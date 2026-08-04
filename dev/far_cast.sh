#!/usr/bin/env bash
# dev/far_cast.sh — #320 Increment 3 (3b): prove a near->far address-space cast
# (AS0 -> AS2) followed by a RUNTIME dereference lowers to 65816 indirect-long
# (`lda [dp]`, opcode A7) and reads the right bank-$00 byte. Builds
# examples/65816/far_cast.c against the snes platform (bank $00) with
# -mcpu=mosw65816 AND +mos-a16 (the far pointer is a 32-bit value; 32-bit value
# legalization is a16-gated), asserts the deref is indirect-long (A7), boots the
# ROM headless in MAME, and checks the byte read via the cast far pointer
# round-trips to 0xF3.
#
# Gate is host-expected == +mos-a16 on both emulators (MAME here + bsnes-jg via
# dev/run.sh xcheck); the default 8-bit build can't compile a runtime far deref.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_cast.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# See docs/plans/2026-06-20-320-far-pointer-runtime.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_cast   # build examples/65816/far_cast.c (snes, +mos-a16), boot in MAME, assert near->far cast deref (lda [dp]) == 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_cast.c"
ROM="$BUILD/far_cast.sfc"
MAP="$BUILD/far_cast.map"
OBJ="$BUILD/far_cast.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0xF3   # near_sentinel (0xA9) ^ 0x5A; flip this to exercise the negative control

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
echo "==> disasm gate: the runtime deref is indirect-long (A7 = lda [dp])"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"
"$TOOL/llvm-objdump" -h "$OBJ" >/dev/null 2>&1 \
  || { echo "FAIL: -verify-machineinstrs emitted no real object (vacuous verify)"; exit 1; }
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*a7 ' || true
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*a7 ' && echo "  PASS: near->far cast deref -> LDA IndirectLong (a7)" || { echo "  FAIL: no A7 (indirect-long) deref"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (the cast far read)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "near->far address-space cast then lda [dp] (bank \$00); byte round-tripped == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
