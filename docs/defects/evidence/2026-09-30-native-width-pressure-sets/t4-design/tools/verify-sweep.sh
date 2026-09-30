#!/usr/bin/env bash
# -verify-machineinstrs over the fixed set in the given modes, one llc.
# usage: verify-sweep.sh LLC OUT.tsv [MODE ...]
#   OUT columns: input, mode, rc, first diagnostic line (digits and /work
#   paths removed; "-" when clean). MODE as in sizes.sh (default: the two
#   native modes).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
LLC=$(realpath "$1"); OUT=$(realpath -m "$2"); shift 2
[ $# -gt 0 ] || set -- a16=mosw65816:+mos-a16 a16xy16=mosw65816:+mos-a16,+mos-xy16
C_LLC=/work/${LLC#$ROOT/}; C_OUT=/work/${OUT#$ROOT/}
IN=${INPUTS:-/work/build/pressure-sets/default-inputs}
cd "$ROOT"
dev/container.sh -- sh -c '
set -eu; ulimit -c 0
LLC=$1; OUT=$2; IN=$3; shift 3
T=$(mktemp -d); : > "$OUT.tmp"
for f in "$IN"/tests/*.ll "$IN"/corpus/*.ll; do
  rel=${f#$IN/}
  for spec in "$@"; do
    label=${spec%%=*}; rest=${spec#*=}; cpu=${rest%%:*}
    case "$rest" in *:*) attr="-mattr=${rest#*:}";; *) attr=;; esac
    set +e
    timeout 180 "$LLC" -mtriple=mos -mcpu=$cpu $attr -O2 -verify-machineinstrs -filetype=obj "$f" -o /dev/null 2>"$T/e"; rc=$?
    set -e
    if [ $rc -eq 0 ]; then d=-; else d=$(grep -m1 -E "error|Bad machine|LLVM ERROR|Assertion" "$T/e" | sed "s/[0-9]//g; s|/work/[^ :]*||g" | cut -c1-120); fi
    printf "%s\t%s\t%s\t%s\n" "$rel" "$label" "$rc" "$d" >> "$OUT.tmp"
  done
done
mv "$OUT.tmp" "$OUT"; rm -rf "$T"
' _ "$C_LLC" "$C_OUT" "$IN" "$@"
wc -l < "$OUT"
