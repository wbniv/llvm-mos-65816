#!/usr/bin/env bash
# Per-input object size and asm/object hashes of one llc over the fixed set,
# for one or more modes, with optional extra llc flags.
#
# usage: [LLCFLAGS="..."] sizes.sh LLC OUT.tsv [MODE ...]
#   LLC   llc binary under /home/will/llvm-mos-65816 (runs in the dev container)
#   OUT   TSV under /home/will/llvm-mos-65816. Columns: input, mode, size
#         (.text+.data+.rodata of the object, or "fail"), asm sha256/16,
#         object sha256/16
#   MODE  label=cpu[:features]; default a16=mosw65816:+mos-a16
#         a16xy16=mosw65816:+mos-a16,+mos-xy16
# Env: LLCFLAGS  extra llc options (e.g. "-disable-machine-licm")
#      INPUTS    container path of the input set
#                (default /work/build/pressure-sets/default-inputs)
#      SIZE      container path of llvm-size
#                (default /work/build/pressure-sets/build/bin/llvm-size)
# Compare two outputs with size-diff.py. Derived from the Phase A tools
# mode-hashes.sh and size-compare.sh (one llc per run, per-input rows, flags).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
LLC=$(realpath "$1"); OUT=$(realpath -m "$2"); shift 2
[ $# -gt 0 ] || set -- a16=mosw65816:+mos-a16 a16xy16=mosw65816:+mos-a16,+mos-xy16
case "$LLC" in $ROOT/*) ;; *) echo "llc must live under $ROOT" >&2; exit 2;; esac
case "$OUT" in $ROOT/*) ;; *) echo "output must live under $ROOT" >&2; exit 2;; esac
C_LLC=/work/${LLC#$ROOT/}; C_OUT=/work/${OUT#$ROOT/}
IN=${INPUTS:-/work/build/pressure-sets/default-inputs}
SIZE=${SIZE:-/work/build/pressure-sets/build/bin/llvm-size}
cd "$ROOT"
dev/container.sh -- sh -c '
set -eu
ulimit -c 0
LLC=$1; OUT=$2; IN=$3; SIZE=$4; FL=$5; shift 5
T=$(mktemp -d)
: > "$OUT.tmp"
for f in "$IN"/tests/*.ll "$IN"/corpus/*.ll; do
  rel=${f#$IN/}
  for spec in "$@"; do
    label=${spec%%=*}; rest=${spec#*=}; cpu=${rest%%:*}
    case "$rest" in *:*) attr="-mattr=${rest#*:}";; *) attr=;; esac
    set +e
    timeout 120 "$LLC" -mtriple=mos -mcpu=$cpu $attr -O2 $FL "$f" -o "$T/o.s" 2>/dev/null; ra=$?
    timeout 120 "$LLC" -mtriple=mos -mcpu=$cpu $attr -O2 $FL -filetype=obj "$f" -o "$T/o.o" 2>/dev/null; ro=$?
    set -e
    if [ $ra -eq 0 ]; then ha=$(sha256sum < "$T/o.s" | cut -c1-16); else ha=err; fi
    if [ $ro -eq 0 ]; then
      ho=$(sha256sum < "$T/o.o" | cut -c1-16)
      sz=$("$SIZE" -A "$T/o.o" | awk "/^\.text|^\.data|^\.rodata/ {s+=\$2} END {print s+0}")
    else ho=-; sz=fail; fi
    printf "%s\t%s\t%s\t%s\t%s\n" "$rel" "$label" "$sz" "$ha" "$ho" >> "$OUT.tmp"
    rm -f "$T/o.s" "$T/o.o"
  done
done
mv "$OUT.tmp" "$OUT"
rm -rf "$T"
' _ "$C_LLC" "$C_OUT" "$IN" "$SIZE" "${LLCFLAGS:-}" "$@"
wc -l < "$OUT"
