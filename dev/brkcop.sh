#!/usr/bin/env bash
# Round 7 #140: BRK/COP — the synchronous software interrupts, on their own native vectors.
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'USAGE'
Usage: dev/brkcop.sh            (normally: dev/run.sh brkcop)

Round 7 demo #140 "Software Vectors". Builds examples/snes/brkcop.c in default/a16/xy16, then:
  1. host oracle (tools/brkcop-sim.c) -> gate_crc
  2. non-vacuous -verify-machineinstrs (-fno-lto, real-object checked) per feature mode
  3. interrupt-envelope order gate on BOTH `brk` and `cop` in the linked a16 ELF
  4. tools/nmitally-isr-gate.py --symbol brk / --symbol cop
  5. native vector-slot gate: no COP/BRK/NMI/IRQ slot reads $0000; COP/BRK == the C handlers
  6. bsnes-jg differential default/a16/xy16 vs the host oracle + 3x a16 repeats
USAGE
  exit 0
fi

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/brkcop.c"
VENDOR="$ROOT/vendor/bsnes-jg"

cc -O2 "$ROOT/tools/brkcop-sim.c" -o "$BUILD/brkcop-sim"
EXPECT=$("$BUILD/brkcop-sim" | sed -n 's/.*gate_crc = \(0x[0-9A-Fa-f]\{4\}\).*/\1/p')
[ -n "$EXPECT" ] || { echo "FATAL: host oracle printed no gate_crc"; exit 1; }
echo "==> host oracle: brkcop gate hash = $EXPECT"

A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
rc=0
for mode in default a16 xy16; do
  feat=()
  [ "$mode" = a16 ] && feat=("${A16[@]}")
  [ "$mode" = xy16 ] && feat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/brkcop-$mode.map" \
    -o "$BUILD/brkcop-$mode.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/brkcop-$mode.sfc" >/dev/null
done

# -verify-machineinstrs must run where codegen runs. Under the config's default LTO, `-c` emits
# bitcode (no codegen) and the link does not forward -mllvm to the LTO backend, so the flag on the
# build commands above verifies NOTHING (the wt/321-nmitally vacuous-verify finding). Verify on an
# explicit -fno-lto object and prove the output is a real object, not bitcode.
echo "==> -verify-machineinstrs (-fno-lto, so codegen actually runs)"
for vmode in a16 xy16; do
  vfeat=("${A16[@]}"); [ "$vmode" = xy16 ] && vfeat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${vfeat[@]}" -Os \
    -fno-lto -mllvm -verify-machineinstrs -c "$SRC" -o "$BUILD/brkcop-verify.o"
  "$TOOL/llvm-objdump" -h "$BUILD/brkcop-verify.o" >/dev/null 2>&1 \
    || { echo "FAIL: $vmode verify emitted no real object (vacuous verify)"; exit 1; }
  echo "    PASS: $vmode verify clean (real object emitted)"
done

# Envelope gate on BOTH software-interrupt handlers, on the linked a16 ELF (the shipped artifact,
# post-LTO) and order-aware: the property is ordering, not presence — full-width saves before the
# M8/X8 body, full-width restores before rti. A presence-only grep passes the pre-#123 codegen.
echo "==> interrupt-envelope order gate on brk + cop (linked a16 ELF)"
ELF="$BUILD/brkcop-a16.sfc.elf"
[ -f "$ELF" ] || { echo "FATAL: $ELF absent (link should emit it beside the .sfc)"; exit 1; }
"$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$ELF" > "$BUILD/brkcop-a16.dis"
for sym in brk cop; do
  isr=$(awk -F'\t' -v s="<$sym>:" '$0 ~ s {p=1;next} p&&/^[[:space:]]*$/{exit} p&&NF>=2{sub(/[[:space:]]+;.*$/,"",$3); print (NF>=3&&$3!="")?$2" "$3:$2}' \
    "$BUILD/brkcop-a16.dis")
  [ -n "$isr" ] || { echo "FAIL: no disassembly for handler '$sym'"; exit 1; }
  head11=$(printf '%s\n' "$isr" | head -11 | paste -sd,)
  tail7=$(printf '%s\n' "$isr" | tail -7 | paste -sd,)
  [ "$head11" = 'rep #$30,pha,phx,phy,phb,phd,pea $0,pld,phk,plb,sep #$30' ] || \
    { echo "FAIL: $sym prologue is not the width-safe envelope: [$head11]"; exit 1; }
  [ "$tail7" = 'rep #$30,pld,plb,ply,plx,pla,rti' ] || \
    { echo "FAIL: $sym epilogue is not the width-safe envelope: [$tail7]"; exit 1; }
  echo "    PASS: $sym brackets its body with the rep #\$30 full-width save/restore envelope"
done
# Deeper semantic audit (shape / width / Imag + soft-stack save-restore) on the same disasm.
python3 "$ROOT/tools/nmitally-isr-gate.py" "$BUILD/brkcop-a16.dis" --symbol brk || exit 1
python3 "$ROOT/tools/nmitally-isr-gate.py" "$BUILD/brkcop-a16.dis" --symbol cop || exit 1

# Vector-wiring gate. The defect this demo starts from is a vector slot holding the literal $0000:
# a native-mode COP then jumps to bank-0 $0000 and executes WRAM as code. Read the slots straight
# out of the ROM image and require them to name the real handlers.
echo "==> native vector-slot gate (ROM image)"
BRK_VMA=$(awk '$NF=="brk"{print $1; exit}' "$BUILD/brkcop-a16.map")
COP_VMA=$(awk '$NF=="cop"{print $1; exit}' "$BUILD/brkcop-a16.map")
[ -n "$BRK_VMA" ] && [ -n "$COP_VMA" ] || { echo "FAIL: brk/cop absent from the link map"; exit 1; }
python3 - "$BUILD/brkcop-a16.sfc" "$BRK_VMA" "$COP_VMA" <<'PY' || exit 1
import sys
rom = open(sys.argv[1], "rb").read()
want = {"BRK": int(sys.argv[2], 16), "COP": int(sys.argv[3], 16)}
# LoROM bank $00: $8000-$FFFF maps to file offset $0000-$7FFF (link.ld emits FULL(rom)+FULL(romhdr),
# 0x7FB0 + 0x50 = 0x8000 contiguous bytes).
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
for name in ("BRK", "COP"):
    if vals[name] != want[name]:
        print("    FAIL  %s slot $%04X != `%s` symbol $%04X"
              % (name, vals[name], name.lower(), want[name]))
        rc = 1
if rc == 0:
    print("    PASS  COP/BRK slots equal the addresses of the C `cop`/`brk` handlers")
sys.exit(rc)
PY

JGX="$BUILD/jgxcheck"
[ -x "$JGX" ] || { echo "FATAL: build/jgxcheck absent"; exit 1; }
[ -d "$VENDOR/Database" ] || { echo "FATAL: bsnes-jg database absent"; exit 1; }
for mode in default a16 xy16; do
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/brkcop-$mode.map")
  echo "==> bsnes-jg: $mode"
  "$JGX" "$BUILD/brkcop-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 500 \
    "$BUILD/brkcop-$mode-jg.png" || rc=1
done
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/brkcop-a16.map")
for repeat in 1 2; do
  "$JGX" "$BUILD/brkcop-a16.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 500 \
    "$BUILD/brkcop-a16-repeat$repeat.png" || rc=1
done
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Software Vectors; host == default == a16 == xy16 == $EXPECT; a16 3x deterministic"
else
  echo "RESULT: FAIL — one or more legs mismatched (see individual leg output above)"
fi
exit "$rc"
