#!/usr/bin/env bash
# dev/far_tail.sh — #320 far TAIL calls: prove a FAR function (bank $01) that
# tail-calls ANOTHER far function has its `JSL far_x; RTL` block tail folded into a
# single direct long jump `TailJML` (opcode $5C, JMP_AbsoluteLong, sets PBR:PC,
# relocates R_MOS_ADDR24). far_x then runs and its OWN RTL pops the ORIGINAL caller's
# 3-byte JSL return, returning past the intervening far function (tail-call style).
#
# Two shapes in examples/65816/far_tail.c (both .far_text):
#   * far_outer  — minimal single far->far tail; folds jsl(4)+rtl(1)=5 B -> jmp.l(4)=4 B.
#   * far_pick   — a conditional with TWO far-tail blocks tail-calling two leaves that
#     return DISTINCT values; block A is adjacent to block B, so a broken block-A tail
#     jump falls through to block B -> a WRONG corpus_result (execution discriminator).
#
# Gates: (1) -verify-machineinstrs clean (default AND +mos-a16 — the fold is a16-
# independent); (2) disasm: far_outer = one long jmp ($5C+R_MOS_ADDR24, no jsl/rtl),
# far_pick = TWO long jmps (no jsl/rtl), both leaves keep their own rtl; (3) link:
# all far fns in bank $01; (4) execution: corpus_result == 0xCB on MAME (path A =
# far_addk; a broken block-A jump would fall through to far_xork -> 0xE0).
#
# NB on disasm: $5C (JMP_AbsoluteLong) disassembles as a *long* `jmp`, NOT `jml`
# ($DC is the indirect long jump). The $5C tail jump is distinguished from a near
# $4C `jmp` by its R_MOS_ADDR24 reloc (a near jmp carries R_MOS_ADDR16) — the
# R_MOS_ADDR24 + .far_text conjunction is the load-bearing discriminator, not the
# bare `jmp` token.
#
# Gate is host-expected == mosw65816 on both emulators (MAME here + bsnes-jg via
# dev/run.sh xcheck). Runs INSIDE the dev container; drive from the host:
# dev/run.sh far_tail. Prereqs: from-source toolchain + SDK.
# See docs/plans/2026-06-22-320-far-tail-calls.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_tail   # build examples/65816/far_tail.c (snes-far), assert far->far TAIL calls fold to long jmps (\$5C TailJML) and return 0xCB"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_tail.c"
ROM="$BUILD/far_tail.sfc"
MAP="$BUILD/far_tail.map"
OBJ="$BUILD/far_tail.o"
OBJA16="$BUILD/far_tail.a16.o"
WANT=0xCB   # far_pick(1, far_outer(0xA9)) = far_addk(0xA9+0x11=0xBA) = 0xBA+0x11 = 0xCB
            # a broken block-A tail jump falls through to far_xork(0xBA)=0xBA^0x5A=0xE0

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# Extract one function's disasm block: from its <name>: label to the next <...>: label.
fnblock() { awk -v fn="$1" '
  $0 ~ ("^[0-9a-fA-F]+ <" fn ">:") {grab=1; print; next}
  grab && /^[0-9a-fA-F]+ <[^>]*>:/ {exit}
  grab {print}
'; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
echo "==> a16 gate: the fold is accumulator-mode-independent (-verify clean + still \$5C under +mos-a16)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -Xclang -target-feature -Xclang +mos-a16 \
  -mllvm -verify-machineinstrs -c -o "$OBJA16" "$SRC" && echo "  PASS: +mos-a16 compile + -verify-machineinstrs clean" || { echo "  FAIL: +mos-a16 build/verify"; rc=1; }
A16OUTER="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJA16" 2>/dev/null | fnblock far_outer)"
if printf '%s\n' "$A16OUTER" | grep -iqE '\bjmp\b' && printf '%s\n' "$A16OUTER" | grep -q 'R_MOS_ADDR24' \
   && ! printf '%s\n' "$A16OUTER" | grep -iqE '\bjsl\b'; then
  echo "  PASS: far_outer folds to a long jmp (\$5C) under +mos-a16 too (a16-independent)"
else
  echo "  FAIL: far_outer did not fold under +mos-a16"; rc=1
fi

echo "==> disasm gate: far->far tails fold to long jmps (TailJML \$5C+R_MOS_ADDR24), NOT jsl+rtl"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"

# (1) far_outer: exactly one long jmp into .far_text (R_MOS_ADDR24), no jsl, no rtl.
OUTER="$(printf '%s\n' "$DIS" | fnblock far_outer)"
printf '%s\n' "$OUTER" | grep -iE '\b(jmp|jsl|rtl)\b|R_MOS_ADDR24' || true
if printf '%s\n' "$OUTER" | grep -iqE '\bjmp\b' \
   && printf '%s\n' "$OUTER" | grep -q 'R_MOS_ADDR24' \
   && printf '%s\n' "$OUTER" | grep -q '\.far_text' \
   && ! printf '%s\n' "$OUTER" | grep -iqE '\bjsl\b' \
   && ! printf '%s\n' "$OUTER" | grep -iqE '\brtl\b'; then
  echo "  PASS: far_outer = one long jmp into .far_text (TailJML \$5C); no jsl/rtl"
else
  echo "  FAIL: far_outer's single far->far tail not folded"; rc=1
fi

# (2) far_pick: TWO long jmps (both far-tail blocks folded), no jsl, no rtl.
PICK="$(printf '%s\n' "$DIS" | fnblock far_pick)"
NJMP="$(printf '%s\n' "$PICK" | grep -icE '\bjmp\b' || true)"
NADDR24="$(printf '%s\n' "$PICK" | grep -c 'R_MOS_ADDR24' || true)"
printf '  far_pick: long-jmp count=%s  R_MOS_ADDR24 count=%s\n' "$NJMP" "$NADDR24"
if [ "$NJMP" -eq 2 ] && [ "$NADDR24" -eq 2 ] \
   && ! printf '%s\n' "$PICK" | grep -iqE '\bjsl\b' \
   && ! printf '%s\n' "$PICK" | grep -iqE '\brtl\b'; then
  echo "  PASS: far_pick's TWO far-tail blocks both folded to long jmps; no jsl/rtl"
else
  echo "  FAIL: far_pick's two far-tail blocks not both folded (want 2 jmp + 2 R_MOS_ADDR24, no jsl/rtl)"; rc=1
fi

# (3) the leaves are real far leaves — each keeps its OWN rtl.
for leaf in far_addk far_xork; do
  if printf '%s\n' "$DIS" | fnblock "$leaf" | grep -iqE '\brtl\b'; then
    echo "  PASS: $leaf keeps its own rtl"
  else
    echo "  FAIL: $leaf lost its rtl"; rc=1
  fi
done

echo "==> link gate: all far functions are placed in bank \$01 (\$018000-\$01FFFF)"
for fn in far_outer far_pick far_addk far_xork; do
  VMA="$(grep -E "\b$fn\b" "$MAP" | awk '{print $1}' | head -1 || true)"
  printf '  %s VMA = 0x%s\n' "$fn" "${VMA:-?}"
  if [ -n "${VMA:-}" ] && [ "$((16#$VMA))" -ge "$((16#18000))" ] && [ "$((16#$VMA))" -lt "$((16#20000))" ]; then
    echo "  PASS: $fn in bank \$01"
  else
    echo "  FAIL: $fn not in bank \$01 (VMA 0x${VMA:-none})"; rc=1
  fi
done
[ $rc -eq 0 ] || { echo "RESULT: FAIL (codegen/link gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (path A = far_addk; a broken block-A tail jump would fall through to far_xork -> 0xE0)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "far->far tail calls folded to long jmps (TailJML \$5C); far_pick took path A and far_addk's RTL returned past far_pick to main; value == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
