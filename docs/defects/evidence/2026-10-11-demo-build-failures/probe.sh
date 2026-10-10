#!/usr/bin/env bash
# Replay the ascast/ascast_sim and lzss-gallery build failures against one toolchain.
#
# usage: probe.sh TOOLCHAIN_DIR LABEL [SDK_DIR]
#   TOOLCHAIN_DIR  an llvm-mos install (bin/mos-clang, bin/llc)
#   LABEL          output directory name under runs/
#   SDK_DIR        SDK install for the link-shaped runs (default: build/install)
#
# Every run writes runs/LABEL/<name>.log: the command, the toolchain hashes, the
# compiler output and a final `rc=N` line. runs/LABEL/summary.tsv lists name and rc.
# Run from the repository root. Probes run with core dumps off and a 2 GB cap.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
TC=$(cd "$1" && pwd); LABEL=$2
ROOT=$(pwd); SDK=${3:-$ROOT/build/install}
E=docs/defects/evidence/2026-10-11-demo-build-failures
OUT=$E/runs/$LABEL; mkdir -p "$OUT"
SCRATCH=$ROOT/build/demo-build-failures-20261010/probe-$LABEL; mkdir -p "$SCRATCH"
ulimit -c 0; ulimit -v 2000000
CLANG=$TC/bin/mos-clang; LLC=$TC/bin/llc
REAL=$(readlink -f "$CLANG")
IDENT="toolchain=$TC clang=$(sha256sum "$REAL" | cut -d' ' -f1) ($(basename "$REAL")) llc=$(sha256sum "$LLC" | cut -d' ' -f1) lld=$(sha256sum "$TC/bin/lld" | cut -d' ' -f1)"
A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-xy16)
: >"$OUT/summary.tsv"
run() { # NAME CMD...
  local name=$1; shift
  { echo "# $IDENT"; echo "# cwd=$ROOT"; echo "\$ $*"; } >"$OUT/$name.log"
  local rc=0
  "$@" >>"$OUT/$name.log" 2>&1 || rc=$?
  echo "rc=$rc" >>"$OUT/$name.log"
  printf '%s\t%s\n' "$name" "$rc" >>"$OUT/summary.tsv"
}
G=$E/gallery; A=$E/ascast
gunzip -c "$G/lzss-gallery.Os.i.gz" >"$SCRATCH/lzss-gallery.Os.i"

# lzss-gallery record_result: reduced C, every level and mode (object only, no LTO).
for O in O0 O1 O2 O3 Os Oz; do
  run "gallery-reduced-default-$O" "$CLANG" --target=mos -mcpu=mosw65816 -"$O" -c -o /dev/null "$G/record-result-reduced.c"
  run "gallery-reduced-a16-$O" "$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -"$O" -c -o /dev/null "$G/record-result-reduced.c"
  run "gallery-reduced-xy16-$O" "$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" "${XY16[@]}" -"$O" -c -o /dev/null "$G/record-result-reduced.c"
done
# Full program, preprocessed translation unit, object only at the battery level and the gate level.
run gallery-full-tu-a16-Os-nolto "$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -fno-lto -c -o /dev/null "$SCRATCH/lzss-gallery.Os.i"
run gallery-full-tu-a16-Oz-nolto "$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -Oz -fno-lto -c -o /dev/null "$SCRATCH/lzss-gallery.Os.i"
# Full program, link-shaped like dev/build.sh (-Os) and like dev/lzss-gallery.sh (-Oz, the published ROM).
run gallery-battery-link-Os "$CLANG" --config "$SDK/bin/mos-snes-gallery.cfg" -mcpu=mosw65816 "${A16[@]}" -I examples/snes -Os -o "$SCRATCH/gallery-Os.sfc" examples/snes/lzss-gallery.c
run gallery-gate-link-Oz "$CLANG" --config "$SDK/bin/mos-snes-gallery.cfg" -mcpu=mosw65816 "${A16[@]}" -DGALLERY_START=0 -Oz -o "$SCRATCH/gallery-Oz.sfc" examples/snes/lzss-gallery.c
# Reduced IR: the pass and the knobs that move it.
run gallery-ir-llc "$LLC" -O2 -o /dev/null "$G/record-result-reduced.ll"
run gallery-ir-llc-basic "$LLC" -O2 -regalloc=basic -o /dev/null "$G/record-result-reduced.ll"
run gallery-ir-llc-no-global-join "$LLC" -O2 -join-globalcopies=false -o /dev/null "$G/record-result-reduced.ll"
run gallery-ir-llc-no-misched "$LLC" -O2 -enable-misched=false -o /dev/null "$G/record-result-reduced.ll"
# Reduced MIR at the greedy allocator, and the return-register control.
run gallery-mir-greedy "$LLC" -O2 -run-pass=greedy -o /dev/null "$G/record-result-reduced.pre-greedy.mir"
run gallery-min-mir-greedy "$LLC" -O2 -run-pass=greedy -o - "$G/record-result-min.pre-greedy.mir"
run gallery-min-mir-basic "$LLC" -O2 -run-pass=regallocbasic -o /dev/null "$G/record-result-min.pre-greedy.mir"
run gallery-min-mir-greedy-return-in-y "$LLC" -O2 -run-pass=greedy -o /dev/null "$G/record-result-min-return-in-y.pre-greedy.mir"

# ascast / ascast_sim: default mode (what dev/build.sh does without a mos-a16-only marker) and +mos-a16.
for O in O0 O1 O2 O3 Os Oz; do
  run "ascast-sim-default-$O" "$CLANG" --target=mos -mcpu=mosw65816 -"$O" -c -o /dev/null "$A/ascast_sim.i"
  run "ascast-sim-a16-$O" "$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -"$O" -c -o /dev/null "$A/ascast_sim.i"
done
run ascast-sim-mos6502-Os "$CLANG" --target=mos -mcpu=mos6502 -Os -c -o /dev/null "$A/ascast_sim.i"
run ascast-demo-default-Os "$CLANG" --target=mos -mcpu=mosw65816 -Os -c -o /dev/null "$A/ascast.i"
run ascast-demo-a16-Os "$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o /dev/null "$A/ascast.i"
# Link-shaped like dev/build.sh today (no marker) and with the flags the marker would add.
run ascast-battery-link-Os "$CLANG" --config "$SDK/bin/mos-snes.cfg" -I examples/snes -Os -o "$SCRATCH/ascast.sfc" examples/snes/ascast.c
run ascast-sim-battery-link-Os "$CLANG" --config "$SDK/bin/mos-snes.cfg" -I examples/snes -Os -o "$SCRATCH/ascast_sim.sfc" examples/snes/corpus/ascast_sim.c
run ascast-marker-link-Os "$CLANG" --config "$SDK/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -I examples/snes -Os -o "$SCRATCH/ascast-a16.sfc" examples/snes/ascast.c
run ascast-sim-marker-link-Os "$CLANG" --config "$SDK/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -I examples/snes -Os -o "$SCRATCH/ascast_sim-a16.sfc" examples/snes/corpus/ascast_sim.c
# Pass and construct for the default-mode failure: the legalizer input of ac_to_far.
run ascast-sim-default-Os-before-legalizer "$CLANG" --target=mos -mcpu=mosw65816 -Os -c -o /dev/null -mllvm -print-before=legalizer -mllvm -filter-print-funcs=ac_to_far "$A/ascast_sim.i"
run ascast-sim-a16-Os-after-legalizer "$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o /dev/null -mllvm -print-after=legalizer -mllvm -filter-print-funcs=ac_to_far "$A/ascast_sim.i"

rm -rf "$SCRATCH"
cat "$OUT/summary.tsv"
