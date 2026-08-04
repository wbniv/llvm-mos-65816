#!/usr/bin/env bash
# dev/a16indiry.sh — #321 native 16-bit (zp),y indexed load (`lda (zp),y` in M16).
#
# Builds examples/65816/a16indiry.c with +mos-a16. A 16-bit struct-field access via
# a runtime pointer + 8-bit Y offset must compile to ONE native
# `rep #$20; lda (zp),y; sep #$20` (opcode B1) — NOT two 8-bit `lda (zp),y` ops
# (with an `iny` in between). corpus_result == 0x5678 (member .b of g_pair) on BOTH
# MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16indiry. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-18-321-abs-x-indiry-16bit-indexed-load-store.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16indiry   # 16-bit (zp),y indexed load (lda (zp),y in M16, no iny+byte-pair); corpus_result==0x5678 both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16indiry.c"
ROM="$BUILD/a16indiry.sfc"; MAP="$BUILD/a16indiry.map"; OBJ="$BUILD/a16indiry.o"
WANT=0x5678
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16indiry.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: native 16-bit lda (zp),y (B1) under rep/sep — no iny+byte-pair"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"
"$TOOL/llvm-objdump" -h "$OBJ" >/dev/null 2>&1 \
  || { echo "FAIL: -verify-machineinstrs emitted no real object (vacuous verify)"; exit 1; }
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|b1|91|88|c8)\b' | head -20
nrep=$(printf '%s\n' "$DIS"  | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nldiy=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*b1\b' || true)   # lda (zp),y (b1)
niny=$(printf '%s\n' "$DIS"  | grep -ciE '^\s*[0-9a-f]+:\s*(88|c8)\b' || true)  # dey (88) / iny (c8)
[ "$nrep" -ge 1 ] && echo "  PASS: $nrep rep #\$20 bracket(s) — native 16-bit indirect-indexed access" \
  || { echo "  FAIL: no rep #\$20"; rc=1; }
[ "$nldiy" -ge 1 ] && echo "  PASS: $nldiy lda (zp),y (16-bit indirect-indexed load, opcode B1)" \
  || { echo "  FAIL: no lda (zp),y (B1) — byte-pair path still used"; rc=1; }
[ "$niny" -eq 0 ] && echo "  PASS: no iny/dey (no 8-bit byte-pair sequence)" \
  || { echo "  FAIL: found $niny iny/dey ops — access narrowed to 8-bit pair"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> bsnes-jg: assert corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then
    echo "  $line"
  else echo "  $line"; rc=1; fi
else
  echo "==> bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
emu_verdict "$rc" "native 16-bit (zp),y load (lda (zp),y / opcode B1) reads 0x5678; both emulators agree"
exit $rc
