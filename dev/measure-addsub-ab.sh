#!/usr/bin/env bash
# measure-addsub-ab.sh - A/B .text byte comparison of two mos-clang builds over the corpus.
#
# Phase B of the "does G_ADD/G_SUB miss 16-bit lanes under +mos-a16?" investigation
# (docs/investigations/2026-08-04-g-add-sub-s16-lanes.md). BEFORE is the baseline
# toolchain (4x s8 carry lanes), AFTER the experimental one (2x s16 lanes).
#
# Reports per-slice and total .text deltas under +mos-a16, and — because every a16
# change must be provably inert in the default build (agent-handoff "gating discipline")
# — the same comparison WITHOUT the feature, which must come out at exactly 0.
#
# NOTE: llvm-objdump prints section sizes in hex and mawk has no strtonum(), so sizes
# are summed with bash arithmetic. An awk 'strtonum("0x"$3)' version of this silently
# reported every size as 0 (awk exits non-zero, the `|| echo 0` guard swallows it).
#
# Usage: BEFORE=<baseline bin dir> AFTER=<experimental bin dir> dev/measure-addsub-ab.sh
set -euo pipefail

usage() {
  cat <<'EOF'
measure-addsub-ab.sh - A/B corpus .text byte comparison of two mos-clang builds

Usage:
  BEFORE=/path/to/build/llvm-mos-install/bin \
  AFTER=/path/to/build/llvm-mos-install/bin \
  dev/measure-addsub-ab.sh [-h|--help]

Prints a per-slice table (a16 before/after/delta), the a16 total, and the default-build
total, which MUST be identical before/after for the change to be correctly gated.
EOF
}
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

BEFORE="${BEFORE:?set BEFORE to the baseline .../llvm-mos-install/bin}"
AFTER="${AFTER:?set AFTER to the experimental .../llvm-mos-install/bin}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORPUS="$ROOT/examples/snes/corpus"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

A16=(--target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os)
BASE=(--target=mos -mcpu=mosw65816 -Os)

# Sum every .text* section size. Hex -> decimal in bash (mawk has no strtonum).
text_bytes() {
  local obj="$1" dump="$2" total=0 nm sz
  while read -r _ nm sz _; do
    case "$nm" in .text*) total=$(( total + 16#$sz ));; esac
  done < <("$dump/llvm-objdump" --section-headers "$obj" 2>/dev/null)
  echo "$total"
}

printf '%-24s %8s %8s %7s   %8s %8s %7s\n' \
  slice a16-before a16-after delta def-before def-after delta
tb=0; ta=0; db=0; da=0; nwin=0; nloss=0; nsame=0
worst=0; worstn=-; best=0; bestn=-

for src in "$CORPUS"/*.c; do
  n="$(basename "$src" .c)"
  ok=1
  "$BEFORE/mos-clang" "${A16[@]}"  -c "$src" -o "$tmp/b.o"  2>/dev/null || ok=0
  "$AFTER/mos-clang"  "${A16[@]}"  -c "$src" -o "$tmp/a.o"  2>/dev/null || ok=0
  "$BEFORE/mos-clang" "${BASE[@]}" -c "$src" -o "$tmp/bd.o" 2>/dev/null || ok=0
  "$AFTER/mos-clang"  "${BASE[@]}" -c "$src" -o "$tmp/ad.o" 2>/dev/null || ok=0
  if [[ $ok -eq 0 ]]; then
    printf '%-24s %8s\n' "$n" "COMPILE-FAIL"; continue
  fi
  b=$(text_bytes "$tmp/b.o"  "$BEFORE"); a=$(text_bytes "$tmp/a.o"  "$AFTER")
  x=$(text_bytes "$tmp/bd.o" "$BEFORE"); y=$(text_bytes "$tmp/ad.o" "$AFTER")
  d=$(( a - b )); e=$(( y - x ))
  tb=$((tb+b)); ta=$((ta+a)); db=$((db+x)); da=$((da+y))
  if   [[ $d -lt 0 ]]; then nwin=$((nwin+1));  [[ $d -lt $best  ]] && { best=$d;  bestn=$n; }
  elif [[ $d -gt 0 ]]; then nloss=$((nloss+1)); [[ $d -gt $worst ]] && { worst=$d; worstn=$n; }
  else nsame=$((nsame+1)); fi
  [[ $d -ne 0 || $e -ne 0 ]] && \
    printf '%-24s %8d %8d %+7d   %8d %8d %+7d\n' "$n" "$b" "$a" "$d" "$x" "$y" "$e"
done

echo
printf '%-24s %8d %8d %+7d   %8d %8d %+7d\n' TOTAL "$tb" "$ta" "$((ta-tb))" "$db" "$da" "$((da-db))"
echo
echo "a16 slices: $nwin smaller, $nloss larger, $nsame unchanged"
echo "best  slice: $bestn ($best B)"
echo "worst slice: $worstn (+$worst B)"
echo
if [[ $((da-db)) -eq 0 ]]; then
  echo "GATE OK: default (non-+mos-a16) codegen is byte-identical before/after."
else
  echo "GATE FAIL: default codegen changed by $((da-db)) B — the change LEAKS into the 8-bit path."
fi
