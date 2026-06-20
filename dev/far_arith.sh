#!/usr/bin/env bash
# dev/far_arith.sh — #320 Increment 3 (3c): prove far-pointer ARITHMETIC. A runtime
# far pointer (AS2) is incremented (`fp++` -> G_PTR_ADD {PF,S32}, a 32-bit add) and
# the result dereferenced via 65816 indirect-long (`lda [dp]`, opcode A7), reading
# the byte one past the base. Builds examples/65816/far_arith.c against the snes
# platform (bank $00) with -mcpu=mosw65816 AND +mos-a16 (the far pointer is a 32-bit
# value, and `fp++` first exercised the s32->4x s8 unmerge legalization — both
# a16-gated), asserts the deref is indirect-long (A7), boots the ROM headless in
# MAME, and checks the byte read via the incremented far pointer round-trips to 0xF3.
#
# Gate is host-expected == +mos-a16 on both emulators (MAME here + bsnes-jg via
# dev/run.sh xcheck); the default 8-bit build can't compile a runtime far value.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_arith.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# See docs/plans/2026-06-20-320-far-pointer-runtime.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_arith   # build examples/65816/far_arith.c (snes, +mos-a16), boot in MAME, assert fp++ then lda [dp] == 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_arith.c"
ROM="$BUILD/far_arith.sfc"
MAP="$BUILD/far_arith.map"
OBJ="$BUILD/far_arith.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0xF3   # arr[1] (0xA9) ^ 0x5A; flip arr[1] in the source to exercise the negative control

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
echo "==> disasm gate: the incremented-far-pointer deref is indirect-long (A7 = lda [dp])"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*a7 ' || true
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*a7 ' && echo "  PASS: fp++ then deref -> LDA IndirectLong (a7)" || { echo "  FAIL: no A7 (indirect-long) deref"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (the post-increment far read)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "far-pointer fp++ (G_PTR_ADD {PF,S32}) then lda [dp] (bank \$00); byte round-tripped == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
