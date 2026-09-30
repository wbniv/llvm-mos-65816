#!/usr/bin/env bash
# Hash default-mode codegen for the fixed input set with one llc binary.
#
# usage: default-hashes.sh LLC OUT.tsv
#   LLC     llc binary (path under /home/will/llvm-mos-65816, run in the dev container)
#   OUT     TSV: input, mode, asm rc, asm sha256, obj rc, obj sha256
# Modes: -mcpu=mos6502 and plain -mcpu=mosw65816 (no +mos-a16/+mos-xy16).
# Inputs: build/split-320-321/default-inputs/{tests,corpus}/*.ll (fixed set:
# the MOS CodeGen .ll tests at 06bc967d2668 plus every 8th frozen corpus IR,
# target-cpu/target-features attributes stripped so -mcpu decides the mode).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
LLC=$(realpath "$1"); OUT=$(realpath -m "$2")
case "$LLC" in $ROOT/*) ;; *) echo "llc must live under $ROOT" >&2; exit 2;; esac
case "$OUT" in $ROOT/*) ;; *) echo "output must live under $ROOT" >&2; exit 2;; esac
C_LLC=/work/${LLC#$ROOT/}; C_OUT=/work/${OUT#$ROOT/}
cd "$ROOT"
dev/container.sh -- sh -c '
set -eu
ulimit -c 0; ulimit -v 2000000
LLC=$1; OUT=$2; IN=/work/build/split-320-321/default-inputs
T=$(mktemp -d)
: > "$OUT.tmp"
for f in "$IN"/tests/*.ll "$IN"/corpus/*.ll; do
  rel=${f#$IN/}
  for mode in mos6502 mosw65816; do
    set +e
    timeout 120 "$LLC" -mtriple=mos -mcpu=$mode -O2 "$f" -o "$T/o.s" 2>"$T/e"; ra=$?
    timeout 120 "$LLC" -mtriple=mos -mcpu=$mode -O2 -filetype=obj "$f" -o "$T/o.o" 2>/dev/null; ro=$?
    set -e
    if [ $ra -eq 0 ]; then ha=$(sha256sum < "$T/o.s" | cut -c1-16); else ha=err:$(head -n1 "$T/e" | sed "s/[0-9]//g; s|/work/[^ :]*||g" | sha256sum | cut -c1-12); fi
    if [ $ro -eq 0 ]; then ho=$(sha256sum < "$T/o.o" | cut -c1-16); else ho=-; fi
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$rel" "$mode" "$ra" "$ha" "$ro" "$ho" >> "$OUT.tmp"
    rm -f "$T/o.s" "$T/o.o"
  done
done
mv "$OUT.tmp" "$OUT"
rm -rf "$T"
' _ "$C_LLC" "$C_OUT"
wc -l < "$OUT"
