#!/usr/bin/env bash
# Emit frontend IR for the SNES corpus and demo sources at one clang level,
# once per mode, for llc-sizes.sh.
#
# usage: gen-ir.sh LEVEL SOURCES OUTDIR
#   LEVEL    Os, Oz, O2 or O3 (clang -LEVEL -fno-lto)
#   SOURCES  list of paths relative to examples/snes (the 277 of
#            build/pressure-sets/final/downstream/codegen/sources.txt)
#   OUTDIR   under /home/will/llvm-mos-65816; receives STEM.MODE.ll and
#            status.tsv (source, mode, ok|skip-frontend|no-source)
# The frontend is the main checkout's installed clang with mos-snes.cfg and
# -mcpu=mosw65816, run in the dev container exactly as
# docs/defects/evidence/2026-09-30-native-width-pressure-sets/final/tools/downstream-codegen.sh
# does. Modes: default, a16 (+mos-a16), a16xy16 (+mos-a16,+mos-xy16).
# Each clang runs under ulimit -c 0, ulimit -v 2000000 and timeout 300.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
LEVEL=$1; SRCS=$(realpath "$2"); OUT=$(realpath -m "$3")
for p in "$SRCS" "$OUT"; do
  case "$p" in $ROOT/*) ;; *) echo "$p must live under $ROOT" >&2; exit 2;; esac
done
case "$LEVEL" in Os|Oz|O2|O3) ;; *) echo "bad LEVEL $LEVEL" >&2; exit 2;; esac
mkdir -p "$OUT"
cd "$ROOT"
dev/container.sh -- sh -c '
set -u
ulimit -c 0; ulimit -v 2000000
L=$1; S=$2; O=$3
T=/work/build/llvm-mos-install/bin
CFG=/work/build/install/bin/mos-snes.cfg
: > "$O/status.tsv"
one() {
  rel=$1; m=$2
  src=/work/examples/snes/$rel; stem=$(echo "$rel" | tr / _)
  case $m in
    default) F="";;
    a16) F="-Xclang -target-feature -Xclang +mos-a16";;
    a16xy16) F="-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16";;
  esac
  if [ ! -f "$src" ]; then printf "%s\t%s\tno-source\n" "$rel" $m; return; fi
  if timeout 300 $T/clang --config $CFG -mcpu=mosw65816 $F -$L -fno-lto \
       -I/work/examples/65816 -I/work/examples/snes -I/work/build -I/work/build/seamdemo-gen \
       -S -emit-llvm "$src" -o "$O/$stem.$m.ll" 2>/dev/null; then
    printf "%s\t%s\tok\n" "$rel" $m
  else
    printf "%s\t%s\tskip-frontend\n" "$rel" $m
  fi
}
while read -r rel; do
  for m in default a16 a16xy16; do one "$rel" $m >> "$O/status.tsv" & done
  wait
done < "$S"
' sh "$LEVEL" "/work/${SRCS#$ROOT/}" "/work/${OUT#$ROOT/}"
awk -F'\t' '{print $3}' "$OUT/status.tsv" | sort | uniq -c
