#!/usr/bin/env bash
# Round 7 #124: NMI landing inside long native-width mainline sequences.
set -euo pipefail
ROOT=/work;BUILD="$ROOT/build";TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin";CFG="$BUILD/install/bin/mos-snes.cfg";SRC="$ROOT/examples/snes/isrbracket.c";VENDOR="$ROOT/vendor/bsnes-jg"
A16=(-Xclang -target-feature -Xclang +mos-a16);XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
cc -O2 "$ROOT/tools/isrbracket-sim.c" -o "$BUILD/isrbracket-sim";EXPECT=$("$BUILD/isrbracket-sim"|grep -oE '0x[0-9A-Fa-f]{4}'|head -1);echo "==> host oracle: isrbracket gate hash = $EXPECT"
for mode in default a16 xy16;do feat=();[ "$mode" = a16 ]&&feat=("${A16[@]}");[ "$mode" = xy16 ]&&feat=("${XY16[@]}");"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/isrbracket-$mode.map" -o "$BUILD/isrbracket-$mode.sfc" "$SRC";python3 "$ROOT/tools/snes-checksum.py" "$BUILD/isrbracket-$mode.sfc" >/dev/null;done
echo "==> interrupt envelope + long native-width bracket gate"
"$TOOL/mos-clang" --config "$CFG" -fno-lto -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c "$SRC" -o "$BUILD/isrbracket.o"
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/isrbracket.o");isr=$(printf '%s\n' "$dis"|awk '/<nmi>:/{p=1} p{print} p&&/^[[:space:]]*$/{p=0}');for op in cld rti rep sep pha pla phx plx phy ply;do printf '%s\n' "$isr"|grep -qw "$op"||{ echo "FAIL: nmi lacks $op";exit 1;};done
printf '%s\n' "$dis"|awk '/<tunnel>:/{p=1} p{print} p&&/^[[:space:]]*$/{p=0}'|grep -qw rep||{ echo "FAIL: tunnel lacks native-width bracket";exit 1;};echo "    PASS: ISR outer envelope and native-width tunnel present"
rc=0;export SMOKE_SETTLE="${SMOKE_SETTLE:-1400}";export SMOKE_SECONDS="${SMOKE_SECONDS:-25}";source "$ROOT/dev/_emu.sh";require_bios||exit $?
for mode in default a16 xy16;do run_assert "$BUILD/isrbracket-$mode.sfc" "$BUILD/isrbracket-$mode.map" corpus_result "$EXPECT"||rc=1;VMA=$(awk '$NF=="corpus_result"{print $1;exit}' "$BUILD/isrbracket-$mode.map");for repeat in 1 2 3;do "$BUILD/jgxcheck" "$BUILD/isrbracket-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 1400 "$BUILD/isrbracket-$mode-jg$repeat.png"||rc=1;done;done
[ "$rc" -eq 0 ]&&echo "RESULT: PASS — Mid-Bracket Interrupt Torture; host == default == a16 == xy16 == $EXPECT; bsnes-jg 3x deterministic"||echo "RESULT: FAIL — asynchronous width restoration diverged";exit "$rc"
