#!/usr/bin/env bash
# dev/a16bit.sh — #321 Increment 1b: 16-bit-accumulator bitwise AND/OR/XOR via A16.
#
# Builds examples/65816/a16bit.c with +mos-a16 and proves the dual-width A16
# bitwise path: g_and/g_or/g_xor = a16v {&,|,^} b16v each compile to a 16-bit
# bitwise op bracketed by its own rep/sep pair (no carry) — rep #$20; lda;
# and|ora|eor; sta; sep #$20 — and the AND result reads corpus_result == 0x0F00
# (0xFF0F & 0x0FF0) on BOTH MAME and bsnes-jg, driven by the native-mode crt0.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16bit. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
# bsnes-jg cross-check reuses build/jgxcheck (built by dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-increment-1b-dual-width-accumulator.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16bit   # build a16bit.c +mos-a16, assert and/ora/eor (16-bit) + corpus_result==0x0F00 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16bit.c"
ROM="$BUILD/a16bit.sfc"; MAP="$BUILD/a16bit.map"; OBJ="$BUILD/a16bit.o"
WANT=0x0F00
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16bit.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: three 16-bit bitwise ops select to and / ora / eor under rep/sep"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|2[df]|0[df]|4[df])\b' | head -20
nand=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*2[df]\b')   # 2d/2f = and abs/long
nora=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*0[df]\b')   # 0d/0f = ora abs/long
neor=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*4[df]\b')   # 4d/4f = eor abs/long
[ "$nand" -ge 1 ] && echo "  PASS: 16-bit and present" || { echo "  FAIL: no 16-bit and"; rc=1; }
[ "$nora" -ge 1 ] && echo "  PASS: 16-bit ora present" || { echo "  FAIL: no 16-bit ora"; rc=1; }
[ "$neor" -ge 1 ] && echo "  PASS: 16-bit eor present" || { echo "  FAIL: no 16-bit eor"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0xFF0F & 0x0FF0)"
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
[ $rc -eq 0 ] && echo "RESULT: PASS — 16-bit and/ora/eor select correctly; AND reads 0x0F00 on both emulators" \
             || echo "RESULT: FAIL"
exit $rc
