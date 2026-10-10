#!/usr/bin/env bash
# usage: mirlog.sh LOG LLC TEST   (pass + verifier + FileCheck)
set -uo pipefail
case "${1-}" in -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
log=$1; llc=$2; t=$3
ulimit -c 0
ulimit -v 2000000
{
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) COMMAND: $llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -run-pass=mos-insert-rep-sep -verify-machineinstrs $t -o - | FileCheck $t"
  echo "llc sha256: $(sha256sum "$llc" | cut -d' ' -f1)"
  "$llc" -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -run-pass=mos-insert-rep-sep -verify-machineinstrs "$t" -o - 2>"$log.err" | build/llvm-mos/bin/FileCheck "$t" 2>&1 | head -5
  rc=("${PIPESTATUS[@]}")
  grep -E 'Bad machine code|^- function|^- instruction|LLVM ERROR' "$log.err" | sed 's/(0x[0-9a-f]*)/(addr)/'
  rm -f "$log.err"
  echo "LLC_EXIT: ${rc[0]} FILECHECK_EXIT: ${rc[1]}"
} > "$log" 2>&1
tail -1 "$log"
