#!/usr/bin/env bash
# dev/a16unmerge.sh — #321 HERMETIC crash-regression for the +mos-a16 s32 legalizer gap.
# Compiles a FROZEN LLVM-IR fixture (examples/65816/a16unmerge.ll, the -Os IR of the Csmith
# fuzzer's seed 11) so the guard survives C front-end / optimizer drift — only the backend
# codegen path under test can change it. Pure compile-time gate, no emulator (runtime
# correctness of s32-under-a16 is covered by the Csmith differential sweep). Asserts:
#   1. the frozen IR compiles CLEAN under +mos-a16 (was: "unable to legalize instruction:
#      ... = G_UNMERGE_VALUES %_(s32)" — the s32->2x s16 split had no legal form).
#   2. the fixture still carries the trigger (an i32 op truncated to i16), so a future edit
#      that guts the fixture can't silently no-op the guard.
#
# Uses the rebuilt `mos-clang` (NOT `llc`): `dev/run.sh toolchain` builds only the
# `distribution` target, so build/llvm-mos/bin/llc is NOT rebuilt and goes stale — an
# llc-based gate would silently test a 2-day-old binary. `-Xclang -disable-llvm-passes`
# feeds the frozen IR straight to the backend (no mid-end re-optimization), so it's
# llc-equivalent: the pinned IR reaches the legalizer unchanged. Runs INSIDE the dev
# container; drive: dev/run.sh a16unmerge. Prereq: from-source toolchain (dev/run.sh toolchain).
# Plan: docs/plans/2026-06-19-321-a16-unmerge-s32-legalizer.md
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16unmerge   # hermetic .ll gate: +mos-a16 s32 (long) unmerge compiles clean"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
LL="$ROOT/examples/65816/a16unmerge.ll"
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$LL" ]            || { echo "FATAL: fixture missing: $LL"; exit 1; }

rc=0

echo "==> 1) the frozen .ll must compile CLEAN under +mos-a16 (was: G_UNMERGE_VALUES s32)"
if vlog="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -Xclang -disable-llvm-passes \
            -mllvm -verify-machineinstrs -c -o /dev/null "$LL" 2>&1)"; then
  echo "  PASS: clean (exit 0)"
else
  echo "  FAIL: backend rejected the IR:"; printf '%s\n' "$vlog" | grep -iE "unable to legalize|G_UNMERGE|G_MERGE|Bad machine|fatal|error" | head -4
  rc=1
fi

echo "==> 2) the fixture must still carry the trigger (an i32 op truncated to i16)"
if grep -qE 'trunc i32 .* to i16' "$LL" && grep -qE '(xor|add|sub|and|or) i32' "$LL"; then
  echo "  PASS: fixture still truncates a materialized i32 -> i16 (the s32->2x s16 split path)"
else
  echo "  FAIL: fixture no longer contains the trunc-of-i32 trigger — guard would be a no-op"
  rc=1
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — hermetic .ll: +mos-a16 s32 unmerge/trunc compiles clean" \
             || echo "RESULT: FAIL"
exit $rc
