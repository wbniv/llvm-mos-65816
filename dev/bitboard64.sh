#!/usr/bin/env bash
# Round 7 #120: s64 bitboard popcount/clz/ctz lowering and runtime differential.
set -euo pipefail
ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/bitboard64.c"
VENDOR="$ROOT/vendor/bsnes-jg"
A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)

cc -O2 "$ROOT/tools/bitboard64-sim.c" -o "$BUILD/bitboard64-sim"
EXPECT=$("$BUILD/bitboard64-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | head -1)
echo "==> host oracle: bitboard64 gate hash = $EXPECT"

for mode in default a16 xy16; do
  feat=(); [ "$mode" = a16 ] && feat=("${A16[@]}"); [ "$mode" = xy16 ] && feat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/bitboard64-$mode.map" \
    -o "$BUILD/bitboard64-$mode.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/bitboard64-$mode.sfc" >/dev/null
done

echo "==> s64 bit-operation disassembly gate"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -S -emit-llvm \
  "$ROOT/examples/65816/bitboard64-probe.c" -o "$BUILD/bitboard64-probe.ll"
for intrinsic in llvm.ctpop.i64 llvm.cttz.i64 llvm.ctlz.i64; do
  grep -q "$intrinsic" "$BUILD/bitboard64-probe.ll" || { echo "FAIL: missing $intrinsic"; exit 1; }
done
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -fno-lto \
  -mllvm -verify-machineinstrs -c "$ROOT/examples/65816/bitboard64-probe.c" \
  -o "$BUILD/bitboard64-probe.o"
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/bitboard64-probe.o")
grep -q '<bitboard64_step>:' <<< "$dis" || { echo "FAIL: bitboard64_step not selected"; exit 1; }
echo "    PASS: ctpop/cttz/ctlz i64 intrinsics form and lower to verified inline machine code"

rc=0
export SMOKE_SETTLE="${SMOKE_SETTLE:-480}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-12}"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
for mode in default a16 xy16; do
  run_assert "$BUILD/bitboard64-$mode.sfc" "$BUILD/bitboard64-$mode.map" corpus_result "$EXPECT" || rc=1
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/bitboard64-$mode.map")
  "$BUILD/jgxcheck" "$BUILD/bitboard64-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 480 \
    "$BUILD/bitboard64-$mode-jg.png" || rc=1
done
[ "$rc" -eq 0 ] && echo "RESULT: PASS — Bitboard Knight Tour; host == default == a16 == xy16 == $EXPECT on MAME + bsnes-jg" || \
  echo "RESULT: FAIL — s64 bit operation changed the tour"
exit "$rc"
