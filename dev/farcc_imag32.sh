#!/usr/bin/env bash
# dev/farcc_imag32.sh — #320 Inc 4 Phase 2 (A0): prove a 32-bit far (addrspace 2)
# pointer CROSSES a call boundary under variant (a) Imag32. Builds
# examples/65816/farcc_imag32.c against the snes-far platform (64 KiB, banks
# $00+$01) with -mcpu=mosw65816 +mos-a16 +mos-farcc-imag32. A far pointer is
# RETURNED from make_far_ptr() and PASSED into deref_far() across real (noinline)
# calls; the dereferenced byte must round-trip to 0xF3, proving all 4 pointer bytes
# survived the far-ptr calling convention in both directions.
#
# Negative control: the SAME source WITHOUT +mos-farcc-imag32 must FAIL to compile
# (the documented `G_UNMERGE_VALUES %p2` machine-verifier crash) — i.e. the feature
# is load-bearing and default codegen is unaffected when it is off.
#
# Gate is host-expected == +mos-a16 +mos-farcc-imag32 on both emulators (MAME here
# + bsnes-jg via dev/run.sh xcheck): the default 8-bit build legitimately can't
# compile a runtime far deref, so there is no default leg (as in dev/far_indir.sh).
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh farcc_imag32.
# Prereqs (built once): from-source toolchain (dev/run.sh toolchain) AND the SDK
# install incl. the snes-far platform (MOS_TOOLCHAIN=.../llvm-mos-install dev/run.sh build).
# See docs/plans/2026-06-20-320-far-pointer-cc-build-all-variants.md (Phase 2, A0).
set -euo pipefail

usage() { echo "Usage: dev/run.sh farcc_imag32   # build examples/65816/farcc_imag32.c (snes-far, +mos-a16 +mos-farcc-imag32), boot in MAME, assert a far ptr round-trips across calls == 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/farcc_imag32.c"
ROM="$BUILD/farcc_imag32.sfc"
MAP="$BUILD/farcc_imag32.map"
OBJ="$BUILD/farcc_imag32.o"
NEGLOG="$BUILD/farcc_imag32_nofarcc.err"
A16=(-Xclang -target-feature -Xclang +mos-a16)
FARCC=(-Xclang -target-feature -Xclang +mos-farcc-imag32)
WANT=0xF3   # bank1_sentinel (0xA9) ^ 0x5A; flip to exercise the negative control

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> default-on control: +mos-farcc-imag32 is now the DEFAULT (D, 2026-06-21) — WITHOUT it the far-ptr-across-call still compiles, identically"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs \
     -c -o /dev/null "$SRC" 2>"$NEGLOG"; then
  echo "  PASS: compiles by default — Imag32 is the shipped default far-ptr CC; the flag is now redundant"
else
  echo "  FAIL: the default-on far-ptr CC regressed — far-ptr-across-call no longer compiles by default:"
  grep -iE 'G_UNMERGE|Bad machine code|fatal|error' "$NEGLOG" | head -3 | sed 's/^/    /' || true; rc=1
fi

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 +mos-farcc-imag32 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 "${A16[@]}" "${FARCC[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

sz="$(stat -c%s "$ROM")"
printf '    %-18s %6s bytes\n' farcc_imag32.sfc "$sz"

echo "==> size gate: 64 KiB image (banks \$00 + \$01)"
[ "$sz" -eq 65536 ] && echo "  PASS: 64 KiB (65536 bytes)" || { echo "  FAIL: expected 65536, got $sz"; rc=1; }

echo "==> placement gate: bank1_sentinel lands in bank \$01 (\$018xxx) per the link map"
FARVMA="$(awk '$NF == "bank1_sentinel" { print $1; exit }' "$MAP" || true)"
if [ -n "$FARVMA" ] && [ "$((0x$FARVMA))" -ge "$((0x18000))" ]; then
  echo "  PASS: bank1_sentinel @ 0x$FARVMA (bank \$01)"
else
  echo "  FAIL: bank1_sentinel @ 0x${FARVMA:-<not found>} (expected >= 0x018000, bank \$01)"; rc=1
fi

echo "==> disasm gate: the far pointer is received + dereferenced indirect-long (A7 = lda [dp]) in deref_far"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" "${FARCC[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*a7 ' || true
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*a7 ' && echo "  PASS: far deref -> LDA IndirectLong (a7)" || { echo "  FAIL: no A7 (indirect-long) deref"; rc=1; }
printf '%s\n' "$DIS" | grep -qiE '\bjsr\b' && echo "  PASS: real calls present (make_far_ptr / deref_far not inlined away)" || { echo "  FAIL: no JSR — calls were inlined, the far-ptr CC is not exercised"; rc=1; }

[ $rc -eq 0 ] || { echo "RESULT: FAIL (negative-control/build/placement/disasm gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (far ptr round-tripped across calls)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "far pointer returned from make_far_ptr() + passed into deref_far() across real calls (variant a Imag32 / RL quad); 24-bit address survived both directions, byte read == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
