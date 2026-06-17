#!/usr/bin/env bash
# dev/xy16spill.sh — #321 xy16 static-stack spill gate: +mos-xy16 (implies +mos-a16) must
# not break the Ac16 static-stack spill path added in Layer 4 (MOSInstrInfo::loadStoreReg-
# StackSlot). The new Xc16/Yc16 branches sit above the existing Ac16 branch; this compile-
# time gate proves the Ac16 path still fires correctly when +mos-xy16 is set. No emulator
# needed — the bug class (invalid MIR / SelectImm $a16) is caught by -verify-machineinstrs.
#
# Parallel to dev/a16spill.sh; differs only in the feature flag (+mos-xy16 vs +mos-a16).
# Runs INSIDE the dev container; drive: dev/run.sh xy16spill.
set -euo pipefail

usage() { echo "Usage: dev/run.sh xy16spill   # xy16 static-stack Ac16 spill: -verify-machineinstrs clean under +mos-xy16"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/xy16spill.c"
OBJ="$BUILD/xy16spill.o"
XY16=(-Xclang -target-feature -Xclang +mos-xy16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }

rc=0

echo "==> 1) +mos-xy16 -verify-machineinstrs must compile CLEAN (Ac16 static-stack spill under +mos-xy16)"
if vlog="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>&1)"; then
  echo "  PASS: clean (exit 0)"
else
  echo "  FAIL: backend rejected the build:"; printf '%s\n' "$vlog" | grep -iE "Flag register|SelectImm|Bad machine|fatal" | head -4
  rc=1
fi

echo "==> 2) the body must still SPILL the 16-bit accumulator across the call (STAbs16/LDAbs16 \$a16, %stack)"
mir="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -print-after=virtregrewriter -c -o /dev/null "$SRC" 2>&1 || true)"
nspill=$(printf '%s\n' "$mir" | grep -ciE '(STAbs16|LDAbs16).*(stack|static)' || true)
if [ "$nspill" -ge 2 ]; then
  echo "  PASS: $nspill Ac16 static-stack spill/reload op(s) — the Layer 4 Ac16 path is exercised"
else
  echo "  FAIL: expected an Ac16 static-stack spill (STAbs16/LDAbs16 \$a16, %stack); found $nspill — test no longer guards the regression"
  rc=1
fi

echo "==> 3) default (non-+mos-xy16) build stays clean"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>/dev/null; then
  echo "  PASS: default clean"
else
  echo "  FAIL: default build broke"; rc=1
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — Ac16 static-stack spill compiles clean under +mos-xy16 (Layer 4 Ac16 path intact)" \
             || echo "RESULT: FAIL"
exit $rc
