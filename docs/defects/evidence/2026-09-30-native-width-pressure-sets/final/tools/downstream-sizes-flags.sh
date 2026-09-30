#!/usr/bin/env bash
# Object bytes of the downstream baseline and candidate llc over the IR that
# downstream-codegen.sh emitted, with extra llc flags.
#
# usage: downstream-sizes-flags.sh MODE [LLC_FLAGS...]
#   MODE  default, a16 or a16xy16 (rows of codegen/results.tsv with status ok)
# Prints: MODE flags[...]: N inputs, BASE -> CAND (delta), larger, smaller.
# Every llc runs under ulimit -c 0, ulimit -v 2000000 and timeout 300.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
M=$1; shift
D=/home/will/llvm-mos-65816/build/pressure-sets/final/downstream/codegen
B=/home/will/llvm-mos-65816/build/far-review-defects/candidate/llc
C=/home/will/llvm-mos-65816/build/pressure-sets/final/downstream/llc
S=/home/will/llvm-mos-65816/build/llvm-mos-install/bin/llvm-size
W=$(mktemp -d)
tb=0; tc=0; n=0; up=0; dn=0
for rel in $(awk -F'\t' -v m=$M '$2==m && $3=="ok"{print $1}' $D/results.tsv); do
  stem=$(echo $rel | tr / _); ir=$D/ir/$stem.$M.ll
  ( ulimit -c 0; ulimit -v 2000000; timeout 300 $B -O2 "$@" -filetype=obj $ir -o $W/b.o 2>/dev/null ) || continue
  ( ulimit -c 0; ulimit -v 2000000; timeout 300 $C -O2 "$@" -filetype=obj $ir -o $W/c.o 2>/dev/null ) || continue
  sb=$($S -A $W/b.o | awk '/^\.text|^\.data|^\.rodata/ {s+=$2} END {print s+0}')
  sc=$($S -A $W/c.o | awk '/^\.text|^\.data|^\.rodata/ {s+=$2} END {print s+0}')
  tb=$((tb+sb)); tc=$((tc+sc)); n=$((n+1)); [ $sc -gt $sb ] && up=$((up+1)); [ $sc -lt $sb ] && dn=$((dn+1))
done
echo "$M flags[$*]: $n inputs, $tb -> $tc ($((tc-tb))), larger $up, smaller $dn"
rm -rf $W
