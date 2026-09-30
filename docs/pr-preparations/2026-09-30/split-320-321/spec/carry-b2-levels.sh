#!/usr/bin/env bash
# Per-optimization-level effect of the B2 repair (lesson 4).
#
# usage: carry-b2-levels.sh OLD_LLC_LABEL NEW_LLC_LABEL OUT_DIR
# Inputs: far-memop-length.ll and far-memset.ll from the carried #320-3, as
# written and with every function forced to optsize (Os) or optsize+minsize (Oz)
# by `opt -passes=forceattrs`. Each is compiled at llc -O0..-O3 (Os/Oz at -O2,
# as clang does) in +mos-a16 and +mos-a16,+mos-xy16 by both llc binaries.
# Reports, per level and function, the far runtime entry each llc calls, and
# the object .text size of each input. Runs in the dev container with
# ulimit -c 0, ulimit -v 2000000 and timeouts.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
OLD=$1 NEW=$2 OUT=$3
ROOT=/home/will/llvm-mos-65816
SPLIT=$ROOT/build/split-320-321
mkdir -p "$OUT/in"
git -C "$SPLIT/source" show a56574564f44:llvm/test/CodeGen/MOS/far-memop-length.ll > "$OUT/in/far-memop-length.ll"
git -C "$SPLIT/source" show a56574564f44:llvm/test/CodeGen/MOS/far-memset.ll > "$OUT/in/far-memset.ll"
C_OUT=/work/${OUT#$ROOT/}
cd "$ROOT"
dev/container.sh -- bash -c '
set -uo pipefail; ulimit -c 0; ulimit -v 2000000
B=/work/build/split-320-321/build/bin; L=/work/build/split-320-321/llc; OLD=$1; NEW=$2; O=$3
cd $O
for f in far-memop-length far-memset; do
  timeout 60 $B/opt -S -passes=forceattrs -force-attribute=optsize in/$f.ll -o in/$f.Os.ll
  timeout 60 $B/opt -S -passes=forceattrs -force-attribute=optsize -force-attribute=minsize in/$f.ll -o in/$f.Oz.ll
done
printf "input\tmode\tlevel\tllc\trc\ttext_bytes\tcalls\n" > levels.tsv
for f in far-memop-length far-memset; do
 for m in a16 xy16; do
  a=+mos-a16; [ $m = xy16 ] && a=+mos-a16,+mos-xy16
  for lv in O0 O1 O2 O3 Os Oz; do
   in=in/$f.ll; opt=-$lv
   case $lv in Os) in=in/$f.Os.ll; opt=-O2;; Oz) in=in/$f.Oz.ll; opt=-O2;; esac
   for which in old new; do
    l=$OLD; [ $which = new ] && l=$NEW
    timeout 120 $L/$l -mtriple=mos -mcpu=mosw65816 -mattr=$a $opt -verify-machineinstrs $in -o $f.$m.$lv.$which.s 2>$f.$m.$lv.$which.err; rc=$?
    timeout 120 $L/$l -mtriple=mos -mcpu=mosw65816 -mattr=$a $opt -filetype=obj $in -o $f.$m.$lv.$which.o 2>/dev/null
    sz=$($B/llvm-size -A $f.$m.$lv.$which.o 2>/dev/null | awk "/^.text/{s+=\$2} END{print s+0}")
    calls=$(awk "/^[a-z_0-9]+:/{fn=\$1} /(jsr|jmp) __mem(set|cpy|move)_far/{print fn \$2}" $f.$m.$lv.$which.s | tr "\n" " ")
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" $f $m $lv $which $rc "$sz" "$calls" >> levels.tsv
   done
  done
 done
done
' _ "$OLD" "$NEW" "$C_OUT" </dev/null
python3 - "$OUT/levels.tsv" <<'EOF'
import sys, collections
rows=[l.rstrip('\n').split('\t') for l in open(sys.argv[1])][1:]
d=collections.defaultdict(dict)
for f,m,lv,w,rc,sz,calls in rows: d[(f,m,lv)][w]=(rc,int(sz),calls)
print('input\tmode\tlevel\told_rc\tnew_rc\ttext_old\ttext_new\tdelta\tcallees_changed')
for k,v in d.items():
    o,n=v['old'],v['new']
    oc=dict(c.split(':',1) for c in o[2].split() if ':' in c) if o[2] else {}
    nc=dict(c.split(':',1) for c in n[2].split() if ':' in c) if n[2] else {}
    ch=[f'{fn}->{nc.get(fn)}' for fn in sorted(set(oc)|set(nc)) if oc.get(fn)!=nc.get(fn)]
    print('\t'.join([*k,o[0],n[0],str(o[1]),str(n[1]),f'{n[1]-o[1]:+d}',' '.join(ch) or '-']))
EOF
