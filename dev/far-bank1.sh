#!/usr/bin/env bash
# dev/far-bank1.sh — #320 Increment 2b: prove a far (24-bit) pointer read crosses
# a real ROM bank boundary. Builds examples/65816/far-bank1.c against the snes-far
# child platform (64 KiB LoROM, banks $00+$01) with -mcpu=mosw65816, asserts the
# far global lands in bank $01 ($018xxx) as a true absolute-long, boots the ROM
# headless in MAME, and checks the byte read from bank $01 round-trips to 0xF3.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far-bank1.
# Prereqs (built once): from-source toolchain (dev/run.sh toolchain) AND the SDK
# install incl. the snes-far platform (MOS_TOOLCHAIN=.../llvm-mos-install dev/run.sh build).
# See docs/plans/2026-06-14-320-increment-2b-multi-bank-rom-far-read.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far-bank1   # build examples/65816/far-bank1.c (snes-far, 64 KiB), boot in MAME, assert bank-\$01 far read == 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far-bank1.c"
ROM="$BUILD/far-bank1.sfc"
MAP="$BUILD/far-bank1.map"
OBJ="$BUILD/far-bank1.o"
WANT=0xF3   # far_src (0xA9) ^ 0x5A; flip this to exercise the negative control

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
sz="$(stat -c%s "$ROM")"
printf '    %-14s %6s bytes\n' far-bank1.sfc "$sz"

echo "==> size gate: 64 KiB image (banks \$00 + \$01)"
[ "$sz" -eq 65536 ] && echo "  PASS: 64 KiB (65536 bytes)" || { echo "  FAIL: expected 65536, got $sz"; rc=1; }

echo "==> placement gate: far_src lands in bank \$01 (\$018xxx) per the link map"
# Map cols: VMA LMA Size Align Out In Symbol — far_src's VMA must be >= 0x018000.
FARVMA="$(awk '$NF == "far_src" { print $1; exit }' "$MAP" || true)"
if [ -n "$FARVMA" ] && [ "$((0x$FARVMA))" -ge "$((0x18000))" ]; then
  echo "  PASS: far_src @ 0x$FARVMA (bank \$01)"
else
  echo "  FAIL: far_src @ 0x${FARVMA:-<not found>} (expected >= 0x018000, bank \$01)"; rc=1
fi

echo "==> disasm gate: far access is absolute-long (AF) + R_MOS_ADDR24 (standalone object)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(af|8f) |ADDR(_)?24' || true
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*af '       && echo "  PASS: far load -> LDA AbsoluteLong (af)"        || { echo "  FAIL: no AF (absolute-long) far load"; rc=1; }
printf '%s\n' "$DIS" | grep -qiE 'ADDR(_)?24'                 && echo "  PASS: far global -> R_MOS_ADDR24 relocation"    || { echo "  FAIL: no R_MOS_ADDR24"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (build/placement/disasm gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (the bank-\$01 read)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  echo "RESULT: PASS — far read crossed into bank \$01 and round-tripped == $WANT"
else
  echo "RESULT: FAIL — see SMOKE: line above"
  exit 1
fi
