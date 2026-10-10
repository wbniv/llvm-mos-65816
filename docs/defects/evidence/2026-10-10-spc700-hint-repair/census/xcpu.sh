#!/usr/bin/env bash
# Usage: xcpu.sh LLCNAME CPU
# Compile the 52 default-mode corpus IRs at -O2 for CPU with the frozen LLCNAME
# and record per-input exit codes and assembly under xcpu/LLCNAME-CPU/.
set -uo pipefail
case "${1:-}" in -h|--help) sed -n '2,4p' "$0"; exit 0;; esac
L=/home/will/llvm-mos-65816/build/spc700-hint/llc/$1; CPU=$2
O=xcpu/$1-$CPU; mkdir -p "$O"
ulimit -c 0; ulimit -v 2000000
for f in /home/will/llvm-mos-65816/build/split-320-321/default-inputs/corpus/*.ll; do
  b=$(basename "$f" .c.default.ll)
  timeout 300 "$L" -mtriple=mos -mcpu="$CPU" -O2 -disable-spill-hoist "$f" -o "$O/$b.s" >/dev/null 2>&1
  echo "$b $?"
done > "$O.rc"
