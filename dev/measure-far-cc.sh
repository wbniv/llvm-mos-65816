#!/usr/bin/env bash
# dev/measure-far-cc.sh — #320 Inc 4 Ph2 (M): the far-ptr CC bytes+throughput table.
#
# For each ABI variant (a Imag32 / b Imag16+bank / c A:X+Y / d soft-stack), measures:
#   * .text bytes of the shared round-trip source (examples/65816/farcc_imag32.c) — the
#     same figure as the A3 byte census;
#   * round-trips completed in a FIXED wall of emulated frames, via the infinite-loop
#     bench (examples/65816/farcc_bench.c) + dev/probe-cycles.lua. More round-trips ==
#     cheaper per-call passing (MAME 0.285 has no Lua total_cycles(), so this
#     frame-deterministic iteration count is the cycle metric — see the M+D plan).
# Every cell is correctness-gated: the probe only reports PASS if corpus_result == 0xF3.
# Drive from the host: dev/run.sh measure-far-cc.   Runs inside the dev container.
set -euo pipefail
usage() { echo "Usage: dev/run.sh measure-far-cc   # bytes + round-trip throughput per far-ptr CC variant"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
BENCH="$ROOT/examples/65816/farcc_bench.c"
CENSUS="$ROOT/examples/65816/farcc_imag32.c"   # the byte-census source (shared round-trip)
A16=(-Xclang -target-feature -Xclang +mos-a16)
SETTLE="${PROBE_SETTLE:-120}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL (dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far not built (MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }
source "$ROOT/dev/_emu.sh"
require_bios || exit $?

# Sum .text* section sizes. The container's awk is mawk (no strtonum), so extract the
# hex Size column with awk and convert with bash 16# arithmetic — portable either way.
text_bytes() {
  local total=0 sz
  while read -r sz; do [ -n "$sz" ] && total=$((total + 16#$sz)); done < <(
    "$TOOL/llvm-objdump" --section-headers "$1" 2>/dev/null | awk '$2 ~ /^\.text/ { print $3 }'
  )
  echo "$total"
}

ORDER=(imag32 split axy stack)
declare -A VFLAG=( [imag32]=+mos-farcc-imag32 [split]=+mos-farcc-split [axy]=+mos-farcc-axy [stack]=+mos-farcc-stack )
declare -A LABEL=( [imag32]="(a) Imag32" [split]="(b) Im16+bank" [axy]="(c) A:X+Y" [stack]="(d) soft-stack" )
declare -A BYTES ITERS
best=0

echo "==> far-ptr CC measurement (.text on the round-trip source; round-trips in $SETTLE frames on the bench)"
for v in "${ORDER[@]}"; do
  flag="${VFLAG[$v]}"
  rom="$BUILD/bench_$v.sfc"; map="$BUILD/bench_$v.map"; obj="$BUILD/census_$v.o"
  "$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 "${A16[@]}" \
    -Xclang -target-feature -Xclang "$flag" -Os -mllvm -verify-machineinstrs \
    -Wl,-Map="$map" -o "$rom" "$BENCH"
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" \
    -Xclang -target-feature -Xclang "$flag" -Os -mllvm -verify-machineinstrs -c -o "$obj" "$CENSUS"
  "$TOOL/llvm-objdump" -h "$obj" >/dev/null 2>&1 \
    || { echo "  $v: FAIL — -verify-machineinstrs emitted no real object (vacuous verify)"; exit 1; }
  BYTES[$v]="$(text_bytes "$obj")"

  read -r cv _ < <(_emu_map_lookup "$map" corpus_result) || true
  read -r iv _ < <(_emu_map_lookup "$map" iters) || true
  [ -n "${cv:-}" ] && [ -n "${iv:-}" ] || { echo "  $v: FAIL — corpus_result/iters not in $map"; exit 1; }
  caddr=$(printf '0x%X' $((0x7E0000 + 0x$cv))); iaddr=$(printf '0x%X' $((0x7E0000 + 0x$iv)))

  log="$_EMU_SCRATCH/probe-$v.log"
  env SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy \
      PROBE_CORPUS_ADDR="$caddr" PROBE_ITERS_ADDR="$iaddr" PROBE_SETTLE="$SETTLE" \
    mame snes -cart "$rom" -rompath "$ROMPATH" -autoboot_script "$ROOT/dev/probe-cycles.lua" \
      -skip_gameinfo -video none -sound none -nothrottle -seconds_to_run 8 \
      -cfg_directory "$_EMU_SCRATCH" -nvram_directory "$_EMU_SCRATCH" >"$log" 2>&1 || true
  line="$(grep -m1 '^PROBE:' "$log" || true)"
  case "$line" in
    "PROBE: PASS"*) ITERS[$v]="$(printf '%s' "$line" | sed -n 's/.*iters=\([0-9]*\).*/\1/p')";;
    *) echo "  $v: PROBE FAIL — ${line:-<no PROBE line; see $log>}"; exit 1;;
  esac
  printf '    %-14s text=%-4s B  iters=%s\n' "${LABEL[$v]}" "${BYTES[$v]}" "${ITERS[$v]}"
  [ "${ITERS[$v]}" -gt "$best" ] && best="${ITERS[$v]}"
done

echo ""
echo "Far-pointer CC — bytes vs throughput ($SETTLE frames; cost_rel = fastest/this, 1.00 = fastest):"
printf '  %-15s %8s %12s %9s\n' variant '.text_B' 'round-trips' 'cost_rel'
printf '  %-15s %8s %12s %9s\n' '-------' '-------' '-----------' '--------'
for v in "${ORDER[@]}"; do
  cr=$(awk -v b="$best" -v i="${ITERS[$v]}" 'BEGIN{ printf "%.2f", b/i }')
  printf '  %-15s %8s %12s %9s\n' "${LABEL[$v]}" "${BYTES[$v]}" "${ITERS[$v]}" "$cr"
done
echo ""
echo "RESULT: smallest .text AND most round-trips wins; ties -> (a) Imag32 (simplest)."
