#!/usr/bin/env bash
# Explain an object-only difference between two llc binaries on one input.
#
# usage: obj-diff.sh LLC_A LLC_B INPUT MODE
# Prints mapping-symbol counts for each object and whether every allocated
# section's bytes and the relocation list are identical.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
c() { echo "/work/$(realpath --relative-to=$ROOT "$1")"; }
A=$(c "$1"); Bl=$(c "$2"); IN=$(c "$3")
cd "$ROOT"
dev/container.sh -- bash -c '
set -eu; ulimit -c 0
B=/work/build/split-320-321/build/bin; T=$(mktemp -d)
"$1" -mtriple=mos -mcpu=$4 -O2 -filetype=obj "$3" -o $T/a.o
"$2" -mtriple=mos -mcpu=$4 -O2 -filetype=obj "$3" -o $T/b.o
for v in a b; do
  echo "$v mapping symbols: $($B/llvm-readelf -s $T/$v.o | awk "{print \$8}" | grep "^\\$" | sed "s/\\..*//" | sort | uniq -c | tr -s " " | tr "\n" " ")"
  for s in $($B/llvm-readelf -S $T/$v.o | grep -E "PROGBITS|NOBITS" | sed -E "s/.*\] +([^ ]+).*/\1/"); do
    echo "== $s"; $B/llvm-readelf -x "$s" $T/$v.o | tail -n +2
  done > $T/$v.sec
  $B/llvm-readelf -r $T/$v.o | sed -E "s/at offset 0x[0-9a-f]+//" | awk "{\$2=\"\"; print}" > $T/$v.rel
done
echo "sections: $(grep -c "^==" $T/a.sec) vs $(grep -c "^==" $T/b.sec)"
cmp -s $T/a.sec $T/b.sec && echo "section bytes: identical" || echo "section bytes: DIFFER"
cmp -s $T/a.rel $T/b.rel && echo "relocations (symbol index column ignored): identical" || echo "relocations: DIFFER"
rm -rf $T
' _ "$A" "$Bl" "$IN" "$4"
