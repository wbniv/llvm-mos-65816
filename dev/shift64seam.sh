#!/usr/bin/env bash
# Round 7 #138: data-dependent s64 shifts across 16- and 32-bit limb seams.
set -euo pipefail
ROOT=/work; BUILD="$ROOT/build"; TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"; CFG="$BUILD/install/bin/mos-snes.cfg"; SRC="$ROOT/examples/snes/shift64seam.c"; VENDOR="$ROOT/vendor/bsnes-jg"
A16=(-Xclang -target-feature -Xclang +mos-a16); XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
cc -O2 "$ROOT/tools/shift64seam-sim.c" -o "$BUILD/shift64seam-sim"
EXPECT=$("$BUILD/shift64seam-sim"|grep -oE '0x[0-9A-Fa-f]{4}'|head -1); echo "==> host oracle: shift64seam gate hash = $EXPECT"
for mode in default a16 xy16;do feat=();[ "$mode" = a16 ]&&feat=("${A16[@]}");[ "$mode" = xy16 ]&&feat=("${XY16[@]}");"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/shift64seam-$mode.map" -o "$BUILD/shift64seam-$mode.sfc" "$SRC";python3 "$ROOT/tools/snes-checksum.py" "$BUILD/shift64seam-$mode.sfc" >/dev/null;done
echo "==> widened-count s64 shift gate"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -S -emit-llvm "$ROOT/examples/65816/shift64seam-probe.c" -o "$BUILD/shift64seam.ll"
for op in 'shl i64' 'lshr i64' 'ashr i64';do grep -q "$op" "$BUILD/shift64seam.ll"||{ echo "FAIL: missing $op";exit 1;};done
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -fno-lto -mllvm -verify-machineinstrs -c "$ROOT/examples/65816/shift64seam-probe.c" -o "$BUILD/shift64seam.o"
echo "    PASS: variable shl/lshr/ashr i64 form and verify with an explicitly widened count"
rc=0;export SMOKE_SETTLE="${SMOKE_SETTLE:-480}";export SMOKE_SECONDS="${SMOKE_SECONDS:-12}";source "$ROOT/dev/_emu.sh";require_bios||exit $?
for mode in default a16 xy16;do run_assert "$BUILD/shift64seam-$mode.sfc" "$BUILD/shift64seam-$mode.map" corpus_result "$EXPECT"||rc=1;VMA=$(awk '$NF=="corpus_result"{print $1;exit}' "$BUILD/shift64seam-$mode.map");"$BUILD/jgxcheck" "$BUILD/shift64seam-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 480 "$BUILD/shift64seam-$mode-jg.png"||rc=1;done
[ "$rc" -eq 0 ]&&echo "RESULT: PASS — Limb-Seam Barrel; host == default == a16 == xy16 == $EXPECT on MAME + bsnes-jg"||echo "RESULT: FAIL — s64 seam shift diverged";exit "$rc"
