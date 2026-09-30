#!/usr/bin/env bash
# Derive a per-optimization-level copy of the frozen fixed input set by
# changing only the size attributes on function definitions.
#
# usage: make-level-inputs.sh LEVEL OUTDIR
#   LEVEL   Os  add optsize to every defined function (clang -Os)
#           Oz  add optsize and minsize (clang -Oz)
#           O2  remove optsize and minsize everywhere (clang -O2/-O3)
#   OUTDIR  under /home/will/llvm-mos-65816; receives tests/ and corpus/
# The frozen set (build/pressure-sets/default-inputs) is IR after clang's
# middle end at -Os for the corpus files and hand-written IR for the MOS
# CodeGen tests. Only function attributes change here: opt's forceattrs pass
# adds the attribute to the definitions named in a per-file CSV (it skips
# declarations and never adds optsize/minsize to an optnone function), or
# removes it. Everything else is re-printed unchanged.
# Env: OPT  container path of opt
#           (default /work/build/pressure-sets/build-head/bin/opt)
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
[ $# -eq 2 ] || { echo "need LEVEL OUTDIR" >&2; exit 2; }
ROOT=/home/will/llvm-mos-65816
LEVEL=$1; OUT=$(realpath -m "$2")
case "$LEVEL" in Os|Oz|O2) ;; *) echo "LEVEL must be Os, Oz or O2" >&2; exit 2;; esac
case "$OUT" in $ROOT/*) ;; *) echo "OUTDIR must live under $ROOT" >&2; exit 2;; esac
C_OUT=/work/${OUT#$ROOT/}
OPT=${OPT:-/work/build/pressure-sets/build-head/bin/opt}
mkdir -p "$OUT/tests" "$OUT/corpus"
cd "$ROOT"
dev/container.sh -- sh -c '
set -eu
ulimit -c 0; ulimit -v 2000000
LEVEL=$1; OUT=$2; OPT=$3; IN=/work/build/pressure-sets/default-inputs
case $LEVEL in Os) attrs="optsize";; Oz) attrs="optsize minsize";; O2) attrs=;; esac
fails=0
for f in "$IN"/tests/*.ll "$IN"/corpus/*.ll; do
  rel=${f#$IN/}
  if [ "$LEVEL" = O2 ]; then
    set +e
    timeout 60 "$OPT" -S -passes=forceattrs -force-remove-attribute=optsize \
      -force-remove-attribute=minsize "$f" -o "$OUT/$rel" 2>"$OUT/$rel.err"; rc=$?
    set -e
  else
    csv=$OUT/$rel.csv; : > "$csv"
    sed -n "s/^define [^@]*@\"\{0,1\}\([^\"(]*\)\"\{0,1\}(.*/\1/p" "$f" | while read -r fn; do
      for a in $attrs; do printf "%s,%s\n" "$fn" "$a" >> "$csv"; done
    done
    set +e
    timeout 60 "$OPT" -S -passes=forceattrs -forceattrs-csv-path="$csv" "$f" \
      -o "$OUT/$rel" 2>"$OUT/$rel.err"; rc=$?
    set -e
    rm -f "$csv"
  fi
  if [ $rc -ne 0 ] || [ -s "$OUT/$rel.err" ]; then
    echo "FAIL rc=$rc $rel: $(head -n1 "$OUT/$rel.err")"; fails=$((fails+1))
  else rm -f "$OUT/$rel.err"; fi
done
echo "level $LEVEL: $(ls "$OUT"/tests/*.ll "$OUT"/corpus/*.ll | wc -l) files, $fails failures"
' _ "$LEVEL" "$C_OUT" "$OPT"
