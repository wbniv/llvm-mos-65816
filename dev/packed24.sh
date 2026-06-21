#!/usr/bin/env bash
# dev/packed24.sh — #320 packed-24 (addrspace 3) Increment B: prove a 3-byte PACKED
# far pointer round-trips a 24-bit address (incl. the bank byte) through 3-byte
# storage. Builds examples/65816/packed24/packed24_e2e.c against the snes-far child
# platform (64 KiB, banks $00+$01) with -mcpu=mosw65816 AND +mos-a16 (the far value
# is 32-bit), asserts the packed store/load is a 3-byte access and the deref is far
# indirect-long (`lda [dp]`, A7), boots the ROM headless in MAME, and checks the byte
# read back through the unpacked pointer (bank $01) round-trips to 0xF3.
#
# The fidelity point: the far pointer targets bank $01, so its bank byte must survive
# the 3-byte packing — if it were dropped, the deref would read bank $00 and the
# result would not be 0xF3. Gate is host-expected == +mos-a16 on both emulators (MAME
# here + bsnes-jg via dev/run.sh xcheck).
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh packed24.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK incl. snes-far
# (MOS_TOOLCHAIN=.../llvm-mos-install dev/run.sh build).
# See docs/plans/2026-06-21-320-packed24-incrementB-handoff.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh packed24   # build packed24_e2e.c (snes-far, +mos-a16), boot in MAME, assert packed far ptr round-trip (bank \$01) == 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/packed24/packed24_e2e.c"
ROM="$BUILD/packed24_e2e.sfc"
MAP="$BUILD/packed24_e2e.map"
OBJ="$BUILD/packed24_e2e.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0xF3   # far_src (0xA9, bank $01) ^ 0x5A; flip to exercise the negative control

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
echo "==> storage gate: the packed slot is 3 bytes (vs 4 for an AS_Far pointer)"
# slot's size column in the map; a packed (p3) pointer object must be 3 bytes.
SLOTSZ="$(awk '$NF == "slot" { print $3; exit }' "$MAP" || true)"
if [ "$((0x${SLOTSZ:-0}))" -eq 3 ]; then
  echo "  PASS: slot is 3 bytes (0x$SLOTSZ)"
else
  echo "  FAIL: slot is 0x${SLOTSZ:-<not found>} bytes (expected 3)"; rc=1
fi

echo "==> disasm gate: packed deref is far indirect-long (A7 = lda [dp]) + the bank byte is materialized"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*a7 |ADDR24_BANK' || true
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*a7 '   && echo "  PASS: packed ptr deref -> LDA IndirectLong (a7)"           || { echo "  FAIL: no A7 (indirect-long) far deref"; rc=1; }
printf '%s\n' "$DIS" | grep -qiE 'ADDR24_BANK'            && echo "  PASS: far_src bank byte materialized (R_MOS_ADDR24_BANK)" || { echo "  FAIL: no R_MOS_ADDR24_BANK (bank byte not formed)"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (build/storage/disasm gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (bank-\$01 read through the packed ptr)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "packed-24 far ptr (3-byte store/load, bank \$01) unpacked + far-derefed == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
