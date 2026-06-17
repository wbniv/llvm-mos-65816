#!/usr/bin/env bash
# dev/a16spillir.sh — #321 HERMETIC crash-regression for the soft-stack Ac16 spill (F3).
#
# Companion to dev/a16spillr.sh (the runtime differential): this drives `llc` on a FROZEN
# LLVM-IR fixture (examples/65816/a16spillir.ll, the emitted IR of a16spillr.c), so the guard
# survives C front-end / optimizer drift — only the backend codegen path under test can change
# it. Pure compile-time gate, no emulator. Asserts:
#   1. llc -verify-machineinstrs compiles CLEAN (was: invalid MIR / "SelectImm $a16" segfault).
#   2. the body still exercises the soft-stack Ac16 spill (STStk/LDStk $a16) — so a future
#      codegen change that stops spilling the accumulator here can't silently no-op the guard.
#
# Uses the build-tree `llc` (pure codegen; not shipped in the install dir). Runs INSIDE the dev
# container; drive: dev/run.sh a16spillir. Prereq: from-source toolchain (dev/run.sh toolchain).
# Plan: docs/plans/2026-06-17-p2-hermetic-ll-crash-regression-for-the-soft-stack.md
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16spillir   # hermetic .ll gate: soft-stack Ac16 spill compiles clean + spill present"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
LLC="${MOS_LLC:-$BUILD/llvm-mos/bin/llc}"   # llc lives in the build tree, not the install dir
LL="$ROOT/examples/65816/a16spillir.ll"
LLCFLAGS=(-mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16)

[ -x "$LLC" ] || { echo "FATAL: no llc at $LLC (run: dev/run.sh toolchain — llc is built into build/llvm-mos/bin)"; exit 1; }
[ -f "$LL" ]  || { echo "FATAL: fixture missing: $LL"; exit 1; }

rc=0

echo "==> 1) llc -verify-machineinstrs on the frozen .ll must compile CLEAN (was: SelectImm \$a16)"
if vlog="$("$LLC" "${LLCFLAGS[@]}" -verify-machineinstrs -o /dev/null "$LL" 2>&1)"; then
  echo "  PASS: clean (exit 0)"
else
  echo "  FAIL: llc rejected the IR:"; printf '%s\n' "$vlog" | grep -iE "Flag register|SelectImm|Bad machine|Scavenger|fatal|error" | head -4
  rc=1
fi

echo "==> 2) the body must still SPILL the 16-bit accumulator on the soft stack (STStk/LDStk \$a16)"
mir="$("$LLC" "${LLCFLAGS[@]}" -print-after=virtregrewriter -o /dev/null "$LL" 2>&1 || true)"
nspill=$(printf '%s\n' "$mir" | grep -ciE '(STStk|LDStk).*a16' || true)
if [ "$nspill" -ge 1 ]; then
  echo "  PASS: $nspill soft-stack Ac16 spill op(s) (STStk/LDStk \$a16) — the F3 path is exercised"
else
  echo "  FAIL: no soft-stack Ac16 spill found ($nspill) — fixture no longer guards the soft-stack F3 bug"
  rc=1
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — hermetic .ll: soft-stack Ac16 spill compiles clean and the spill path is exercised" \
             || echo "RESULT: FAIL"
exit $rc
