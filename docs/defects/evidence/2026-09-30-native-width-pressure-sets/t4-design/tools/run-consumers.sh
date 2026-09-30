#!/usr/bin/env bash
# Pass-ablation matrix in native modes: unchanged head (321-16) and the Phase A
# candidate at head (321-16-cand1), each with no flag and with each pressure
# consumer disabled. Writes build/pressure-sets/t4/consumers/<llc>.<variant>.tsv
# usage: run-consumers.sh [JOBS]   (default 4 parallel containers)
set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ulimit -c 0
J=${1:-4}
E=$(cd "$(dirname "$0")" && pwd)
P=/home/will/llvm-mos-65816/build/pressure-sets
O=$P/t4/consumers; mkdir -p "$O"
jobs=()
for llc in 321-16 321-16-cand1; do
  for v in none licm sink misched all; do
    case $v in
      none) fl="";; licm) fl="-disable-machine-licm";; sink) fl="-disable-machine-sink";;
      misched) fl="-enable-misched=false";;
      all) fl="-disable-machine-licm -disable-machine-sink -enable-misched=false";;
    esac
    jobs+=("$llc|$v|$fl")
  done
done
printf '%s\n' "${jobs[@]}" | xargs -P "$J" -I{} bash -c '
  IFS="|" read -r llc v fl <<< "{}"
  LLCFLAGS="$fl" bash "'"$E"'/sizes.sh" "'"$P"'/llc/$llc" "'"$O"'/$llc.$v.tsv" > /dev/null
  echo "$(date -u +%H:%M:%S) $llc.$v done"'
