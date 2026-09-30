#!/usr/bin/env bash
# Run every second-review B8/B9 probe on the reviewed and second-round llcs.
#
# usage: r2-b8-sweep.sh OUT.tsv LLC_LABEL...
# Probes: build/split-320-321/probe-review2/*.ll (far and near shapes, the
# quad spill loop). Each runs with -verify-machineinstrs at O0 and O2 in plain
# mosw65816, +mos-a16 and +mos-a16,+mos-xy16 (near probes also on mos6502).
# Columns: probe, llc, mode, level, exit code, signature (first diagnostic).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
OUT=$(realpath -m "$1"); shift
cd "$ROOT"
dev/container.sh -- bash -c '
set -uo pipefail; ulimit -c 0; ulimit -v 2000000
OUT=$1; shift; P=/work/build/split-320-321/probe-review2; L=/work/build/split-320-321/llc
printf "probe\tllc\tmode\tlevel\trc\tsignature\n" > "$OUT"
for l in "$@"; do for f in $P/*.ll; do b=$(basename $f .ll)
  case $b in n*) modes="mos6502 mosw65816";; *) modes="mosw65816 mosw65816:+mos-a16 mosw65816:+mos-a16,+mos-xy16";; esac
  for m in $modes; do cpu=${m%%:*}; a=; [ "$m" != "$cpu" ] && a=-mattr=${m#*:}
    for o in O0 O2; do
      timeout 120 $L/$l -mtriple=mos -mcpu=$cpu $a -$o -verify-machineinstrs $f -o /dev/null 2>/tmp/e
      rc=$?
      sig=$(grep -m1 -oE "Generic virtual register use cannot be undef|Assertion.*|LLVM ERROR.*" /tmp/e | cut -c1-90)
      printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$b" "$l" "$m" "$o" "$rc" "$sig" >> "$OUT"
    done; done; done; done
' _ "/work/${OUT#$ROOT/}" "$@" </dev/null
