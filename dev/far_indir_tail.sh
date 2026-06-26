#!/usr/bin/env bash
# dev/far_indir_tail.sh — #320 Phase B FAR-INDIRECT TAIL CALL: prove a far function's
# tail that is an INDIRECT far call (`return far_leaf(x)` where far_leaf is `far`) folds
# to a single long jmp. far_outer (.far_text) tail-calls far_leaf via the far-indirect
# sequence, so far_outer's block tail is `JSL __call_indir_far; RTL`; the IndirFarThunk
# arm of MOSLateOptimization::tailJMP folds it to `TailJML __call_indir_far` ($5C long
# jump, R_MOS_ADDR24). The thunk `jml (__mos_far_target)`s to far_leaf, whose RTL pops
# main's 3-byte return — control returns straight to main (tail-call style). Builds
# examples/65816/far_indir_tail.c against snes-far with -mcpu=mosw65816 AND +mos-a16,
# asserts the fold fired (long jmp to __call_indir_far, no jsl/rtl in far_outer), that
# the thunk + both far functions are in bank $01, boots in MAME, and checks
# far_outer(0x5A) -> far_leaf -> 0xFF.
#
# Needs the __call_indir_far runtime stub (platforms/snes/call-indir-far.s). Gate is
# host-expected == +mos-a16 on both emulators (MAME here + bsnes-jg via dev/run.sh xcheck).
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_indir_tail.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# See docs/plans/2026-06-26-320-thunk-tail-calls.md (Phase B).
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_indir_tail   # build examples/65816/far_indir_tail.c (snes-far, +mos-a16), boot in MAME, assert a far-indirect TAIL call folds to a long jmp to __call_indir_far and returns 0xFF"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_indir_tail.c"
ROM="$BUILD/far_indir_tail.sfc"
MAP="$BUILD/far_indir_tail.map"
OBJ="$BUILD/far_indir_tail.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0xFF   # far_outer(0x5A) -> far_leaf(0x5A) = 0x5A ^ 0xA5 = 0xFF

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
echo "==> disasm gate: far_outer's far-indirect TAIL folds to a long jmp __call_indir_far (TailJML \$5C), not jsl+rtl"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
# Isolate far_outer's block (its only call — the tail `return far_leaf(x)`).
OUTER="$(printf '%s\n' "$DIS" | awk '
  /^[0-9a-fA-F]+ <far_outer>:/ {grab=1; print; next}
  grab && /^[0-9a-fA-F]+ <[^>]*>:/ {exit}
  grab {print}
')"
printf '%s\n' "$OUTER" | grep -iE '\b(jsl|jmp|rtl)\b|__call_indir_far|__mos_far_target|R_MOS_ADDR24' || true
# The fold: far_outer's `JSL __call_indir_far; RTL` -> a long jmp ($5C, R_MOS_ADDR24) to
# the thunk; no jsl/rtl survive in far_outer. (A near $4C/R_MOS_ADDR16, or a leftover
# jsl __call_indir_far / rtl = FAIL.) far_outer still STASHES into __mos_far_target before
# the tail (that store is not the tail and is unaffected).
# far_outer's tail must be a single long jmp ($5C) to __call_indir_far (R_MOS_ADDR24),
# with NO jsl and NO rtl surviving. The `jmp __call_indir_far` line is the fold; the
# preceding stash stores (to __mos_far_target) are not the tail and are unaffected.
if printf '%s\n' "$OUTER" | grep -B1 'R_MOS_ADDR24[[:space:]]*__call_indir_far' | grep -iqE '\bjmp\b' \
   && ! printf '%s\n' "$OUTER" | grep -iqE '\bjsl\b' \
   && ! printf '%s\n' "$OUTER" | grep -iqE '\brtl\b'; then
  echo "  PASS: far_outer's far-indirect tail folded to a long jmp __call_indir_far (\$5C, R_MOS_ADDR24); no jsl/rtl"
else
  echo "  FAIL: far-indirect thunk tail did not fold (expected long jmp __call_indir_far + R_MOS_ADDR24, no jsl/rtl)"; rc=1
fi
# far_leaf still returns via its own RTL (only far_outer's tail folded).
LEAF="$(printf '%s\n' "$DIS" | awk '
  /^[0-9a-fA-F]+ <far_leaf>:/ {grab=1; print; next}
  grab && /^[0-9a-fA-F]+ <[^>]*>:/ {exit}
  grab {print}
')"
if printf '%s\n' "$LEAF" | grep -iqE '\brtl\b'; then
  echo "  PASS: far_leaf keeps its own rtl"
else
  echo "  FAIL: far_leaf lost its rtl"; rc=1
fi

echo "==> thunk gate: __call_indir_far is linked (gc kept it) with a jml-indirect body"
if grep -qE '\b__call_indir_far\b' "$MAP"; then
  echo "  PASS: __call_indir_far linked into the ROM"
else
  echo "  FAIL: __call_indir_far not in the link (gc dropped a referenced symbol?)"; rc=1
fi

echo "==> link gate: far_outer + far_leaf are placed in bank \$01 (\$018000-\$01FFFF)"
for sym in far_outer far_leaf; do
  VMA="$(grep -E "\b$sym\b" "$MAP" | awk '{print $1}' | head -1 || true)"
  printf '  %s VMA = 0x%s\n' "$sym" "${VMA:-?}"
  if [ -n "${VMA:-}" ] && [ "$((16#$VMA))" -ge "$((16#18000))" ] && [ "$((16#$VMA))" -lt "$((16#20000))" ]; then
    echo "  PASS: $sym in bank \$01"
  else
    echo "  FAIL: $sym not in bank \$01 (VMA 0x${VMA:-none})"; rc=1
  fi
done
[ $rc -eq 0 ] || { echo "RESULT: FAIL (codegen/link gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (folded far-indirect tail returned far_leaf's value to main)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "far-indirect TAIL call folded to a long jmp __call_indir_far (TailJML \$5C); thunk jml'd to far_leaf in bank \$01, whose RTL returned past far_outer to main; value == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
