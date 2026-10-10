#!/usr/bin/env bash
# Usage: census.sh LLC OUTDIR [OPT...]
# Compile each default-mode corpus IR for mosspc700 with LLC at each OPT level
# and write one TSV row per input/level: level input rc signature hint.
set -uo pipefail
case "${1:-}" in -h|--help) sed -n '2,4p' "$0"; exit 0;; esac
LLC=$1; OUT=$2; shift 2
LEVELS=("${@:-O2}")
BASE=/home/will/llvm-mos-65816/build/split-320-321/default-inputs/corpus
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
ulimit -c 0; ulimit -v 2000000
# Os/Oz: llc has no size levels; clang passes them as optsize/minsize function
# attributes at -O2, so those levels read attribute-rewritten copies of the IR.
for L in "${LEVELS[@]}"; do
  case "$L" in Os|Oz) IN="$HERE/inputs-$L"; LL=O2;; *) IN=$BASE; LL=$L;; esac
  for f in "$IN"/*.ll; do
    b=$(basename "$f" .c.default.ll)
    log="$OUT/$L-$b.log"
    timeout 300 "$LLC" -mtriple=mos -mcpu=mosspc700 -"$LL" ${EXTRA:-} "$f" -o "${ASMDIR:-/dev/null}${ASMDIR:+/$L-$b.s}" -debug-only=regalloc >"$log" 2>&1
    rc=$?
    sig=ok
    if [ $rc -ne 0 ]; then
      if grep -q 'Target hint is outside allocation order' "$log"; then sig=hint-outside-order
      elif grep -q 'ran out of registers' "$log"; then sig=out-of-registers
      elif grep -q 'unable to legalize' "$log"; then sig=legalize-far-p2
      else
        pass=$(grep -E "^[0-9]+\.[[:space:]]+Running pass '" "$log" | tail -1 | sed -E "s/.*Running pass '([^']*)'.*/\1/")
        sig="crash rc=$rc in ${pass:-unknown}"
      fi
    fi
    hint=""
    if [ "$sig" = hint-outside-order ]; then
      hint=$(grep -E '^(selectOrSplit|hints:)' "$log" | tail -2 | tr '\n' ' ' | cut -c1-120)
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$L" "$b" "$rc" "$sig" "$hint"
    # Keep only failing logs, trimmed to the tail, to save disk.
    if [ $rc -eq 0 ]; then rm -f "$log"; else tail -60 "$log" > "$log.t" && mv "$log.t" "$log"; fi
  done
done
