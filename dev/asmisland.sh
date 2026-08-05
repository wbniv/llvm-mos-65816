#!/usr/bin/env bash
# Round 7 #125: inline assembly inside native-width code.
set -euo pipefail
ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/asmisland.c"
VENDOR="$ROOT/vendor/bsnes-jg"

cc -O2 "$ROOT/tools/asmisland-sim.c" -o "$BUILD/asmisland-sim"
EXPECT=$("$BUILD/asmisland-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | head -1)
echo "==> host oracle: asmisland gate hash = $EXPECT"

A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
for mode in default a16 xy16; do
  feat=(); [ "$mode" = a16 ] && feat=("${A16[@]}"); [ "$mode" = xy16 ] && feat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/asmisland-$mode.map" \
    -o "$BUILD/asmisland-$mode.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/asmisland-$mode.sfc" >/dev/null
done

echo "==> opaque-island raw-byte/disassembly gate"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -c "$ROOT/examples/65816/asmisland-probe.c" \
  -o "$BUILD/asmisland-probe.o"
hex=$("$TOOL/llvm-objdump" -s -j .text.asmisland_step "$BUILD/asmisland-probe.o" | tr -d ' \n')
printf '%s' "$hex" | grep -qi 'e220a95a8d' || { echo "FAIL: missing explicit A8 immediate bytes"; exit 1; }
printf '%s' "$hex" | grep -qi 'c220a9ff004d' || { echo "FAIL: missing explicit A16 immediate bytes"; exit 1; }
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/asmisland-probe.o")
step=$(printf '%s\n' "$dis" | awk '/<asmisland_step>:/{p=1} p{print} p && /rts/{exit}')
printf '%s\n' "$step" | grep -q $'\tplp'
after=$(printf '%s\n' "$step" | awk '/plp/{p=1;next} p{print}')
printf '%s\n' "$after" | grep -q $'\trep\t#$20' || { echo "FAIL: M16 not re-established after asm"; exit 1; }
echo "    PASS: explicit A8/A16 bytes + compiler M16 re-establishment"

rc=0
for mode in default a16 xy16; do
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/asmisland-$mode.map")
  "$BUILD/jgxcheck" "$BUILD/asmisland-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 300 \
    "$BUILD/asmisland-$mode-jg.png" || rc=1
done
[ "$rc" -eq 0 ] && echo "RESULT: PASS — Inline-Asm Island; host == default == a16 == xy16 == $EXPECT" || \
  echo "RESULT: FAIL — inline asm corrupted width state or a live value"
exit "$rc"
