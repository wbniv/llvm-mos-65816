#!/usr/bin/env bash
# Capture evidence for the two dangling-DBG_VALUE records of the second round.
#
# usage: r2-record-capture.sh REPO_WORKTREE PHASE
#   REPO_WORKTREE  checkout of llvm-mos-65816 holding docs/defects
#   PHASE          baseline (reviewed split, downstream and upstream base) or
#                  candidate (the second-round split commits)
# Inputs are the second independent review's probes, copied into each record's
# evidence directory. Every llc runs in REPO_WORKTREE's dev container with
# ulimit -c 0, ulimit -v 2000000 and a timeout; each log records the command,
# the llc sha256 and the exit code captured immediately after the command.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
WT=$(realpath "$1"); PHASE=$2
MAIN=/home/will/llvm-mos-65816
FAR=docs/defects/evidence/2026-10-01-far-fold-dangling-dbg-sites
NEAR=docs/defects/evidence/2026-10-01-legalizer-fold-dangling-dbg-upstream
mkdir -p "$WT/$FAR" "$WT/$NEAR"
P=$MAIN/build/split-320-321/probe-review2
for f in field store1 gfield gidx; do [ -e "$WT/$FAR/$f.ll" ] || cp "$P/$f.ll" "$WT/$FAR/"; done
for f in nidx ngfield ngidx nearfield; do [ -e "$WT/$NEAR/$f.ll" ] || cp "$P/$f.ll" "$WT/$NEAR/"; done
cd "$WT"
"$WT/dev/container.sh" -v "$MAIN/build/split-320-321":/work/build/split-320-321 \
  -v "$MAIN/build/far-review-defects":/work/build/far-review-defects -- bash -c '
set -uo pipefail
ulimit -c 0; ulimit -v 2000000
cd /work
FAR=$1 NEAR=$2 PHASE=$3; L=build/split-320-321/llc; DOWN=build/far-review-defects/candidate/llc
run() { # log llc cpu attrs opt input
  local log=$1 llc=$2 cpu=$3 attrs=$4 opt=$5 in=$6
  local cmd="$llc -mtriple=mos -mcpu=$cpu${attrs:+ -mattr=$attrs} -$opt -verify-machineinstrs $in -o /dev/null"
  { echo "\$ $cmd"; echo "# llc sha256 $(sha256sum "$llc" | cut -d" " -f1)"; } > "$log"
  timeout 120 $cmd >> "$log" 2>&1
  local rc=$?
  echo "exit_code=$rc" >> "$log"
  echo "$log: exit_code=$rc"
}
if [ "$PHASE" = baseline ]; then
  run $FAR/baseline.log $L/c-320-04 mosw65816 +mos-a16 O2 $FAR/field.ll
  run $FAR/field-O0.log $L/c-320-04 mosw65816 +mos-a16 O0 $FAR/field.ll
  run $FAR/field-plain-O2.log $L/c-320-04 mosw65816 "" O2 $FAR/field.ll
  run $FAR/store1.log $L/c-320-04 mosw65816 +mos-a16 O2 $FAR/store1.ll
  run $FAR/gfield-O0.log $L/c-320-04 mosw65816 +mos-a16 O0 $FAR/gfield.ll
  run $FAR/gidx-fw14.log $L/c-fw-14 mosw65816 +mos-a16 O2 $FAR/gidx.ll
  run $FAR/downstream-field.log $DOWN mosw65816 +mos-a16 O2 $FAR/field.ll
  run $FAR/downstream-gidx.log $DOWN mosw65816 +mos-a16 O2 $FAR/gidx.ll
  run $NEAR/baseline.log $L/p-321-00 mos6502 "" O2 $NEAR/nidx.ll
  run $NEAR/nidx-O0.log $L/p-321-00 mos6502 "" O0 $NEAR/nidx.ll
  run $NEAR/ngfield-O0.log $L/p-321-00 mos6502 "" O0 $NEAR/ngfield.ll
  run $NEAR/ngidx-O2.log $L/p-321-00 mos6502 "" O2 $NEAR/ngidx.ll
  run $NEAR/nearfield-O2.log $L/p-321-00 mos6502 "" O2 $NEAR/nearfield.ll
  run $NEAR/nidx-w65816.log $L/p-321-00 mosw65816 "" O2 $NEAR/nidx.ll
else
  run $FAR/candidate.log $L/r2-320-4 mosw65816 +mos-a16 O2 $FAR/field.ll
  run $FAR/candidate-field-O0.log $L/r2-320-4 mosw65816 +mos-a16 O0 $FAR/field.ll
  run $FAR/candidate-store1.log $L/r2-320-4 mosw65816 +mos-a16 O2 $FAR/store1.ll
  run $FAR/candidate-gfield-O0.log $L/r2-320-2 mosw65816 +mos-a16 O0 $FAR/gfield.ll
  run $FAR/candidate-gidx-fw14.log $L/r2-fw-14 mosw65816 +mos-a16 O2 $FAR/gidx.ll
  run $NEAR/r2-320-4-nidx.log $L/r2-320-4 mos6502 "" O2 $NEAR/nidx.ll
fi
' _ "$FAR" "$NEAR" "$PHASE" </dev/null
