#!/usr/bin/env bash
# Round 7 #131: multiple non-rematerializable Imag32 far-pointer spills across a clobbering call.
set -euo pipefail
ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes-far.cfg"
SRC="$ROOT/examples/snes/farspill.c"
VENDOR="$ROOT/vendor/bsnes-jg"
A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)

cc -O2 "$ROOT/tools/farspill-sim.c" -o "$BUILD/farspill-sim"
EXPECT=$("$BUILD/farspill-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | head -1)
echo "==> host oracle: farspill gate hash = $EXPECT"

for mode in a16 xy16; do
  feat=("${A16[@]}"); [ "$mode" = xy16 ] && feat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/farspill-$mode.map" \
    -o "$BUILD/farspill-$mode.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/farspill-$mode.sfc" >/dev/null
done

echo "==> Imag32 spill and producer gates"
MIR="$BUILD/farspill-greedy.mir"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -fno-lto \
  -mllvm -verify-machineinstrs -mllvm -stop-after=greedy -S \
  "$ROOT/examples/65816/farspill-probe.c" -o "$MIR"
slots=$(grep -cE 'type: spill-slot.*size: 4,' "$MIR" || true)
stores=$(grep -cE 'STAbs .*%stack\.[0-9]+( \+ [123])? .*store \(s8\)' "$MIR" || true)
loads=$(grep -cE 'LDAbs .*%stack\.[0-9]+( \+ [123])? .*load \(s8\)' "$MIR" || true)
[ "$slots" -ge 4 ] && [ "$stores" -ge 16 ] && [ "$loads" -ge 16 ] || {
  echo "FAIL: expected multiple four-byte Imag32 spills; slots=$slots stores=$stores loads=$loads"; exit 1;
}
echo "    PASS: $slots four-byte Imag32 slots expand to $stores stores / $loads reloads"

dump=$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -fno-lto \
  -mllvm -print-before=mos-late-opt -S -o /dev/null \
  "$ROOT/examples/65816/farspill-probe.c" 2>&1 | grep -E '=[[:space:]]*LDImm ' || true)
nongpr=$(printf '%s\n' "$dump" | grep -vE '^[[:space:]]*(dead |renamable |killed )*\$(a|x|y)[[:space:]]*=' | grep -c . || true)
total=$(printf '%s\n' "$dump" | grep -c . || true)
[ "$total" -gt 0 ] && [ "$nongpr" -eq 0 ] || { echo "FAIL: LDImm producer gate total=$total non-GPR=$nongpr"; exit 1; }
echo "    PASS: all $total LDImm destinations are hardware GPRs"

rc=0
export SMOKE_SETTLE="${SMOKE_SETTLE:-420}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-10}"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
for mode in a16 xy16; do
  run_assert "$BUILD/farspill-$mode.sfc" "$BUILD/farspill-$mode.map" corpus_result "$EXPECT" || rc=1
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/farspill-$mode.map")
  "$BUILD/jgxcheck" "$BUILD/farspill-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 420 \
    "$BUILD/farspill-$mode-jg.png" || rc=1
done
[ "$rc" -eq 0 ] && echo "RESULT: PASS — Far-Spill Stress; host == a16 == xy16 == $EXPECT on MAME + bsnes-jg" || \
  echo "RESULT: FAIL — spilled far pointer changed value"
exit "$rc"
