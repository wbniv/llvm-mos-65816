#!/usr/bin/env bash
# dev/farcc_split.sh — #320 Inc 4 Phase 2 (A1): far-pointer CC variant (b) "split"
# (low-16 offset in an RS# Imag16 pair + bank byte in an RC# Imag8). Builds the
# SHARED variant-agnostic round-trip source examples/65816/farcc_imag32.c (a far
# pointer returned from make_far_ptr() AND passed into deref_far() across noinline
# calls) with -mcpu=mosw65816 +mos-a16 +mos-farcc-split, and asserts the 24-bit
# address round-trips to 0xF3 on both emulators — proving the heterogeneous
# {offset,bank} CC split (assignCustomValue) (de)composes the pointer correctly in
# both directions.
#
# Gate (as dev/farcc_imag32.sh): host-expected == +mos-a16 +mos-farcc-split on MAME
# + bsnes-jg; -verify-machineinstrs clean; negative control = does NOT compile
# without the flag. Drive from the host: dev/run.sh farcc_split.
# See docs/plans/2026-06-20-320-far-pointer-cc-build-all-variants.md (Phase 2, A1).
set -euo pipefail

usage() { echo "Usage: dev/run.sh farcc_split   # far-ptr CC variant (b) Imag16+bank: round-trip a far ptr across calls == 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/farcc_imag32.c"   # shared round-trip source; variant = build flag
ROM="$BUILD/farcc_split.sfc"
MAP="$BUILD/farcc_split.map"
OBJ="$BUILD/farcc_split.o"
NEGLOG="$BUILD/farcc_split_noflag.err"
A16=(-Xclang -target-feature -Xclang +mos-a16)
FARCC=(-Xclang -target-feature -Xclang +mos-farcc-split)
WANT=0xF3

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> opt-in control: WITHOUT +mos-farcc-split the far ptr uses the DEFAULT (Imag32, the shipped winner); the flag is an opt-in override to variant (b)"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs \
     -c -o /dev/null "$SRC" 2>"$NEGLOG"; then
  echo "  PASS: compiles by default (Imag32); +mos-farcc-split overrides to variant (b) below"
else
  echo "  FAIL: the default-on far-ptr CC regressed — far-ptr-across-call no longer compiles by default:"
  grep -iE 'G_UNMERGE|Bad machine code|fatal|error' "$NEGLOG" | head -3 | sed 's/^/    /' || true; rc=1
fi

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 +mos-farcc-split -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 "${A16[@]}" "${FARCC[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

sz="$(stat -c%s "$ROM")"
printf '    %-18s %6s bytes\n' farcc_split.sfc "$sz"
echo "==> size gate: 64 KiB image (banks \$00 + \$01)"
[ "$sz" -eq 65536 ] && echo "  PASS: 64 KiB" || { echo "  FAIL: expected 65536, got $sz"; rc=1; }

echo "==> placement gate: bank1_sentinel in bank \$01 (\$018xxx)"
FARVMA="$(awk '$NF == "bank1_sentinel" { print $1; exit }' "$MAP" || true)"
if [ -n "$FARVMA" ] && [ "$((0x$FARVMA))" -ge "$((0x18000))" ]; then
  echo "  PASS: bank1_sentinel @ 0x$FARVMA (bank \$01)"
else
  echo "  FAIL: bank1_sentinel @ 0x${FARVMA:-<not found>} (expected >= 0x018000)"; rc=1
fi

echo "==> disasm gate: the recomposed far pointer is dereferenced indirect-long (A7 = lda [dp]) in deref_far"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" "${FARCC[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*a7 ' || true
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*a7 ' && echo "  PASS: far deref -> LDA IndirectLong (a7)" || { echo "  FAIL: no A7 (indirect-long) deref"; rc=1; }
printf '%s\n' "$DIS" | grep -qiE '\bjsr\b' && echo "  PASS: real calls present (not inlined away)" || { echo "  FAIL: no JSR — calls were inlined"; rc=1; }

[ $rc -eq 0 ] || { echo "RESULT: FAIL (negative-control/build/placement/disasm gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (far ptr round-tripped via {offset,bank} split)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "far pointer split into offset(RS#)+bank(RC#) across real calls (variant b); 24-bit address survived both directions, byte read == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
