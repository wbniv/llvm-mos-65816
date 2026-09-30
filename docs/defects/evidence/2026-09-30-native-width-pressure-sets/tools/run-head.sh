#!/usr/bin/env bash
# Phase A comparisons at series head c33eb63d65a3 (#321-16) with the change.
# usage: run-head.sh
set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,3p' "$0"; exit 0;; esac
ulimit -c 0
E=/home/will/llvm-mos-65816-pressure/docs/defects/evidence/2026-09-30-native-width-pressure-sets/tools
P=/home/will/llvm-mos-65816/build/pressure-sets
H=$P/runs-head; rm -rf $H; mkdir -p $H
M="a16=mosw65816:+mos-a16 a16xy16=mosw65816:+mos-a16,+mos-xy16"
( set +e; bash $E/default-identity.sh $P/llc/321-00 $P/llc/321-16-cand1 $H/default-vs-upstream > $H/default-vs-upstream.log 2>&1; echo "exit=$?" >> $H/default-vs-upstream.log ) &
( set +e; bash $E/default-identity.sh $P/llc/321-16 $P/llc/321-16-cand1 $H/default-vs-head > $H/default-vs-head.log 2>&1; echo "exit=$?" >> $H/default-vs-head.log
  bash $E/size-compare.sh $P/llc/321-16 $P/llc/321-16-cand1 > $H/default-size-vs-head.txt 2>&1; echo "exit=$?" >> $H/default-size-vs-head.txt ) &
( set +e; R=$H/native; mkdir -p $R
  bash $E/mode-hashes.sh $P/llc/321-16 $R/ref.tsv $M && bash $E/mode-hashes.sh $P/llc/321-16-cand1 $R/cand.tsv $M
  python3 $E/compare-hashes.py $R/ref.tsv $R/cand.tsv --names > $R/compare.txt; echo "exit=$?" >> $R/compare.txt
  bash $E/size-compare.sh $P/llc/321-16 $P/llc/321-16-cand1 $M > $R/size.txt 2>&1; echo "exit=$?" >> $R/size.txt ) &
wait
echo done
