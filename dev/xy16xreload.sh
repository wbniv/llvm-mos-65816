#!/usr/bin/env bash
# Check late X preservation with the original Vlastack input and MIR routines
# that consume/produce hard-stack bytes while X.high must survive narrowing.
set -euo pipefail
ROOT=/work
. "$ROOT/dev/_emu.sh"
OUT="${XY16_RELOAD_OUT:-$ROOT/build/xy16-x-preserve/runtime}"
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos}/bin"
CFG="$ROOT/build/install/bin/mos-snes.cfg"
mkdir -p "$OUT"
require_bios

"$TOOL/llc" -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 \
  -start-before=mos-insert-rep-sep -verify-machineinstrs -filetype=obj \
  "$ROOT/vendor/llvm-mos/llvm/test/CodeGen/MOS/insert-rep-sep-stack.mir" \
  -o "$OUT/stack.o"
for mode in default a16 xy16; do
  flags=()
  if [ "$mode" != default ]; then
    flags=(-Xclang -target-feature -Xclang "+mos-$mode")
  fi
  "$TOOL/clang" --config "$CFG" -mcpu=mosw65816 "${flags[@]}" -Os \
    "$ROOT/examples/65816/xy16-x-preserve.c" "$OUT/stack.o" \
    -Wl,-Map="$OUT/stack-$mode.map" -o "$OUT/stack-$mode.sfc"
  python3 "$ROOT/tools/snes-checksum.py" "$OUT/stack-$mode.sfc"
  SMOKE_SETTLE=1200 SMOKE_SECONDS=25 \
    run_assert "$OUT/stack-$mode.sfc" "$OUT/stack-$mode.map" corpus_result 0xD77B
  offset=$(awk '$NF == "corpus_result" {print "0x"$1; exit}' "$OUT/stack-$mode.map")
  "$ROOT/build/jgxcheck" "$OUT/stack-$mode.sfc" \
    "$ROOT/vendor/bsnes-jg/Database" "$offset" 2 0xD77B 1200
done

SOURCE="$ROOT/docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/vlastack_sim.c"
"$TOOL/clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-xy16 -Os \
  -mllvm -mos-carry-sched=always -Wl,-mllvm,-mos-carry-sched=always -Wl,--save-temps \
  -Wl,-Map="$OUT/original.map" -o "$OUT/original.sfc" "$SOURCE"
python3 "$ROOT/tools/snes-checksum.py" "$OUT/original.sfc"
SMOKE_SETTLE=1200 SMOKE_SECONDS=25 \
  run_assert "$OUT/original.sfc" "$OUT/original.map" corpus_result 0xD77B
"$ROOT/build/jgxcheck" "$OUT/original.sfc" \
  "$ROOT/vendor/bsnes-jg/Database" 0x200 2 0xD77B 1200
