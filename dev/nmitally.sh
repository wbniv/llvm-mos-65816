#!/usr/bin/env bash
# Round 7 #123: C VBlank interrupt handler under default/a16/xy16 width modes.
set -euo pipefail
ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/nmitally.c"
VENDOR="$ROOT/vendor/bsnes-jg"

cc -O2 "$ROOT/tools/nmitally-sim.c" -o "$BUILD/nmitally-sim"
EXPECT=$("$BUILD/nmitally-sim" | sed -n 's/.*gate_crc = \(0x[0-9A-Fa-f]\{4\}\).*/\1/p')
[ -n "$EXPECT" ] || { echo "FATAL: host oracle printed no gate_crc"; exit 1; }
echo "==> host oracle: nmitally gate hash = $EXPECT"

A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
rc=0
for mode in default a16 xy16; do
  feat=()
  [ "$mode" = a16 ] && feat=("${A16[@]}")
  [ "$mode" = xy16 ] && feat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/nmitally-$mode.map" \
    -o "$BUILD/nmitally-$mode.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/nmitally-$mode.sfc" >/dev/null
done

# ISR structural gate — on the linked a16 ELF (the shipped artifact, post-LTO), and order-aware:
# the pre-fix ISR also *contained* cld/pha/rep/sep/pla/rti, so a presence-only grep passes buggy
# codegen. The property the envelope establishes is ordering — full-width saves before the M8/X8
# body, full-width restores before rti.
echo "==> ISR structural gate (linked a16 ELF)"
ELF="$BUILD/nmitally-a16.sfc.elf"
[ -f "$ELF" ] || { echo "FATAL: $ELF absent (link should emit it beside the .sfc)"; exit 1; }
isr=$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$ELF" \
  | awk -F'\t' '/<nmi>:/{p=1;next} p&&/^[[:space:]]*$/{exit} p&&NF>=2{sub(/[[:space:]]+;.*$/,"",$3); print (NF>=3&&$3!="")?$2" "$3:$2}')
head5=$(printf '%s\n' "$isr" | head -5 | paste -sd,)
tail5=$(printf '%s\n' "$isr" | tail -5 | paste -sd,)
[ "$head5" = 'rep #$30,pha,phx,phy,sep #$30' ] || \
  { echo "FAIL: nmi prologue is not the width-safe envelope: [$head5]"; exit 1; }
[ "$tail5" = 'rep #$30,ply,plx,pla,rti' ] || \
  { echo "FAIL: nmi epilogue is not the width-safe envelope: [$tail5]"; exit 1; }
printf '%s\n' "$isr" | grep -qx cld || { echo "FAIL: nmi lacks cld"; exit 1; }
echo "    PASS: rep #\$30 full-width save/restore envelope brackets the ISR body; cld present"

JGX="$BUILD/jgxcheck"
[ -x "$JGX" ] || { echo "FATAL: build/jgxcheck absent"; exit 1; }
[ -d "$VENDOR/Database" ] || { echo "FATAL: bsnes-jg database absent"; exit 1; }
for mode in default a16 xy16; do
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/nmitally-$mode.map")
  png="$BUILD/nmitally-$mode-jg.png"
  echo "==> bsnes-jg: $mode"
  "$JGX" "$BUILD/nmitally-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 500 "$png" || rc=1
done
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/nmitally-a16.map")
for repeat in 1 2; do
  "$JGX" "$BUILD/nmitally-a16.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 500 \
    "$BUILD/nmitally-a16-repeat$repeat.png" || rc=1
done
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — VBlank Interrupt Tally; host == default == a16 == xy16 == $EXPECT; a16 3x deterministic"
else
  echo "RESULT: FAIL — one or more legs mismatched (see individual leg output above)"
fi
exit "$rc"
