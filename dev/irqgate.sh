#!/usr/bin/env bash
# Round 7 #139: the PPU V-count timer IRQ running a C handler, with NMI simultaneously live.
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'USAGE'
Usage: dev/irqgate.sh           (normally: dev/run.sh irqgate)

Round 7 demo #139 "IRQ Gate". Builds examples/snes/irqgate.c in default/a16/xy16, then:
  1. host oracle (tools/irqgate-sim.c) -> gate_crc
  2. non-vacuous -verify-machineinstrs (-fno-lto, real-object checked) per feature mode
  3. interrupt-envelope order gate on BOTH `nmi` and `irq` in the linked a16 ELF
  4. tools/nmitally-isr-gate.py --symbol nmi / --symbol irq
  5. TIMEUP ($4211) acknowledge present inside `irq`
  6. native vector-slot gate: no COP/BRK/NMI/IRQ slot reads $0000; NMI/IRQ == the C handlers
  7. bsnes-jg differential default/a16/xy16 vs the host oracle + 3x a16 repeats
USAGE
  exit 0
fi

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/irqgate.c"
VENDOR="$ROOT/vendor/bsnes-jg"

cc -O2 "$ROOT/tools/irqgate-sim.c" -o "$BUILD/irqgate-sim"
EXPECT=$("$BUILD/irqgate-sim" | sed -n 's/.*gate_crc = \(0x[0-9A-Fa-f]\{4\}\).*/\1/p')
[ -n "$EXPECT" ] || { echo "FATAL: host oracle printed no gate_crc"; exit 1; }
echo "==> host oracle: irqgate gate hash = $EXPECT"

A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
rc=0
for mode in default a16 xy16; do
  feat=()
  [ "$mode" = a16 ] && feat=("${A16[@]}")
  [ "$mode" = xy16 ] && feat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/irqgate-$mode.map" \
    -o "$BUILD/irqgate-$mode.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/irqgate-$mode.sfc" >/dev/null
done

# -verify-machineinstrs must run where codegen runs. Under the config's default LTO, `-c` emits
# bitcode (no codegen) and the link does not forward -mllvm to the LTO backend, so the flag on the
# build commands above verifies NOTHING (the wt/321-nmitally vacuous-verify finding). Verify on an
# explicit -fno-lto object and prove the output is a real object, not bitcode.
echo "==> -verify-machineinstrs (-fno-lto, so codegen actually runs)"
for vmode in a16 xy16; do
  vfeat=("${A16[@]}"); [ "$vmode" = xy16 ] && vfeat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${vfeat[@]}" -Os \
    -fno-lto -mllvm -verify-machineinstrs -c "$SRC" -o "$BUILD/irqgate-verify.o"
  "$TOOL/llvm-objdump" -h "$BUILD/irqgate-verify.o" >/dev/null 2>&1 \
    || { echo "FAIL: $vmode verify emitted no real object (vacuous verify)"; exit 1; }
  echo "    PASS: $vmode verify clean (real object emitted)"
done

# Envelope gate on BOTH hardware handlers, on the linked a16 ELF (the shipped artifact, post-LTO)
# and order-aware: the property is ordering, not presence — full-width saves before the M8/X8 body,
# full-width restores before rti. A presence-only grep passes the pre-#123 codegen.
echo "==> interrupt-envelope order gate on nmi + irq (linked a16 ELF)"
ELF="$BUILD/irqgate-a16.sfc.elf"
[ -f "$ELF" ] || { echo "FATAL: $ELF absent (link should emit it beside the .sfc)"; exit 1; }
"$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$ELF" > "$BUILD/irqgate-a16.dis"
for sym in nmi irq; do
  isr=$(awk -F'\t' -v s="<$sym>:" '$0 ~ s {p=1;next} p&&/^[[:space:]]*$/{exit} p&&NF>=2{sub(/[[:space:]]+;.*$/,"",$3); print (NF>=3&&$3!="")?$2" "$3:$2}' \
    "$BUILD/irqgate-a16.dis")
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
python3 "$ROOT/tools/nmitally-isr-gate.py" "$BUILD/irqgate-a16.dis" --symbol nmi || exit 1
python3 "$ROOT/tools/nmitally-isr-gate.py" "$BUILD/irqgate-a16.dis" --symbol irq || exit 1

# The IRQ acknowledge. TIMEUP ($4211) is read-to-clear; without the read the IRQ line stays
# asserted and the handler re-enters forever the moment RTI restores I. A missing ack is a hang,
# not a wrong value, so no differential leg can see it — this gate can.
echo "==> TIMEUP acknowledge gate"
irq_body=$(awk -F'\t' '/<irq>:/{p=1;next} p&&/^[[:space:]]*$/{exit} p' "$BUILD/irqgate-a16.dis")
printf '%s\n' "$irq_body" | grep -qE 'lda[[:space:]]+\$4211' \
  || { echo "FAIL: irq contains no 'lda \$4211' — TIMEUP is never acknowledged"; exit 1; }
echo "    PASS: irq reads \$4211 (TIMEUP) to acknowledge"

# Vector-wiring gate (carried over from #140): a native slot holding the literal $0000 sends the
# CPU into low WRAM to execute data as code.
echo "==> native vector-slot gate (ROM image)"
NMI_VMA=$(awk '$NF=="nmi"{print $1; exit}' "$BUILD/irqgate-a16.map")
IRQ_VMA=$(awk '$NF=="irq"{print $1; exit}' "$BUILD/irqgate-a16.map")
[ -n "$NMI_VMA" ] && [ -n "$IRQ_VMA" ] || { echo "FAIL: nmi/irq absent from the link map"; exit 1; }
python3 - "$BUILD/irqgate-a16.sfc" "$NMI_VMA" "$IRQ_VMA" <<'PY' || exit 1
import sys
rom = open(sys.argv[1], "rb").read()
want = {"NMI": int(sys.argv[2], 16), "IRQ": int(sys.argv[3], 16)}
# LoROM bank $00: $8000-$FFFF maps to file offset $0000-$7FFF.
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
for name in ("NMI", "IRQ"):
    if vals[name] != want[name]:
        print("    FAIL  %s slot $%04X != `%s` symbol $%04X"
              % (name, vals[name], name.lower(), want[name]))
        rc = 1
if rc == 0:
    print("    PASS  NMI/IRQ slots equal the addresses of the C `nmi`/`irq` handlers")
sys.exit(rc)
PY

JGX="$BUILD/jgxcheck"
[ -x "$JGX" ] || { echo "FATAL: build/jgxcheck absent"; exit 1; }
[ -d "$VENDOR/Database" ] || { echo "FATAL: bsnes-jg database absent"; exit 1; }
FRAMES="${FRAMES:-500}"
for mode in default a16 xy16; do
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/irqgate-$mode.map")
  echo "==> bsnes-jg: $mode"
  "$JGX" "$BUILD/irqgate-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" "$FRAMES" \
    "$BUILD/irqgate-$mode-jg.png" || rc=1
done
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/irqgate-a16.map")
for repeat in 1 2; do
  "$JGX" "$BUILD/irqgate-a16.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" "$FRAMES" \
    "$BUILD/irqgate-a16-repeat$repeat.png" || rc=1
done
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — IRQ Gate; host == default == a16 == xy16 == $EXPECT; a16 3x deterministic"
else
  echo "RESULT: FAIL — one or more legs mismatched (see individual leg output above)"
fi
exit "$rc"
