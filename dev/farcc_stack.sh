#!/usr/bin/env bash
# dev/farcc_stack.sh — #320 Inc 4 Phase 2 (A3): far-pointer CC variant (d) "Stack"
# (the whole 32-bit far pointer passed/returned in one 4-byte slot on the SOFT static
# stack, RS0-relative — the memory analog of (a)'s single RL quad). Builds the SHARED
# variant-agnostic round-trip source examples/65816/farcc_imag32.c (a far pointer
# returned from make_far_ptr() AND passed into deref_far() across noinline calls) with
# -mcpu=mosw65816 +mos-a16 +mos-farcc-stack, and asserts the 24-bit address round-trips
# to 0xF3 on both emulators — proving the CCAssignToStack rule + the assignValueToAddress
# ptrtoint/inttoptr (store i32 / load i32) carry the pointer correctly in both directions.
#
# NB this is the SOFT static stack (RS0); the hardware-S `,S` convention is a separate,
# deferred lift (record-and-drop — see the plan). Gate (as dev/farcc_axy.sh): host ==
# +mos-a16 +mos-farcc-stack on MAME + bsnes-jg; -verify-machineinstrs clean; negative
# control = does NOT compile without the flag. Drive from the host: dev/run.sh farcc_stack.
# See docs/plans/2026-06-21-320-far-cc-variant-d-stack.md (A3).
set -euo pipefail

usage() { echo "Usage: dev/run.sh farcc_stack   # far-ptr CC variant (d) Stack: round-trip a far ptr across calls == 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/farcc_imag32.c"   # shared round-trip source; variant = build flag
ROM="$BUILD/farcc_stack.sfc"
MAP="$BUILD/farcc_stack.map"
OBJ="$BUILD/farcc_stack.o"
NEGLOG="$BUILD/farcc_stack_noflag.err"
A16=(-Xclang -target-feature -Xclang +mos-a16)
FARCC=(-Xclang -target-feature -Xclang +mos-farcc-stack)
WANT=0xF3

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> negative control: WITHOUT +mos-farcc-stack the far-ptr-across-call must NOT compile"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs \
     -c -o /dev/null "$SRC" 2>"$NEGLOG"; then
  echo "  FAIL: built without the feature — the far-ptr CC is NOT properly gated"; rc=1
else
  echo "  PASS: rejected without +mos-farcc-stack. Diagnostic:"
  grep -iE 'G_UNMERGE|Bad machine code|fatal|error' "$NEGLOG" | head -3 | sed 's/^/    /' || true
fi

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 +mos-farcc-stack -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 "${A16[@]}" "${FARCC[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

sz="$(stat -c%s "$ROM")"
printf '    %-18s %6s bytes\n' farcc_stack.sfc "$sz"
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
# soft-stack passing: the 4-byte far ptr moves through the RS0-relative soft stack
# ((__rc0)/(__rc0),y), NOT a hardware-S `,S` operand — confirm we did NOT emit `,s`.
printf '%s\n' "$DIS" | grep -qiE ',\s*s\b' && { echo "  FAIL: emitted a hardware-stack ,S operand (expected soft-stack RS0 passing)"; rc=1; } || echo "  PASS: no ,S operand — far ptr rides the soft static stack (RS0)"

[ $rc -eq 0 ] || { echo "RESULT: FAIL (negative-control/build/placement/disasm gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (far ptr round-tripped via the soft stack)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "far pointer passed in a 4-byte soft-stack slot (RS0-relative) across real calls (variant d); 24-bit address survived both directions, byte read == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
