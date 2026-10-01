#!/usr/bin/env bash
# Default-mode hashes of the fixed input set on every MOS CPU (review N17).
#
# usage: default-hashes-cpus.sh LLC OUT.tsv [LEVEL...]
#   LLC    llc binary under /home/will/llvm-mos-65816 (run in the dev container)
#   OUT    TSV: level, input, cpu, asm rc, asm sha256|err:<hash>, obj rc, obj sha256
#   LEVEL  O0 O1 O2 O3 Os Oz (default: O2). Os/Oz use the optsize/minsize
#          copies made by default-hashes-levels.sh (default-inputs-levels/).
# CPUs: every -mcpu listed by `llc -mtriple=mos -mcpu=help`, no -mattr, so each
# CPU's own default features decide the mode. Inputs: default-inputs/{tests,corpus}.
# A crash is hashed from its innermost "Running pass" line, so the failing pass is kept and
# the llc file name is not. At most 3 llc processes run at once, each under
# ulimit -c 0, ulimit -v 2000000 and a 120 s timeout.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
LLC=$(realpath "$1"); OUT=$(realpath -m "$2"); shift 2
LEVELS=${*:-O2}
case "$LLC" in $ROOT/*) ;; *) echo "llc must live under $ROOT" >&2; exit 2;; esac
case "$OUT" in $ROOT/*) ;; *) echo "output must live under $ROOT" >&2; exit 2;; esac
C_LLC=/work/${LLC#$ROOT/}; C_OUT=/work/${OUT#$ROOT/}
cd "$ROOT"
dev/container.sh -- bash -c '
set -euo pipefail
LLC=$1; OUT=$2; LEVELS=$3; IN=/work/build/split-320-321/default-inputs
V=/work/build/split-320-321/default-inputs-levels
CPUS=$("$LLC" -mtriple=mos -mcpu=help 2>&1 | sed -n "/Available CPUs/,/Available features/p" | grep -oE "^ +mos[a-z0-9]+" | tr -d " " || true)
[ -n "$CPUS" ] || { echo "no CPUs listed" >&2; exit 2; }
T=$(mktemp -d)
one() {
  set +e
  lv=$1 f=$2 cpu=$3; rel=${f#$IN/}; in=$f; opt=-$lv
  case $lv in Os|Oz) in=$V/$lv/$(basename $(dirname $f))__$(basename $f); opt=-O2;; esac
  w=$(mktemp -d -p "$T")
  ( ulimit -c 0; ulimit -v 2000000; timeout 120 "$LLC" -mtriple=mos -mcpu=$cpu $opt "$in" -o $w/o.s 2>$w/e ); ra=$?
  ( ulimit -c 0; ulimit -v 2000000; timeout 120 "$LLC" -mtriple=mos -mcpu=$cpu $opt -filetype=obj "$in" -o $w/o.o 2>/dev/null ); ro=$?
  if [ $ra -eq 0 ]; then ha=$(sha256sum < $w/o.s | cut -c1-16)
  else m=$(grep "^[0-9]*\.[[:space:]]*Running pass" $w/e | tail -n1)
       [ -n "$m" ] || m=$(head -n1 $w/e)
       ha=err:$(printf "%s" "$m" | sed "s/[0-9]//g; s|/work/[^ :]*||g; s/@[^ ]*//g" | sha256sum | cut -c1-12); fi
  if [ $ro -eq 0 ]; then ho=$(sha256sum < $w/o.o | cut -c1-16); else ho=-; fi
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" $lv "$rel" $cpu $ra $ha $ro $ho
  rm -rf $w
}
export -f one; export LLC IN V T
for lv in $LEVELS; do for f in $IN/tests/*.ll $IN/corpus/*.ll; do for cpu in $CPUS; do
  printf "%s\n%s\n%s\n" $lv "$f" $cpu; done; done; done |
  xargs -d "\n" -n 3 -P 3 bash -c "one \"\$@\"" _ > "$OUT.tmp"
sort "$OUT.tmp" > "$OUT"; rm -f "$OUT.tmp"; rm -rf $T
' _ "$C_LLC" "$C_OUT" "$LEVELS"
wc -l < "$OUT"
