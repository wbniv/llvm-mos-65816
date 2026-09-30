#!/usr/bin/env bash
# Summarize the optimization-level matrix: native sizes per level and variant
# against unchanged 321-16 (frozen t4-design size-diff.py), and default-mode
# identity per level (frozen compare-hashes.py): upstream vs 321-01-t4 at
# #321-1; Phase A candidate vs 321-16-t4 and 321-16-t4 vs the gate probe at
# head.
#
# usage: summarize.sh RUNS_DIR [LEVEL ...]   (default levels: Os Oz O2 O3)
# Exit 1 when any default-identity comparison differs.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
EV="$(cd "$(dirname "$0")/../.." && pwd)"
R=$1; shift
[ $# -gt 0 ] || set -- Os Oz O2 O3
SD=$EV/t4-design/tools/size-diff.py; CH=$EV/tools/compare-hashes.py
bad=0
for L in "$@"; do
  g=1; case $L in O2|O3) g=2;; esac
  echo "################ level $L"
  for v in t4 gate$g memb1 cand1; do
    echo "=== native bytes, 321-16 -> $v"
    python3 "$SD" "$R/$L.head.tsv" "$R/$L.$v.tsv" --top 3
  done
  for pair in "upstream t4-01" "cand1 t4" "t4 gate$g"; do
    set -- $pair
    echo "=== default identity, $1 -> $2"
    rc=0; python3 "$CH" "$R/$L.def.$1.tsv" "$R/$L.def.$2.tsv" || rc=$?
    echo "exit $rc"; [ $rc -eq 0 ] || bad=1
  done
done
exit $bad
