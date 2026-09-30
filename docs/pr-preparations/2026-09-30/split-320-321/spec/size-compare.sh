#!/usr/bin/env bash
# Compare total code size (llvm-size text+data) of default-mode objects for
# two llc binaries over the fixed input set, per mode.
#
# usage: size-compare.sh LLC_BEFORE LLC_AFTER
#   Both paths under /home/will/llvm-mos-65816. Inputs that fail with either
#   compiler are counted separately and excluded from the totals.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
A=/work/$(realpath --relative-to=$ROOT "$1"); B=/work/$(realpath --relative-to=$ROOT "$2")
cd "$ROOT"
dev/container.sh -- sh -c '
set -u; ulimit -c 0
A=$1; B=$2; IN=/work/build/split-320-321/default-inputs
SIZE=/work/build/split-320-321/build/bin/llvm-size
T=$(mktemp -d)
for mode in mos6502 mosw65816; do
  ta=0; tb=0; n=0; fail=0; up=0; down=0
  for f in "$IN"/tests/*.ll "$IN"/corpus/*.ll; do
    if timeout 120 "$A" -mtriple=mos -mcpu=$mode -O2 -filetype=obj "$f" -o "$T/a.o" 2>/dev/null &&
       timeout 120 "$B" -mtriple=mos -mcpu=$mode -O2 -filetype=obj "$f" -o "$T/b.o" 2>/dev/null; then
      sa=$("$SIZE" -A "$T/a.o" | awk "/^\.text|^\.data|^\.rodata/ {s+=\$2} END {print s+0}")
      sb=$("$SIZE" -A "$T/b.o" | awk "/^\.text|^\.data|^\.rodata/ {s+=\$2} END {print s+0}")
      ta=$((ta+sa)); tb=$((tb+sb)); n=$((n+1))
      [ "$sb" -gt "$sa" ] && up=$((up+1)); [ "$sb" -lt "$sa" ] && down=$((down+1))
    else fail=$((fail+1)); fi
  done
  echo "$mode: $n inputs, bytes $ta -> $tb (delta $((tb-ta))), larger $up, smaller $down, excluded $fail"
done
rm -rf "$T"
' _ "$A" "$B"
