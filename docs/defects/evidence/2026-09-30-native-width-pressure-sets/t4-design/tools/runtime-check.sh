#!/usr/bin/env bash
# Runtime sanity: compile a fixed-set corpus IR with a given llc, link it with
# the installed SDK (build/install mos-snes.cfg, installed mos-clang as the
# linker driver), and read corpus_result on bsnes-jg (build/jgxcheck).
#
# usage: runtime-check.sh LLC OUTDIR NAME=EXPECTED ... 
#   LLC       llc under /home/will/llvm-mos-65816
#   OUTDIR    receives <name>.<mode>.{o,sfc,map} and results.tsv
#   NAME      corpus sim name (examples_snes_corpus_<NAME>.c.default.ll)
#   EXPECTED  host value from examples/snes/corpus/expected.tsv
# Modes: default (mosw65816), a16, a16xy16. MAME legs are not run (they need
# the SPC700 IPL secret); bsnes-jg is deterministic and needs no BIOS.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
LLC=/work/$(realpath --relative-to=$ROOT "$1"); OUT=$(realpath -m "$2"); shift 2
mkdir -p "$OUT"; C_OUT=/work/$(realpath --relative-to=$ROOT "$OUT")
cd "$ROOT"
dev/container.sh -- sh -c '
set -u; ulimit -c 0
LLC=$1; OUT=$2; shift 2
IN=/work/build/pressure-sets/default-inputs/corpus
T=/work/build/llvm-mos-install/bin; CFG=/work/build/install/bin/mos-snes.cfg
: > "$OUT/results.tsv"
for spec in "$@"; do
  n=${spec%%=*}; want=${spec#*=}
  for m in default a16 a16xy16; do
    case $m in default) attr=; cf=;; a16) attr=-mattr=+mos-a16; cf="-Xclang -target-feature -Xclang +mos-a16";;
      a16xy16) attr=-mattr=+mos-a16,+mos-xy16; cf="-Xclang -target-feature -Xclang +mos-xy16";; esac
    b=$OUT/$n.$m; st=ok; got=-
    if ! "$LLC" -mtriple=mos -mcpu=mosw65816 $attr -O2 -verify-machineinstrs -filetype=obj "$IN/examples_snes_corpus_$n.c.default.ll" -o "$b.o" 2>"$b.err"; then st=llc-fail
    elif ! "$T/mos-clang" --config "$CFG" -mcpu=mosw65816 $cf -Os "$b.o" -Wl,-Map="$b.map" -o "$b.sfc" 2>>"$b.err"; then st=link-fail
    elif ! python3 /work/tools/snes-checksum.py "$b.sfc" >>"$b.err" 2>&1; then st=checksum-fail
    else
      line=$(awk "\$NF==\"corpus_result\" && NF>=3 {print \$1, \$3; exit}" "$b.map")
      vma=${line% *}; len=${line#* }
      r=$(/work/build/jgxcheck "$b.sfc" /work/vendor/bsnes-jg/Database 0x$vma $((0x$len)) $want 1000 2>&1 | grep -m1 "^SMOKE:")
      got=$(printf "%s" "$r" | grep -o "got=0x[0-9A-Fa-f]*" | cut -d= -f2)
      case "$r" in *PASS*) st=PASS;; *) st="FAIL";; esac
    fi
    printf "%s\t%s\t%s\t%s\t%s\n" "$n" "$m" "$want" "${got:--}" "$st" | tee -a "$OUT/results.tsv"
  done
done
' _ "$LLC" "$C_OUT" "$@"
