#!/usr/bin/env bash
# Red/green matrix for the tests the carry adds or extends.
#
# usage: carry-red-green.sh OUT.tsv
# Each probe-carry/<commit>__<test> version runs (run-test-with.py) against:
#   red   its parent commit's llc and the unrepaired version of its commit
#         (the previous split's frozen llc, or for far-word patch 12 the
#         monolithic-prerequisite far-word candidate d7fde754),
#   green its own commit's llc and every later carried llc.
# Columns: test, commit, role, llc label, llc sha256 (16), result, first diagnostic.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
OUT=$(realpath -m "$1"); case "$OUT" in $ROOT/*) ;; *) echo "OUT must be under $ROOT" >&2; exit 2;; esac
cd "$ROOT"
dev/container.sh -- bash -c '
set -uo pipefail
S=/work/build/split-320-321; P=$S/probe-carry; L=$S/llc; OUT=$1
declare -A LLC=([fw-old-candidate]=/work/build/far-word-rebase/candidate/llc)
for l in p-320-02 p-320-03 p-320-04 c-320-01 c-320-02 c-320-03 c-320-04 c-fw-11 c-fw-14; do LLC[$l]=$L/$l; done
row() { # test commit role label
  local f=$P/$2__$1 llc=${LLC[$4]}
  local h; h=$(sha256sum "$llc" | cut -c1-16)
  local r; r=$(python3 $S/spec/run-test-with.py "$llc" "$f" 2>&1 | head -1)
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" "$h" "${r%% *}" "${r#* }"
}
{
printf "test\tcommit\trole\tllc\tllc_sha256_16\tresult\tfirst_diagnostic\n"
for t in far-ptr-arg-exhaustion.ll far-access-non-65816.ll far-ptr-trunc.ll; do
  row $t 320-02 red-parent c-320-01; row $t 320-02 red-unrepaired p-320-02
  for g in c-320-02 c-320-03 c-320-04 c-fw-11 c-fw-14; do row $t 320-02 green $g; done
done
for t in far-memop-length.ll far-access-non-65816.ll; do
  row $t 320-03 red-parent c-320-02; row $t 320-03 red-unrepaired p-320-03
  for g in c-320-03 c-320-04 c-fw-11 c-fw-14; do row $t 320-03 green $g; done
done
t=far-index-fold-debug.ll
row $t 320-04 red-parent c-320-03; row $t 320-04 red-unrepaired p-320-04
for g in c-320-04 c-fw-11 c-fw-14; do row $t 320-04 green $g; done
row $t fw-12 red-parent c-fw-11; row $t fw-12 red-unrepaired fw-old-candidate; row $t fw-12 green c-fw-14
} > "$OUT"
' _ "/work/${OUT#$ROOT/}" </dev/null
column -t -s$'\t' "$OUT" | cut -c1-200
