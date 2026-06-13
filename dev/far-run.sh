#!/usr/bin/env bash
# dev/far-run.sh — #320 Increment 2: prove the Increment-1 far-pointer codegen
# EXECUTES correctly on emulated silicon (not just disassembles). Builds
# examples/65816/far-run.c with -mcpu=mosw65816 into a bootable SNES ROM, boots it
# headless in MAME, and asserts the far-STORED byte read back from WRAM == 0xF3.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far-run.
# Prereqs (built once): the from-source toolchain (dev/run.sh toolchain) AND the
# SDK/platform install (MOS_TOOLCHAIN=.../llvm-mos-install dev/run.sh build) — the
# far patch lives only in the from-source toolchain, and the link/cfg come from the
# SDK build. See docs/plans/2026-06-14-320-increment-2-far-pointer-emulator-end-to-end-mi.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far-run   # build examples/65816/far-run.c (-mcpu=mosw65816), boot in MAME, assert far store == 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far-run.c"
ROM="$BUILD/far-run.sfc"
MAP="$BUILD/far-run.map"
OBJ="$BUILD/far-run.o"
WANT=0xF3   # far_src (0xA9) ^ 0x5A; flip this to exercise the negative control

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes.cfg -mcpu=mosw65816 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"
printf '    %-14s %6s bytes\n' far-run.sfc "$(stat -c%s "$ROM")"

# Disasm gate: far_src / corpus_result are relocatable GLOBALS, so the assembler
# can't prove a zero bank and keeps absolute-long (AF/8F + R_MOS_ADDR24) — proof the
# codegen emits 24-bit accesses, not 16-bit. (Standalone object, like dev/far.sh:
# the linked .sfc is raw binary; the object is where the opcode is inspectable.)
echo "==> disasm gate: compile standalone object + llvm-objdump -dr"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS"
rc=0
check() { # name regex
  if printf '%s\n' "$DIS" | grep -qiE "$2"; then echo "  PASS: $1"; else echo "  FAIL: $1 (no match: $2)"; rc=1; fi
}
check "far load  far_src       -> LDA AbsoluteLong (opcode af)"  '^\s*[0-9a-f]+:\s*af '
check "far store corpus_result -> STA AbsoluteLong (opcode 8f)"  '^\s*[0-9a-f]+:\s*8f '
check "far globals carry 24-bit relocations (R_MOS_ADDR24)"      'ADDR(_)?24'
[ $rc -eq 0 ] || { echo "RESULT: FAIL (codegen did not emit absolute-long)"; exit 1; }

# Execution gate: boot the ROM headless in MAME and read corpus_result back from the
# $7E WRAM mirror. Reuses _emu.sh's run_assert/require_bios + dev/smoke.lua unchanged.
echo "==> execution gate: boot in MAME, assert corpus_result == $WANT"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  echo "RESULT: PASS — far load+store executed in MAME; far-stored byte read back == $WANT"
else
  echo "RESULT: FAIL — see SMOKE: line above"
  exit 1
fi
