#!/usr/bin/env bash
# dev/far_sizeof.sh — #320 (a) far pointers, sizeof(far*) == 4 gate (Layer F:
# getPointerWidthV(AS2) -> 32). The compile itself gates the size: far_sizeof.c
# carries `_Static_assert(sizeof(FAR const void*) == 4)` and `== 4` for a far fn
# ptr, so a build only succeeds when clang's C-level far-pointer size matches the
# p2:32:8 IR width. The runtime gate then proves a far pointer STORED in a struct
# field lays out correctly: it derefs the stored 4-byte far pointer (lda [dp],
# A7) and XORs in the adjacent `tag`, so corpus_result == 0x12 ^ 0xC3 == 0xD1
# only if the 4-byte store did NOT clobber `tag` (which a mis-sized 2-byte field
# would).
#
# Builds examples/65816/far_sizeof.c against the snes platform (bank $00) with
# -mcpu=mosw65816 AND +mos-a16 (a far pointer is a 32-bit value; storing a p2
# VALUE is a16-gated, Gap B). Gate is host-expected == +mos-a16 on both emulators
# (MAME here + bsnes-jg via dev/run.sh xcheck); no default leg.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_sizeof.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# See docs/plans/2026-06-21-320-far-pointer-sizeof.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_sizeof   # build examples/65816/far_sizeof.c (snes, +mos-a16); the _Static_assert gates sizeof(far*)==4, boot in MAME, assert a stored far pointer derefs == 0xD1"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_sizeof.c"
ROM="$BUILD/far_sizeof.sfc"
MAP="$BUILD/far_sizeof.map"
OBJ="$BUILD/far_sizeof.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0xD1   # arr[0] (0x12) ^ tag (0xC3): both intact iff sizeof(far*)==4 (no field clobber)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> sizeof gate: compile far_sizeof.c (the _Static_assert(sizeof(FAR*)==4) FAILS the build if getPointerWidthV(AS2) != 32)"
echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
echo "==> disasm gate: the stored far pointer is dereferenced indirect-long (A7 = lda [dp])"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*a7 ' || true
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*a7 ' && echo "  PASS: stored far pointer deref -> LDA IndirectLong (A7)" || { echo "  FAIL: no A7 (indirect-long) load of the stored far pointer"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (stored far ptr derefs to 0x12; adjacent tag 0xC3 not clobbered by the 4-byte store)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "far pointer stored in a struct field (4-byte, sizeof(far*)==4) then dereferenced (lda [dp]); adjacent tag intact; value == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
