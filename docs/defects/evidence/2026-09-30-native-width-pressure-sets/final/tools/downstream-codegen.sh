#!/usr/bin/env bash
# Codegen the SNES corpus and demo sources with two downstream llc binaries
# from the same frontend IR, per mode, and compare the objects.
#
# usage: downstream-codegen.sh BASE_LLC CAND_LLC OUTDIR
#   BASE_LLC, CAND_LLC  llc binaries under /home/will/llvm-mos-65816
#   OUTDIR              under /home/will/llvm-mos-65816; receives ir/, obj/,
#                       results.tsv (source, mode, status, base bytes, cand
#                       bytes, identical) and summary.txt
# Sources: examples/snes/corpus/*.c and the examples/snes/<slug>.c of
# dev/build-determinism-demo-set.txt. The frontend is the installed project
# clang (build/llvm-mos-install) with mos-snes.cfg, -mcpu=mosw65816, -Os,
# -fno-lto, emitting IR once per mode (default, +mos-a16, +mos-a16,+mos-xy16);
# both llc binaries compile that IR at -O2 (clang -Os codegens at -O2). Every
# clang/llc run is under ulimit -c 0, ulimit -v 2000000 and timeout.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
BASE=$(realpath "$1"); CAND=$(realpath "$2"); OUT=$(realpath -m "$3")
for p in "$BASE" "$CAND" "$OUT"; do
  case "$p" in $ROOT/*) ;; *) echo "$p must live under $ROOT" >&2; exit 2;; esac
done
mkdir -p "$OUT"
MANIFEST=/home/will/llvm-mos-65816-pressure/dev/build-determinism-demo-set.txt
{
  for f in "$ROOT"/examples/snes/corpus/*.c; do echo "corpus/$(basename "$f")"; done
  grep -v '^#' "$MANIFEST" | grep -v '^$' | sed 's#$#.c#'
} > "$OUT/sources.txt"
cd "$ROOT"
dev/container.sh -- sh -c '
set -u
ulimit -c 0; ulimit -v 2000000
B=$1; C=$2; O=$3
T=/work/build/llvm-mos-install/bin
CFG=/work/build/install/bin/mos-snes.cfg
SIZE=$T/llvm-size
: > "$O/results.tsv"
while read -r rel; do
  src=/work/examples/snes/$rel
  stem=$(echo "$rel" | tr / _)
  for m in default a16 a16xy16; do
    case $m in
      default) F="";;
      a16) F="-Xclang -target-feature -Xclang +mos-a16";;
      a16xy16) F="-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16";;
    esac
    mkdir -p "$O/ir" "$O/obj"
    ir=$O/ir/$stem.$m.ll
    if [ ! -f "$src" ]; then printf "%s\t%s\tno-source\t-\t-\t-\n" "$rel" $m >> "$O/results.tsv"; continue; fi
    if ! timeout 300 $T/clang --config $CFG -mcpu=mosw65816 $F -Os -fno-lto \
         -I/work/examples/65816 -I/work/examples/snes -I/work/build -I/work/build/seamdemo-gen \
         -S -emit-llvm "$src" -o "$ir" 2>/dev/null; then
      printf "%s\t%s\tskip-frontend\t-\t-\t-\n" "$rel" $m >> "$O/results.tsv"; continue
    fi
    timeout 300 "$B" -O2 -filetype=obj "$ir" -o "$O/obj/$stem.$m.base.o" 2>/dev/null; rb=$?
    timeout 300 "$C" -O2 -filetype=obj "$ir" -o "$O/obj/$stem.$m.cand.o" 2>/dev/null; rc=$?
    sz() { $SIZE -A "$1" | awk "/^\\.text|^\\.data|^\\.rodata/ {s+=\$2} END {print s+0}"; }
    if [ $rb -ne 0 ] || [ $rc -ne 0 ]; then
      printf "%s\t%s\tllc-fail(base=%s,cand=%s)\t-\t-\t-\n" "$rel" $m $rb $rc >> "$O/results.tsv"; continue
    fi
    same=no; cmp -s "$O/obj/$stem.$m.base.o" "$O/obj/$stem.$m.cand.o" && same=yes
    printf "%s\t%s\tok\t%s\t%s\t%s\n" "$rel" $m "$(sz "$O/obj/$stem.$m.base.o")" "$(sz "$O/obj/$stem.$m.cand.o")" $same >> "$O/results.tsv"
  done
done < "$O/sources.txt"
' sh "/work/${BASE#$ROOT/}" "/work/${CAND#$ROOT/}" "/work/${OUT#$ROOT/}"
python3 - "$OUT/results.tsv" > "$OUT/summary.txt" <<'EOF'
import sys, collections
rows = [l.rstrip('\n').split('\t') for l in open(sys.argv[1])]
for m in ('default', 'a16', 'a16xy16'):
    r = [x for x in rows if x[1] == m]
    st = collections.Counter(x[2] if x[2] != 'ok' else ('identical' if x[5] == 'yes' else 'changed') for x in r)
    ok = [x for x in r if x[2] == 'ok']
    b = sum(int(x[3]) for x in ok); c = sum(int(x[4]) for x in ok)
    larger = sum(1 for x in ok if int(x[4]) > int(x[3])); smaller = sum(1 for x in ok if int(x[4]) < int(x[3]))
    print(f'{m}: {dict(sorted(st.items()))}; bytes {b} -> {c} ({c-b:+d}), larger {larger}, smaller {smaller}')
EOF
cat "$OUT/summary.txt"
