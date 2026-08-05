#!/usr/bin/env bash
# Round 7 #121: llabs and the signed i64 absolute-value idiom across limb seams.
set -euo pipefail
ROOT=/work; BUILD="$ROOT/build"; TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"; CFG="$BUILD/install/bin/mos-snes.cfg"; SRC="$ROOT/examples/snes/llabs64.c"; VENDOR="$ROOT/vendor/bsnes-jg"
A16=(-Xclang -target-feature -Xclang +mos-a16); XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
cc -O2 "$ROOT/tools/llabs64-sim.c" -o "$BUILD/llabs64-sim"
EXPECT=$("$BUILD/llabs64-sim"|grep -oE '0x[0-9A-Fa-f]{4}'|head -1); echo "==> host oracle: llabs64 gate hash = $EXPECT"
for mode in default a16 xy16;do feat=();[ "$mode" = a16 ]&&feat=("${A16[@]}");[ "$mode" = xy16 ]&&feat=("${XY16[@]}");"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/llabs64-$mode.map" -o "$BUILD/llabs64-$mode.sfc" "$SRC";python3 "$ROOT/tools/snes-checksum.py" "$BUILD/llabs64-$mode.sfc" >/dev/null;done
echo "==> signed i64 absolute-value gate"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -S -emit-llvm "$ROOT/examples/65816/llabs64-probe.c" -o "$BUILD/llabs64.ll"
grep -Eq 'llvm\.abs\.i64|call.*llabs' "$BUILD/llabs64.ll"||{ echo "FAIL: missing i64 absolute-value operation";exit 1;}
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -fno-lto -mllvm -verify-machineinstrs -c "$ROOT/examples/65816/llabs64-probe.c" -o "$BUILD/llabs64.o"
echo "    PASS: i64 absolute value forms and verifies"
rc=0;export SMOKE_SETTLE="${SMOKE_SETTLE:-480}";export SMOKE_SECONDS="${SMOKE_SECONDS:-12}";source "$ROOT/dev/_emu.sh";require_bios||exit $?
for mode in default a16 xy16;do run_assert "$BUILD/llabs64-$mode.sfc" "$BUILD/llabs64-$mode.map" corpus_result "$EXPECT"||rc=1;VMA=$(awk '$NF=="corpus_result"{print $1;exit}' "$BUILD/llabs64-$mode.map");"$BUILD/jgxcheck" "$BUILD/llabs64-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 480 "$BUILD/llabs64-$mode-jg.png"||rc=1;done
[ "$rc" -eq 0 ]&&echo "RESULT: PASS — Seismograph Absolute Trace; host == default == a16 == xy16 == $EXPECT on MAME + bsnes-jg"||echo "RESULT: FAIL — signed i64 absolute value diverged";exit "$rc"
