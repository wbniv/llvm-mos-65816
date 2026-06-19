#!/usr/bin/env bash
# dev/a16spillr.sh — #321 regression test: SOFT-stack 16-bit-accumulator (Ac16) spill.
# Companion to dev/a16spill.sh (static stack). examples/65816/a16spillr.c is a RECURSIVE
# (-> soft-stack) +mos-a16 function that keeps a 16-bit value in A16 across the recursive
# call; before the fix the soft-stack spill (MOSRegisterInfo::expandLDSTStk) crashed the
# backend ("Scavenger spill for register not yet implemented" / SelectImm $a16). The fix
# spills Ac16 via a 16-bit indirect LDAIndir16/STAIndir16. See
# docs/plans/2026-06-16-321-fix-cmp-value-selectimm.md.
#
# Unlike dev/a16spill.sh (a compile-time crash gate), this is a VALUE test: it asserts
# host == default == +mos-a16 for corpus_result on MAME + bsnes-jg (the spilled 16-bit
# value must be correct), PLUS a -verify-machineinstrs crash gate and a check that the
# body still exercises a soft-stack Ac16 spill (so it can't silently stop guarding the bug).
#
# Runs INSIDE the dev container; drive: dev/run.sh a16spillr. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16spillr   # soft-stack Ac16 spill regression, corpus_result==0x3457 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16spillr.c"
DROM="$BUILD/a16spillr_default.sfc"; DMAP="$BUILD/a16spillr_default.map"
AROM="$BUILD/a16spillr_a16.sfc";     AMAP="$BUILD/a16spillr_a16.map"
WANT=0x3457
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs must compile CLEAN (was: soft-stack Ac16 spill crash)"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$BUILD/a16spillr.o" "$SRC" 2>"$BUILD/a16spillr.vlog"; then
  echo "  PASS: clean (exit 0)"
else
  echo "  FAIL: backend rejected the build:"; grep -iE "Scavenger|Flag register|SelectImm|fatal|Bad machine" "$BUILD/a16spillr.vlog" | head -4; rc=1
fi

echo "==> 2) the body must SPILL an Ac16 value on the SOFT stack (STStk/LDStk of \$a16 pre-expansion)"
mir="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -print-after=virtregrewriter -c -o /dev/null "$SRC" 2>&1 || true)"
nspill=$(printf '%s\n' "$mir" | grep -ciE '(STStk|LDStk).*a16' || true)
if [ "$nspill" -ge 1 ]; then
  echo "  PASS: $nspill soft-stack Ac16 spill op(s) — the bug path is exercised"
else
  echo "  FAIL: no soft-stack Ac16 spill (STStk/LDStk \$a16) — test no longer guards the soft-stack bug"; rc=1
fi

echo "==> 3) build default + +mos-a16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816          -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$DROM" >/dev/null
python3 "$ROOT/tools/snes-checksum.py" "$AROM" >/dev/null

echo "==> 4) MAME: host == default == +mos-a16 (corpus_result == $WANT)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
echo "  default:"; run_assert "$DROM" "$DMAP" corpus_result "$WANT" || rc=1
echo "  +mos-a16:"; run_assert "$AROM" "$AMAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> 5) bsnes-jg: +mos-a16 corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$AMAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$AROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> 5) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
emu_verdict "$rc" "soft-stack Ac16 spill compiles clean and computes 0x3457; both emulators agree"
exit $rc
