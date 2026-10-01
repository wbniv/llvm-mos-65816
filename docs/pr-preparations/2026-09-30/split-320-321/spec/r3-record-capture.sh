#!/usr/bin/env bash
# Capture evidence for the third-round records (N17 late-opt, N22 far folds).
#
# usage: r3-record-capture.sh REPO_WORKTREE
#   REPO_WORKTREE  checkout of llvm-mos-65816 holding docs/defects
# Runs each llc in REPO_WORKTREE's dev container with ulimit -c 0,
# ulimit -v 2000000 and a timeout; each log records the command, the llc
# sha256 and the exit code captured immediately after the command.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
WT=$(realpath "$1")
MAIN=/home/will/llvm-mos-65816
cd "$WT"
"$WT/dev/container.sh" -v "$MAIN/build/split-320-321":/work/build/split-320-321 -- bash -c '
set -uo pipefail
ulimit -c 0; ulimit -v 2000000
cd /work
L=build/split-320-321/llc
LO=docs/defects/evidence/2026-10-01-late-opt-nongpr-ldimm
FAR=docs/defects/evidence/2026-10-01-far-fold-dangling-dbg-sites
HUC=docs/defects/evidence/2026-10-01-huc-blockmove-frameindex
run() { # log command...
  local log=$1; shift
  local tool; for tool in "$@"; do case "$tool" in */llc/*) break;; esac; done
  { echo "\$ $*"; echo "# llc $tool sha256 $(sha256sum "$tool" | cut -d" " -f1)"; } > "$log"
  timeout 120 "$@" >> "$log" 2>&1
  local rc=$?
  echo "exit_code=$rc" >> "$log"
  echo "$log: exit_code=$rc"
}
run $LO/baseline.log $L/p-321-00 -mtriple=mos -mcpu=mosspc700 -run-pass=mos-late-opt -verify-machineinstrs $LO/late-opt-spc700.mir -o /dev/null
run $LO/candidate.log $L/r3-584-up -mtriple=mos -mcpu=mosspc700 -run-pass=mos-late-opt -verify-machineinstrs $LO/late-opt-spc700.mir -o /dev/null
run $LO/candidate-series.log $L/r3-584 -mtriple=mos -mcpu=mosspc700 -run-pass=mos-late-opt -verify-machineinstrs $LO/late-opt-spc700.mir -o /dev/null
run $LO/series-mc-top.log $L/r3-mc-2 -mtriple=mos -mcpu=mosspc700 -run-pass=mos-late-opt -verify-machineinstrs $LO/late-opt-spc700.mir -o /dev/null
run $LO/fcmp-base.log $L/p-321-00 -mtriple=mos -mcpu=mosspc700 -O2 $LO/fcmp.ll -o /dev/null
run $LO/fcmp-candidate.log $L/r3-584-up -mtriple=mos -mcpu=mosspc700 -O2 $LO/fcmp.ll -o /dev/null
run $FAR/r3-candidate.log $L/r3-320-4 -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O2 -verify-machineinstrs $FAR/field.ll -o /dev/null
run $FAR/r3-candidate-field-O0.log $L/r3-320-4 -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O0 -verify-machineinstrs $FAR/field.ll -o /dev/null
run $FAR/r3-candidate-store1.log $L/r3-320-4 -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O2 -verify-machineinstrs $FAR/store1.ll -o /dev/null
run $FAR/r3-candidate-gfield-O0.log $L/r3-320-2 -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O0 -verify-machineinstrs $FAR/gfield.ll -o /dev/null
run $FAR/r3-candidate-gidx-fw14.log $L/r3-fw-14 -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O2 -verify-machineinstrs $FAR/gidx.ll -o /dev/null
for l in p-321-00 r3-321-10; do run $HUC/$l.log python3 build/split-320-321/spec/run-test-with.py $L/$l $HUC/blockmove-stack.ll; done
for l in r3-321-11 r3-fw-14; do run $HUC/$l.log python3 build/split-320-321/spec/run-test-with.py $L/$l $HUC/blockmove-stack.ll; done
run $HUC/p-321-00.s.log $L/p-321-00 -mtriple=mos -mcpu=moshuc6280 -O2 $HUC/blockmove-stack.ll -o -
run $HUC/r3-321-11.s.log $L/r3-321-11 -mtriple=mos -mcpu=moshuc6280 -O2 $HUC/blockmove-stack.ll -o -
' _ </dev/null
