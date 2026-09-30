#!/usr/bin/env bash
# Red/green matrix for the tests the second round adds or extends.
#
# usage: r2-red-green.sh OUT.tsv
# Each probe-r2/<commit>__<test> version runs (run-test-with.py) against its
# parent's llc (red), the reviewed commit's llc where one exists (red: the
# unrepaired version), and its own and every later second-round llc (green).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
OUT=$(realpath -m "$1"); case "$OUT" in $ROOT/*) ;; *) echo "OUT must be under $ROOT" >&2; exit 2;; esac
cd "$ROOT"
dev/container.sh -- bash -c '
set -uo pipefail
S=/work/build/split-320-321; P=$S/probe-r2; L=$S/llc; OUT=$1
ORDER="r2-320-1a3 r2-320-1b r2-320-1c r2-320-1d r2-320-2 r2-320-3 r2-320-4 r2-fw-9 r2-fw-5 r2-fw-6 r2-fw-7 r2-fw-8 r2-fw-11 r2-fw-14"
row() { # version test role label
  local f=$P/$1__$2 llc=$L/$4
  local h; h=$(sha256sum "$llc" | cut -c1-16)
  local r; r=$(python3 $S/spec/run-test-with.py "$llc" "$f" 2>&1 | head -1)
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$2" "$1" "$3" "$4" "$h" "${r%% *}" "${r#* }"
}
greens() { local on=0; for l in $ORDER; do [ "$l" = "$1" ] && on=1; [ $on = 1 ] && echo $l; done; }
t() { # version test parent unrepaired own-label
  row $1 $2 red-parent $3
  [ -n "$4" ] && row $1 $2 red-unrepaired $4
  for g in $(greens $5); do row $1 $2 green $g; done
}
{
printf "test\tversion\trole\tllc\tllc_sha256_16\tresult\tfirst_diagnostic\n"
t 320-1b imag32-reserved-pairs.ll r2-320-1a3 "" r2-320-1b
t 320-1c imag32-allocation-gate.mir r2-320-1b "" r2-320-1c
t 320-1c far-ptr-arg-exhaustion.ll r2-320-1b c-320-01 r2-320-1c
t 320-1d prologepilog.mir r2-320-1c "" r2-320-1d
t 320-2 far-ptr-arg-exhaustion.ll r2-320-1d c-320-02 r2-320-2
t 320-2 far-quad-spill-call.ll r2-320-1d c-320-02 r2-320-2
t 320-2 far-access-non-65816.ll r2-320-1d c-320-02 r2-320-2
t 320-2 far-fold-debug.ll r2-320-1d c-320-02 r2-320-2
t 320-2 far-ptr-trunc.ll r2-320-1d p-320-02 r2-320-2
t 320-3 far-memop-length.ll r2-320-2 p-320-03 r2-320-3
t 320-4 far-fold-debug.ll r2-320-3 c-320-04 r2-320-4
t 320-4 far-index-fold-debug.ll r2-320-3 p-320-04 r2-320-4
t fw-9 native-index-copy-cost.mir r2-320-4 "" r2-fw-9
t fw-5 far-global-long-x.ll r2-fw-9 "" r2-fw-5
t fw-5 far-fold-debug.ll r2-fw-9 c-fw-14 r2-fw-5
t fw-12 far-index-fold-debug.ll r2-fw-11 fw-old r2-fw-14
} > "$OUT"
' _ "/work/${OUT#$ROOT/}" </dev/null
ln -sf /home/will/llvm-mos-65816/build/far-word-rebase/candidate/llc /home/will/llvm-mos-65816/build/split-320-321/llc/fw-old 2>/dev/null || true
awk -F'\t' 'NR>1{k=($3 ~ /red/)?"red":"green"; print k, $6}' "$1" | sort | uniq -c
awk -F'\t' 'NR>1 && (($3 ~ /red/ && $6!="FAIL") || ($3=="green" && $6!="PASS"))' "$1"
