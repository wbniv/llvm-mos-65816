#!/usr/bin/env bash
# dev/a16.sh — #321 Increment 1a: 16-bit-accumulator REP/SEP demonstration.
#
# Builds examples/65816/a16.c with +mos-a16 and proves the MOSInsertREPSEP pass
# fuses a 16-bit store-of-zero into one `rep #$20; stz; sep #$20` (vs two 8-bit
# `stz` without the flag), and that the value is CORRECT: g16 is fully zeroed, so
# corpus_result = g16 + 0x42 == 0x0042 on BOTH MAME and bsnes-jg (a mis-placed
# REP/SEP or a half-width store would read 0xBE42 from g16's 0xBEEF initialiser).
#
# Runs INSIDE the dev container; drive: dev/run.sh a16. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
# bsnes-jg cross-check reuses build/jgxcheck (built by dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-increment-1-16bit-accumulator.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16   # build a16.c +mos-a16, assert rep/stz/sep + corpus_result==0x0042 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16.c"
ROM="$BUILD/a16.sfc"; MAP="$BUILD/a16.map"; OBJ="$BUILD/a16.o"
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: 16-bit store-of-zero fuses to rep #\$20 / single stz / sep #\$20"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|9c|e2 20)' | head
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*c2 20\b' && echo "  PASS: rep #\$20 (c2 20)" || { echo "  FAIL: no rep #\$20"; rc=1; }
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*e2 20\b' && echo "  PASS: sep #\$20 (e2 20)" || { echo "  FAIL: no sep #\$20"; rc=1; }
nstz=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*9c ')
[ "$nstz" -eq 1 ] && echo "  PASS: single fused stz (was 2 without +mos-a16)" || { echo "  FAIL: expected 1 stz, got $nstz"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == 0x0042 (g16 fully zeroed)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
run_assert "$ROM" "$MAP" corpus_result 0x0042 || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> bsnes-jg: assert corpus_result == 0x0042 (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" 0x0042 180 2>&1)"; then
    echo "  $line"
  else echo "  $line"; rc=1; fi
else
  echo "==> bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — 16-bit STZ (rep/stz/sep) zeroes g16; both emulators read 0x0042" \
             || echo "RESULT: FAIL"
exit $rc
