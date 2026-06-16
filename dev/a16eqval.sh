#!/usr/bin/env bash
# dev/a16eqval.sh — #321 native s16 equality-as-value: `b = (a == c)` stored as a VALUE.
# examples/65816/a16eqval.c. Two assertions:
#   1. VALUE: corpus_result == 0x0101 host == default == +mos-a16 on MAME + bsnes-jg
#      (equality-as-value still narrows to the 8-bit chain — correct, just not native).
#   2. NO-PROLOGUE: under +mos-a16 the s16 operands must load byte-wise for the 8-bit
#      compare, NOT via a wasteful `rep; lda abs -> A16; sta imag16; sep` round-trip
#      (fixed 2026-06-16 in legalizeLoadStore16). Gate: the first 8-bit compare
#      (cmp/cpx/cpy) appears BEFORE the first `rep #$20` (so the operands are byte-loaded;
#      the only rep brackets are the later s16 result combination + store).
#
# Runs INSIDE the dev container; drive: dev/run.sh a16eqval. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16eqval   # s16 equality-as-value: corpus_result==0x0101, operands load byte-wise (no 16-bit prologue)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16eqval.c"
DROM="$BUILD/a16eqval_default.sfc"; DMAP="$BUILD/a16eqval_default.map"
AROM="$BUILD/a16eqval_a16.sfc";     AMAP="$BUILD/a16eqval_a16.map"
OBJ="$BUILD/a16eqval.o"
WANT=0x0101
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean + NO 16-bit-load prologue on the compare operands"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/a16eqval.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/a16eqval.vlog" | head -3; rc=1; }
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
firstcmp=$(printf '%s\n' "$DIS" | grep -nE '\b(cmp|cpx|cpy)\b' | head -1 | cut -d: -f1 || true)
firstrep=$(printf '%s\n' "$DIS" | grep -nE 'rep[[:space:]]+#\$20' | head -1 | cut -d: -f1 || true)
if [ -n "$firstcmp" ] && { [ -z "$firstrep" ] || [ "$firstcmp" -lt "$firstrep" ]; }; then
  echo "  PASS: first 8-bit compare precedes any rep #\$20 — operands loaded byte-wise (no wasteful prologue)"
else
  echo "  FAIL: a rep #\$20 precedes the first compare — the wasteful 16-bit-load+spill prologue is back"; rc=1
fi

echo "==> 2) build default + +mos-a16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816          -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$DROM" >/dev/null
python3 "$ROOT/tools/snes-checksum.py" "$AROM" >/dev/null

echo "==> 3) MAME: host == default == +mos-a16 (corpus_result == $WANT)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
echo "  default:";  run_assert "$DROM" "$DMAP" corpus_result "$WANT" || rc=1
echo "  +mos-a16:"; run_assert "$AROM" "$AMAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> 4) bsnes-jg: +mos-a16 corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$AMAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$AROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> 4) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — s16 equality-as-value computes 0x0101 (both emulators) and loads operands byte-wise" \
             || echo "RESULT: FAIL"
exit $rc
