#!/usr/bin/env bash
# usage: runlog.sh LOG LLC ARGS...   (run from the main checkout; records command, llc sha256, diagnostics, exit)
set -uo pipefail
case "${1-}" in -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
log=$1; shift; llc=$1
ulimit -c 0
ulimit -v 2000000
{
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) COMMAND: $*"
  echo "llc sha256: $(sha256sum "$llc" | cut -d' ' -f1)"
  "$@" 2>&1 | grep -E 'Bad machine code|^- function|^- basic block|^- instruction|^- operand|LLVM ERROR' | sed 's/(0x[0-9a-f]*)/(addr)/'
  echo "EXIT: ${PIPESTATUS[0]}"
} > "$log" 2>&1
tail -1 "$log"
