#!/usr/bin/env bash
# Emit frontend IR for the held-out gcc c-torture/execute in-scope tests, per
# mode and level, for llc-sizes.sh and the cycle probe.
#
# usage: gen-torture-ir.sh OUTDIR [LEVELS]
#   OUTDIR  under /home/will/llvm-mos-65816; receives LEVEL/TEST.MODE.ll and
#           status.tsv (test, level, mode, ok|skip-frontend)
#   LEVELS  default "Os Oz O2 O3"
# Tests: examples/65816/torture/inscope.tsv (vendor/c-torture/execute). The
# frontend is the main checkout's installed clang with mos-snes.cfg,
# -mcpu=mosw65816 and the torture runner's renames (-Dmain=torture_test_main
# -Dabort=__torture_abort -Dexit=__torture_exit), -fno-lto, as tools/torture_run.py
# builds them. Modes: default, a16 (+mos-a16), a16xy16 (+mos-a16,+mos-xy16).
# Three clang at a time, each under ulimit -c 0, ulimit -v 2000000, timeout 120.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
OUT=$(realpath -m "$1"); LEVELS=${2:-Os Oz O2 O3}
case "$OUT" in $ROOT/*) ;; *) echo "$OUT must live under $ROOT" >&2; exit 2;; esac
mkdir -p "$OUT"
cd "$ROOT"
dev/container.sh -- bash -c '
set -u
O=$1; LEVELS=$2
T=/work/build/llvm-mos-install/bin; CFG=/work/build/install/bin/mos-snes.cfg
one() {
  t=$1; L=$2; m=$3
  case $m in
    default) F="";;
    a16) F="-Xclang -target-feature -Xclang +mos-a16";;
    a16xy16) F="-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16";;
  esac
  mkdir -p "$O/$L"
  if ( ulimit -c 0; ulimit -v 2000000; timeout 120 $T/clang --config $CFG -mcpu=mosw65816 $F -$L -fno-lto -w \
       -Dmain=torture_test_main -Dabort=__torture_abort -Dexit=__torture_exit \
       -S -emit-llvm /work/vendor/c-torture/execute/$t -o "$O/$L/$t.$m.ll" ) 2>/dev/null; then
    printf "%s\t%s\t%s\tok\n" $t $L $m
  else
    printf "%s\t%s\t%s\tskip-frontend\n" $t $L $m
  fi
}
export -f one; export O T CFG
grep -v "^#" /work/examples/65816/torture/inscope.tsv | awk "NF{print \$1}" | while read -r t; do
  for L in $LEVELS; do for m in default a16 a16xy16; do echo "$t $L $m"; done; done
done | xargs -P3 -L1 bash -c "one \$0 \$1 \$2" > "$O/status.tsv"
' bash "/work/${OUT#$ROOT/}" "$LEVELS"
awk -F'\t' '{print $2, $4}' "$OUT/status.tsv" | sort | uniq -c
