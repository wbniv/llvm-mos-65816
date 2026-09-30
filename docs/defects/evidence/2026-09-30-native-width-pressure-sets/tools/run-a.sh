#!/usr/bin/env bash
# Phase A comparisons at #321-1: baseline red, candidate green, native effect.
# usage: run-a.sh
set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,3p' "$0"; exit 0;; esac
ulimit -c 0
E=/home/will/llvm-mos-65816-pressure/docs/defects/evidence/2026-09-30-native-width-pressure-sets/tools
P=/home/will/llvm-mos-65816/build/pressure-sets
rm -rf $P/runs; mkdir -p $P/runs
M="a16=mosw65816:+mos-a16 a16xy16=mosw65816:+mos-a16,+mos-xy16"
( set +e; bash $E/default-identity.sh $P/llc/321-00 $P/llc/321-01 $P/runs/baseline > $P/runs/baseline.log 2>&1; echo "exit=$?" >> $P/runs/baseline.log ) &
( set +e; bash $E/default-identity.sh $P/llc/321-00 $P/llc/321-01-cand1 $P/runs/cand1-default > $P/runs/cand1-default.log 2>&1; echo "exit=$?" >> $P/runs/cand1-default.log ) &
( set +e; R=$P/runs/cand1-native; mkdir -p $R
  bash $E/mode-hashes.sh $P/llc/321-01 $R/ref.tsv $M && bash $E/mode-hashes.sh $P/llc/321-01-cand1 $R/cand.tsv $M
  python3 $E/compare-hashes.py $R/ref.tsv $R/cand.tsv --names > $R/compare.txt; echo "exit=$?" >> $R/compare.txt
  bash $E/size-compare.sh $P/llc/321-01 $P/llc/321-01-cand1 $M > $R/size.txt 2>&1; echo "exit=$?" >> $R/size.txt ) &
wait
echo done
