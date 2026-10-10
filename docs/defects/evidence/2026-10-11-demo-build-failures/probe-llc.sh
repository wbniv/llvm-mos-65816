#!/usr/bin/env bash
# Replay the IR/MIR-level reproducers against a bare llc (no clang, no SDK), such
# as the frozen #320/#321 split-series builds under build/split-320-321/llc/.
#
# usage: probe-llc.sh LLC LABEL
#
# Writes runs/LABEL/<name>.log (command, llc hash, output, final `rc=N`) and
# runs/LABEL/summary.tsv. Run from the repository root.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
LLC=$(readlink -f "$1"); LABEL=$2
E=docs/defects/evidence/2026-10-11-demo-build-failures
OUT=$E/runs/$LABEL; mkdir -p "$OUT"
ulimit -c 0; ulimit -v 2000000
IDENT="llc=$LLC sha256=$(sha256sum "$LLC" | cut -d' ' -f1)"
: >"$OUT/summary.tsv"
run() { # NAME CMD...
  local name=$1; shift
  { echo "# $IDENT"; echo "# cwd=$(pwd)"; echo "\$ $*"; } >"$OUT/$name.log"
  local rc=0
  "$@" >>"$OUT/$name.log" 2>&1 || rc=$?
  echo "rc=$rc" >>"$OUT/$name.log"
  printf '%s\t%s\n' "$name" "$rc" >>"$OUT/summary.tsv"
}
run gallery-ir-llc "$LLC" -O2 -o /dev/null "$E/gallery/record-result-reduced.ll"
run gallery-ir-llc-basic "$LLC" -O2 -regalloc=basic -o /dev/null "$E/gallery/record-result-reduced.ll"
run ascast-sim-default-ir-llc "$LLC" -O2 -o /dev/null "$E/ascast/ascast_sim.default.Os.ll"
cat "$OUT/summary.tsv"
