#!/usr/bin/env bash
# dev/a16spill.sh — #321 regression test for Tier-1 fuzzer finding F3 (FIXED 2026-06-16):
# the `SelectImm $a16` crash when a 16-bit-accumulator (Ac16) value is spilled across a
# call. Delta-reduced from fuzz seed 1; see examples/65816/a16spill.c and
# docs/plans/2026-06-16-321-fix-cmp-value-selectimm.md.
#
# This is a COMPILE-TIME gate (the bug is invalid MIR / a backend segfault, not a wrong
# value — the differential value side is covered by the de-XFAIL'd fuzzer, dev/run.sh
# fuzz 50 1). It asserts three things, no emulator required:
#   1. +mos-a16 -verify-machineinstrs compiles CLEAN (was: 2 "is not a Flag register").
#   2. the body actually exercises the Ac16 spill (STAbs16/LDAbs16 $a16, %stack.N) — so a
#      future codegen change that stops spilling the accumulator here can't silently turn
#      this into a no-op guard.
#   3. the default (non-+mos-a16) build stays clean.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16spill. Prereq: from-source toolchain.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16spill   # F3 regression: Ac16 spill across a call compiles clean (no SelectImm \$a16)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16spill.c"
OBJ="$BUILD/a16spill.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs must compile CLEAN (was 2 machine-code errors: SelectImm \$a16)"
if vlog="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>&1)"; then
  echo "  PASS: clean (exit 0)"
else
  echo "  FAIL: backend rejected the build:"; printf '%s\n' "$vlog" | grep -iE "Flag register|SelectImm|Bad machine|fatal" | head -4
  rc=1
fi

echo "==> 2) the body must still SPILL the 16-bit accumulator across the call (STAbs16/LDAbs16 \$a16, %stack)"
mir="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -print-after=virtregrewriter -c -o /dev/null "$SRC" 2>&1 || true)"
nspill=$(printf '%s\n' "$mir" | grep -ciE '(STAbs16|LDAbs16).*(stack|static)' || true)
if [ "$nspill" -ge 2 ]; then
  echo "  PASS: $nspill Ac16 spill/reload op(s) to a stack slot — the F3 path is exercised"
else
  echo "  FAIL: expected an Ac16 spill (STAbs16/LDAbs16 \$a16, %stack); found $nspill — test no longer guards F3"
  rc=1
fi

echo "==> 3) default (non-+mos-a16) build stays clean"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>/dev/null; then
  echo "  PASS: default clean"
else
  echo "  FAIL: default build broke"; rc=1
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — Ac16 spill across a call compiles clean (no SelectImm \$a16); the F3 regression is guarded" \
             || echo "RESULT: FAIL"
exit $rc
