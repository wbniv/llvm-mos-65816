#!/usr/bin/env bash
# Round 7 #119: G_ABDU/G_ABDS absolute-difference legalization and lowering.
set -euo pipefail
ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/absdiff.c"
VENDOR="$ROOT/vendor/bsnes-jg"

cc -O2 "$ROOT/tools/absdiff-sim.c" -o "$BUILD/absdiff-sim"
EXPECT=$("$BUILD/absdiff-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | head -1)
echo "==> host oracle: absdiff gate hash = $EXPECT"

A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
for mode in default a16 xy16; do
  feat=()
  [ "$mode" = a16 ] && feat=("${A16[@]}")
  [ "$mode" = xy16 ] && feat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/absdiff-$mode.map" \
    -o "$BUILD/absdiff-$mode.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/absdiff-$mode.sfc" >/dev/null
done

echo "==> absolute-difference codegen gate"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -fno-lto \
  -mllvm -verify-machineinstrs -c "$ROOT/examples/65816/absdiff-probe.c" \
  -o "$BUILD/absdiff-probe.o"
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/absdiff-probe.o")
for sym in absdiff_u8 absdiff_s16 absdiff_u32; do
  printf '%s\n' "$dis" | grep -q "<$sym>:" || { echo "FAIL: missing $sym"; exit 1; }
done
printf '%s\n' "$dis" | grep -Eq $'\t(sbc|eor)\t' || { echo "FAIL: no subtract/abs lowering"; exit 1; }
echo "    PASS: u8, s16, and u32 absolute-difference bodies selected and verified"

rc=0
for mode in default a16 xy16; do
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/absdiff-$mode.map")
  "$BUILD/jgxcheck" "$BUILD/absdiff-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 360 \
    "$BUILD/absdiff-$mode-jg.png" || rc=1
done
[ "$rc" -eq 0 ] && echo "RESULT: PASS — Motion-Detect Difference Field; host == default == a16 == xy16 == $EXPECT" || \
  echo "RESULT: FAIL — absolute-difference result diverged"
exit "$rc"
