#!/usr/bin/env bash
# Replay the B1-B4 defect records' own commands on the split series.
#
# usage: carry-record-replay.sh REPO_WORKTREE
#   REPO_WORKTREE  checkout of llvm-mos-65816 holding docs/defects (logs are
#                  written to its docs/defects/evidence/2026-10-01-split-carry/)
# Each record's baseline or candidate runner command runs unchanged except that
# the llc path names a split-series binary: the unrepaired commit's (previous
# split, build/split-320-321/llc/p-320-NN, or the monolithic far-word candidate
# build/far-word-rebase/candidate/llc) and the carried commit's (llc/c-*).
# Runs in REPO_WORKTREE's dev container (REPO_WORKTREE is /work), with the split and
# far-word build directories mounted at their usual /work/build paths.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
WT=$(realpath "$1")
MAIN=/home/will/llvm-mos-65816
EVD=docs/defects/evidence/2026-10-01-split-carry
mkdir -p "$WT/$EVD"
cd "$WT"
"$WT/dev/container.sh" -v "$MAIN/build/split-320-321":/work/build/split-320-321 \
  -v "$MAIN/build/far-word-rebase":/work/build/far-word-rebase -- bash -c '
set -uo pipefail
ulimit -c 0; ulimit -v 2000000
cd /work
EVD=$1; L=build/split-320-321/llc; FWOLD=build/far-word-rebase/candidate/llc
mkdir -p build/split-320-321/carry-records
rec() { # log-name llc-path command-with-@LLC@
  local log=$EVD/$1.log cmd=${3//@LLC@/$2}
  { echo "\$ $cmd"; echo "# llc sha256 $(sha256sum "$2" | cut -d" " -f1)"; timeout 300 bash -c "$cmd" 2>&1; echo "exit_code=$?"; } > "$log"
  echo "$1: $(tail -1 "$log")"
}
B1="@LLC@ -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O2 -verify-machineinstrs docs/defects/evidence/2026-09-30-far-pointer-arg-exhaustion/abi4.ll -o /dev/null"
rec b1-unrepaired-320-02 $L/p-320-02 "$B1"
rec b1-carried-320-02 $L/c-320-02 "$B1"
rec b1-carried-fw-14 $L/c-fw-14 "$B1"
B2="set -euo pipefail; out=\$(@LLC@ -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O2 -verify-machineinstrs docs/defects/evidence/2026-09-30-far-memop-length-truncation/farmemlen.ll -o - | grep -v -E \"^[[:space:]]*[.;]\"); printf \"%s\n\" \"\$out\"; bad=0; if ! printf \"%s\n\" \"\$out\" | grep -A8 \"^big_const:\" | grep -q -E \"(jmp|jsr)[[:space:]]+__memset_far32\$\"; then echo \"FAIL: 70000-byte far memset does not call __memset_far32\"; bad=1; fi; if ! printf \"%s\n\" \"\$out\" | grep -A2 \"^big_var:\" | grep -q -E \"(jmp|jsr)[[:space:]]+__memcpy_far32\$\"; then echo \"FAIL: unbounded i32 far memcpy does not call __memcpy_far32\"; bad=1; fi; [ \$bad = 0 ] && echo \"PASS: lengths above 0xFFFF reach the 32-bit-length far runtime\"; exit \$bad"
rec b2-unrepaired-320-03 $L/p-320-03 "$B2"
rec b2-carried-320-03 $L/c-320-03 "$B2"
rec b2-carried-fw-14 $L/c-fw-14 "$B2"
B3="set -euo pipefail; o=build/split-320-321/carry-records/rt-6502.o; e=build/split-320-321/carry-records/rt-6502.err; rm -f \"\$o\"; if @LLC@ -mtriple=mos -mcpu=mos6502 -O2 -verify-machineinstrs -filetype=obj docs/defects/evidence/2026-09-30-far-access-non-65816/rt.ll -o \"\$o\" 2>\"\$e\"; then echo \"FAIL: mos6502 far byte load compiled without a diagnostic\"; exit 1; fi; cat \"\$e\"; [ ! -e \"\$o\" ] || { echo \"FAIL: an object was emitted\"; exit 1; }; grep -q \"far (address space 2) memory access requires 65816 long addressing\" \"\$e\" && echo \"PASS: diagnosed; no object emitted\""
rec b3-unrepaired-320-02 $L/p-320-02 "$B3"
rec b3-carried-320-02 $L/c-320-02 "$B3"
rec b3-carried-fw-14 $L/c-fw-14 "$B3"
B4="@LLC@ -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O2 -verify-machineinstrs docs/defects/evidence/2026-09-30-far-index-fold-dangling-dbg/dbgbyte.ll -o /dev/null"
rec b4-unrepaired-320-04 $L/p-320-04 "$B4"
rec b4-carried-320-04 $L/c-320-04 "$B4"
rec b4-carried-fw-14 $L/c-fw-14 "$B4"
B4W="@LLC@ -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O2 -verify-machineinstrs docs/defects/evidence/2026-09-30-far-index-fold-dangling-dbg/dbg.ll -o /dev/null"
rec b4-word-unrepaired-fw-old $FWOLD "$B4W"
rec b4-word-carried-fw-14 $L/c-fw-14 "$B4W"
' _ "$EVD" </dev/null
