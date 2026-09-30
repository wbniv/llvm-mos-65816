#!/usr/bin/env bash
# Compare total object size (.text+.data+.rodata) of two llc binaries over the
# fixed input set, per mode.
#
# usage: size-compare.sh LLC_REF LLC_CAND [MODE ...]
#   Both paths under /home/will/llvm-mos-65816. MODE is label=cpu[:features]
#   (default: mos6502=mos6502 mosw65816=mosw65816). Inputs that fail with
#   either compiler are counted separately and excluded from the totals.
# Env: INPUTS (container path, default /work/build/pressure-sets/default-inputs),
#      SIZE   (container path of llvm-size,
#              default /work/build/pressure-sets/build/bin/llvm-size).
# Derived from build/split-320-321/spec/size-compare.sh (modes parameterized).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
A=/work/$(realpath --relative-to=$ROOT "$1"); B=/work/$(realpath --relative-to=$ROOT "$2"); shift 2
[ $# -gt 0 ] || set -- mos6502=mos6502 mosw65816=mosw65816
IN=${INPUTS:-/work/build/pressure-sets/default-inputs}
SIZE=${SIZE:-/work/build/pressure-sets/build/bin/llvm-size}
cd "$ROOT"
dev/container.sh -- sh -c '
set -u; ulimit -c 0
A=$1; B=$2; IN=$3; SIZE=$4; shift 4
T=$(mktemp -d)
for spec in "$@"; do
  label=${spec%%=*}; rest=${spec#*=}; cpu=${rest%%:*}
  case "$rest" in *:*) attr="-mattr=${rest#*:}";; *) attr=;; esac
  ta=0; tb=0; n=0; fail=0; up=0; down=0
  for f in "$IN"/tests/*.ll "$IN"/corpus/*.ll; do
    if timeout 120 "$A" -mtriple=mos -mcpu=$cpu $attr -O2 -filetype=obj "$f" -o "$T/a.o" 2>/dev/null &&
       timeout 120 "$B" -mtriple=mos -mcpu=$cpu $attr -O2 -filetype=obj "$f" -o "$T/b.o" 2>/dev/null; then
      sa=$("$SIZE" -A "$T/a.o" | awk "/^\.text|^\.data|^\.rodata/ {s+=\$2} END {print s+0}")
      sb=$("$SIZE" -A "$T/b.o" | awk "/^\.text|^\.data|^\.rodata/ {s+=\$2} END {print s+0}")
      ta=$((ta+sa)); tb=$((tb+sb)); n=$((n+1))
      [ "$sb" -gt "$sa" ] && up=$((up+1)); [ "$sb" -lt "$sa" ] && down=$((down+1))
      [ "$sb" -ne "$sa" ] && echo "  $label ${f#$IN/}: $sa -> $sb" >> "$T/detail"
    else fail=$((fail+1)); fi
  done
  echo "$label: $n inputs, bytes $ta -> $tb (delta $((tb-ta))), larger $up, smaller $down, excluded $fail"
done
[ -f "$T/detail" ] && cat "$T/detail"
rm -rf "$T"
' _ "$A" "$B" "$IN" "$SIZE" "$@"
