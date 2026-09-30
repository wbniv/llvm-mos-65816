#!/usr/bin/env bash
# Show which codegen level the -O3 gate sees in real builds with the installed
# downstream toolchain: clang -O3 without LTO, and mos-clang -flto links at
# -O3 and -Os. Each build's code is compared with llc -O3 and llc -O2 run on
# the same IR (the clang -O3 IR, or the link's own precodegen bitcode from
# --save-temps), so the level that built it is identified by its output.
#
# usage: gate-real-builds.sh OUTDIR [SOURCE]
#   OUTDIR  under /home/will/llvm-mos-65816 (receives the builds and report.txt)
#   SOURCE  C file under /home/will/llvm-mos-65816 (default
#           examples/snes/corpus/nmitally_sim.c, whose -O3 code differs
#           with and without the appended sets on the fixed set)
# Mode: -mcpu=mosw65816 +mos-a16, mos-snes.cfg. Every compile and link runs
# under ulimit -c 0, ulimit -v 2000000 and timeout.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
OUT=$(realpath -m "$1"); SRC=$(realpath "${2:-$ROOT/examples/snes/corpus/nmitally_sim.c}")
for p in "$OUT" "$SRC"; do case "$p" in $ROOT/*) ;; *) echo "$p must live under $ROOT" >&2; exit 2;; esac; done
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$ROOT"
dev/container.sh -- sh -c '
set -eu
ulimit -c 0; ulimit -v 2000000
O=$1; S=$2
T=/work/build/llvm-mos-install/bin; LLC=/work/build/llvm-mos/bin/llc
CFG=/work/build/install/bin/mos-snes.cfg
F="-mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -I/work/examples/65816 -I/work/examples/snes -I/work/build"
# The codegen options the MOS driver adds (-mllvm on cc1; -mllvm on ld.lld
# for LTO, plus -zp-avail and the -plugin-opt section flags).
CG="-mcpu=mosw65816 -force-precise-rotation-cost -jump-inst-cost=6 -force-loop-cold-block -phi-node-folding-threshold=0 -speculate-blocks=0 -align-large-globals=false -lsr-complexity-limit=10000000 -function-sections -data-sections"
dis() { $T/llvm-objdump -d --mcpu=mosw65816 --no-show-raw-insn "$1" | tail -n +3 | sha256sum | cut -c1-16; }
cd "$O"
echo "source: $S"
echo "clang-23 $(sha256sum $T/clang-23 | cut -c1-16)  llc $(sha256sum $LLC | cut -c1-16)  ld.lld $(sha256sum $T/lld | cut -c1-16)"
echo "== clang -O3, no LTO"
timeout 300 $T/mos-clang --config $CFG $F -O3 -fno-lto -c "$S" -o clang-O3.o
timeout 300 $T/mos-clang --config $CFG $F -O3 -fno-lto -S -emit-llvm "$S" -o clang-O3.ll
timeout 300 $LLC -O3 $CG -filetype=obj clang-O3.ll -o llc-O3.o
timeout 300 $LLC -O2 $CG -filetype=obj clang-O3.ll -o llc-O2.o
echo "clang -O3 object code $(dis clang-O3.o)"
echo "llc -O3 on its IR     $(dis llc-O3.o)"
echo "llc -O2 on its IR     $(dis llc-O2.o)"
for L in O3 Os; do
  echo "== mos-clang -flto link at -$L (--save-temps)"
  mkdir -p lto-$L; cd lto-$L
  timeout 600 $T/mos-clang --config $CFG $F -$L -flto "$S" -o rom.sfc -Wl,--save-temps -v 2>link.log || { echo "link failed"; tail -3 link.log; exit 1; }
  grep -o "plugin-opt=O[0-9s]*\|-mllvm -[a-z-]*=*[0-9a-z]*" link.log | sort -u | tr "\n" " "; echo
  pre=$(ls *.precodegen.bc | head -1); lto=$(ls *.lto.o | head -1)
  echo "precodegen: $pre  lto object: $lto"
  timeout 600 $LLC -O3 $CG -zp-avail=224 -filetype=obj "$pre" -o llc-O3.o
  timeout 600 $LLC -O2 $CG -zp-avail=224 -filetype=obj "$pre" -o llc-O2.o
  echo "LTO object code        $(dis "$lto")"
  echo "llc -O3 on precodegen  $(dis llc-O3.o)"
  echo "llc -O2 on precodegen  $(dis llc-O2.o)"
  cd ..
done
' sh "/work/${OUT#$ROOT/}" "/work/${SRC#$ROOT/}" | tee "$OUT/report.txt"
