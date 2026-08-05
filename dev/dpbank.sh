#!/usr/bin/env bash
# Round 7 #141: D/DBR interrupt-entry contract — NMIs landing inside moved-D and moved-DBR
# inline-asm windows, with the envelope extended to save/re-establish/restore both registers.
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'USAGE'
Usage: dev/dpbank.sh           (normally: dev/run.sh dpbank)

Round 7 demo #141 "Bank/Direct-Page Windows". Builds examples/snes/dpbank.c in
default/a16/xy16, then:
  1. host oracle (tools/dpbank-sim.c) -> gate_crc
  2. non-vacuous -verify-machineinstrs (-fno-lto, real-object checked) per feature mode
  3. FULL interrupt-envelope order gate on `nmi` in the linked a16 ELF — including the #141
     phb/phd/pea 0/pld/phk/plb D+DBR half of the contract — plus tools/nmitally-isr-gate.py
  4. native vector-slot gate: no COP/BRK/NMI/IRQ slot reads $0000; NMI == the C handler
  5. bsnes-jg differential default/a16/xy16 vs the host oracle + 3x a16 repeats
     (every run rendezvous 20 NMI landings inside D!=0 windows and 20 inside DBR!=0 windows)
USAGE
  exit 0
fi

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/dpbank.c"
VENDOR="$ROOT/vendor/bsnes-jg"

cc -O2 "$ROOT/tools/dpbank-sim.c" -o "$BUILD/dpbank-sim"
EXPECT=$("$BUILD/dpbank-sim" | sed -n 's/.*gate_crc = \(0x[0-9A-Fa-f]\{4\}\).*/\1/p')
[ -n "$EXPECT" ] || { echo "FATAL: host oracle printed no gate_crc"; exit 1; }
echo "==> host oracle: dpbank gate hash = $EXPECT"

A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
rc=0
for mode in default a16 xy16; do
  feat=()
  [ "$mode" = a16 ] && feat=("${A16[@]}")
  [ "$mode" = xy16 ] && feat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/dpbank-$mode.map" \
    -o "$BUILD/dpbank-$mode.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/dpbank-$mode.sfc" >/dev/null
done

# -verify-machineinstrs must run where codegen runs (the wt/321-nmitally vacuous-verify finding).
echo "==> -verify-machineinstrs (-fno-lto, so codegen actually runs)"
for vmode in a16 xy16; do
  vfeat=("${A16[@]}"); [ "$vmode" = xy16 ] && vfeat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${vfeat[@]}" -Os \
    -fno-lto -mllvm -verify-machineinstrs -c "$SRC" -o "$BUILD/dpbank-verify.o"
  "$TOOL/llvm-objdump" -h "$BUILD/dpbank-verify.o" >/dev/null 2>&1 \
    || { echo "FAIL: $vmode verify emitted no real object (vacuous verify)"; exit 1; }
  echo "    PASS: $vmode verify clean (real object emitted)"
done

# The FULL envelope order gate — this is #141's recorded contract. Head: full-width A/X/Y saves,
# then D and DBR saves, then re-establishment of the complete C ABI state (D=0 via pea 0/pld,
# DBR=0 via phk/plb off the hardware-forced PBR=0), all before the M8/X8 body. Tail: the exact
# reverse before RTI restores the stacked P.
echo "==> interrupt-envelope order gate on nmi (linked a16 ELF, D+DBR contract)"
ELF="$BUILD/dpbank-a16.sfc.elf"
[ -f "$ELF" ] || { echo "FATAL: $ELF absent (link should emit it beside the .sfc)"; exit 1; }
"$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$ELF" > "$BUILD/dpbank-a16.dis"
isr=$(awk -F'\t' '/<nmi>:/{p=1;next} p&&/^[[:space:]]*$/{exit} p&&NF>=2{sub(/[[:space:]]+;.*$/,"",$3); print (NF>=3&&$3!="")?$2" "$3:$2}' \
  "$BUILD/dpbank-a16.dis")
[ -n "$isr" ] || { echo "FAIL: no disassembly for handler 'nmi'"; exit 1; }
head11=$(printf '%s\n' "$isr" | head -11 | paste -sd,)
tail7=$(printf '%s\n' "$isr" | tail -7 | paste -sd,)
[ "$head11" = 'rep #$30,pha,phx,phy,phb,phd,pea $0,pld,phk,plb,sep #$30' ] || \
  { echo "FAIL: nmi prologue is not the full D+DBR envelope: [$head11]"; exit 1; }
[ "$tail7" = 'rep #$30,pld,plb,ply,plx,pla,rti' ] || \
  { echo "FAIL: nmi epilogue is not the full D+DBR envelope: [$tail7]"; exit 1; }
echo "    PASS: nmi carries the full A/X/Y + D/DBR save, C-ABI re-establishment, and restore"
python3 "$ROOT/tools/nmitally-isr-gate.py" "$BUILD/dpbank-a16.dis" --symbol nmi || exit 1

# Vector-wiring gate (carried over from #140).
echo "==> native vector-slot gate (ROM image)"
NMI_VMA=$(awk '$NF=="nmi"{print $1; exit}' "$BUILD/dpbank-a16.map")
[ -n "$NMI_VMA" ] || { echo "FAIL: nmi absent from the link map"; exit 1; }
python3 - "$BUILD/dpbank-a16.sfc" "$NMI_VMA" <<'PY' || exit 1
import sys
rom = open(sys.argv[1], "rb").read()
want_nmi = int(sys.argv[2], 16)
slots = [("COP", 0xFFE4), ("BRK", 0xFFE6), ("NMI", 0xFFEA), ("IRQ", 0xFFEE)]
rc = 0
vals = {}
for name, addr in slots:
    off = addr - 0x8000
    vals[name] = rom[off] | (rom[off + 1] << 8)
    if vals[name] == 0:
        print("    FAIL  $%04X %s reads $0000 -> would execute low WRAM as code" % (addr, name))
        rc = 1
    else:
        print("    PASS  $%04X %s -> $%04X" % (addr, name, vals[name]))
if vals["NMI"] != want_nmi:
    print("    FAIL  NMI slot $%04X != `nmi` symbol $%04X" % (vals["NMI"], want_nmi))
    rc = 1
else:
    print("    PASS  NMI slot equals the address of the C `nmi` handler")
sys.exit(rc)
PY

JGX="$BUILD/jgxcheck"
[ -x "$JGX" ] || { echo "FATAL: build/jgxcheck absent"; exit 1; }
[ -d "$VENDOR/Database" ] || { echo "FATAL: bsnes-jg database absent"; exit 1; }
FRAMES="${FRAMES:-500}"
for mode in default a16 xy16; do
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/dpbank-$mode.map")
  echo "==> bsnes-jg: $mode"
  "$JGX" "$BUILD/dpbank-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" "$FRAMES" \
    "$BUILD/dpbank-$mode-jg.png" || rc=1
done
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/dpbank-a16.map")
for repeat in 1 2; do
  "$JGX" "$BUILD/dpbank-a16.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" "$FRAMES" \
    "$BUILD/dpbank-a16-repeat$repeat.png" || rc=1
done
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — dpbank; host == default == a16 == xy16 == $EXPECT; a16 3x deterministic; 20 D-window + 20 B-window NMI landings per run"
else
  echo "RESULT: FAIL — one or more legs mismatched (see individual leg output above)"
fi
exit "$rc"
