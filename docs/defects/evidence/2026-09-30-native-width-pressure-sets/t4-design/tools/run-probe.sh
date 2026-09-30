#!/usr/bin/env bash
# Run sizes.sh for each probe variant of a probe llc (hidden option
# -mos-native-pressure-probe=N, present only in the T4 probe build).
# usage: run-probe.sh LLC OUTDIR "N ..." [MODE ...]
#   writes OUTDIR/probeN.tsv per variant (4 in parallel)
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ulimit -c 0
E=$(cd "$(dirname "$0")" && pwd)
LLC=$1; O=$2; V=$3; shift 3
mkdir -p "$O"
for n in $V; do
  ( LLCFLAGS="-mos-native-pressure-probe=$n" bash "$E/sizes.sh" "$LLC" "$O/probe$n.tsv" "$@" > /dev/null
    echo "$(date -u +%H:%M:%S) probe$n done" ) &
done
wait
