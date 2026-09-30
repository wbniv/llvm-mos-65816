#!/usr/bin/env bash
# Default-mode hashes of the fixed input set at every optimization level.
#
# usage: default-hashes-levels.sh LLC OUT.tsv
# Levels: llc -O0, -O1, -O2, -O3, and -O2 on inputs whose functions opt
# forced to optsize (Os) or optsize+minsize (Oz). Modes: mos6502 and plain
# mosw65816. Columns: level, input, mode, asm rc, asm sha256, obj rc, obj sha256.
# Runs in the dev container with ulimit -c 0, ulimit -v 2000000 and timeouts.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
LLC=$(realpath "$1"); OUT=$(realpath -m "$2")
cd "$ROOT"
dev/container.sh -- bash -c '
set -u; ulimit -c 0; ulimit -v 2000000
LLC=$1; OUT=$2; IN=/work/build/split-320-321/default-inputs; B=/work/build/split-320-321/build/bin
V=/work/build/split-320-321/default-inputs-levels
if [ ! -d $V ]; then mkdir -p $V/Os $V/Oz
  for f in $IN/tests/*.ll $IN/corpus/*.ll; do r=$(basename $(dirname $f))__$(basename $f)
    timeout 60 $B/opt -S -passes=forceattrs -force-attribute=optsize $f -o $V/Os/$r 2>/dev/null
    timeout 60 $B/opt -S -passes=forceattrs -force-attribute=optsize -force-attribute=minsize $f -o $V/Oz/$r 2>/dev/null
  done; fi
T=$(mktemp -d); : > "$OUT.tmp"
for lv in O0 O1 O2 O3 Os Oz; do
  for f in $IN/tests/*.ll $IN/corpus/*.ll; do r=$(basename $(dirname $f))__$(basename $f); in=$f; opt=-$lv
    case $lv in Os|Oz) in=$V/$lv/$r; opt=-O2; [ -s $in ] || continue;; esac
    for mode in mos6502 mosw65816; do
      timeout 120 "$LLC" -mtriple=mos -mcpu=$mode $opt "$in" -o "$T/o.s" 2>"$T/e"; ra=$?
      timeout 120 "$LLC" -mtriple=mos -mcpu=$mode $opt -filetype=obj "$in" -o "$T/o.o" 2>/dev/null; ro=$?
      if [ $ra -eq 0 ]; then ha=$(sha256sum < "$T/o.s" | cut -c1-16); else ha=err:$(grep -m1 -oE "Assertion.*|LLVM ERROR.*|error:.*" "$T/e" | sed "s/[0-9]//g; s|/work/[^ :]*||g" | sha256sum | cut -c1-12); fi
      if [ $ro -eq 0 ]; then ho=$(sha256sum < "$T/o.o" | cut -c1-16); else ho=-; fi
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" $lv "$r" $mode $ra "$ha" $ro "$ho" >> "$OUT.tmp"
      rm -f "$T/o.s" "$T/o.o"
    done; done; done
mv "$OUT.tmp" "$OUT"; rm -rf "$T"
' _ "/work/${LLC#$ROOT/}" "/work/${OUT#$ROOT/}" </dev/null
