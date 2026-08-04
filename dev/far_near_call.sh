#!/usr/bin/env bash
# dev/far_near_call.sh — #320 follow-up (b) MIXED-BANKING: prove a FAR function
# (bank $01) can call a NEAR function (bank $00). The far->near call is routed
# through the bank-0 thunk __call_near_from_far via JSL; the near callee runs at
# PBR=$00 (its own near JSR/RTS work), then control RTLs back to the far caller.
# Builds examples/65816/far_near_call.c against snes-far with -mcpu=mosw65816 (NO
# +mos-a16 — far calls are a16-independent). far_caller's tail `return near_helper(x)`
# is a `JSL __call_near_from_far; RTL` adjacency, so the #320 far-tail peephole folds
# it to a single long jmp ($5C TailJML, R_MOS_ADDR24) to the thunk — the thunk's own
# RTL then returns past far_caller (tail-call style). Asserts that fold fired, that the
# thunk is linked (gc kept it) with its pea/jmp-indirect/rtl body, that the far caller
# is in bank $01, boots the ROM in MAME, and verifies the value folded up the
# main->far->near->near chain (0xA9+0x11=0xBA, 0xBA^0x5A=0xE0).
#
# Gate is host-expected == mosw65816 on both emulators (MAME here + bsnes-jg via
# dev/run.sh xcheck).
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_near_call.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# See docs/plans/2026-06-21-320-far-calls-followups.md (b).
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_near_call   # build examples/65816/far_near_call.c (snes-far), boot in MAME, assert a far->near call via __call_near_from_far returns 0xE0"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_near_call.c"
ROM="$BUILD/far_near_call.sfc"
MAP="$BUILD/far_near_call.map"
OBJ="$BUILD/far_near_call.o"
WANT=0xE0   # 0xA9 + 0x11 = 0xBA (near_inner); 0xBA ^ 0x5A = 0xE0 (near_helper)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
echo "==> disasm gate: the far->near TAIL call folds to a long jmp to __call_near_from_far (TailJML \$5C), not jsl+rtl"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"
"$TOOL/llvm-objdump" -h "$OBJ" >/dev/null 2>&1 \
  || { echo "FAIL: -verify-machineinstrs emitted no real object (vacuous verify)"; exit 1; }
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
# Isolate far_caller's block (its only call — the tail `return near_helper(x)`).
CALLER="$(printf '%s\n' "$DIS" | awk '
  /^[0-9a-fA-F]+ <far_caller>:/ {grab=1; print; next}
  grab && /^[0-9a-fA-F]+ <[^>]*>:/ {exit}
  grab {print}
')"
printf '%s\n' "$CALLER" | grep -iE '\b(jsl|jmp|rtl|rts)\b|__call_near_from_far|R_MOS_ADDR24' || true
# POSITIVE gate (#320 far tail calls, thunk-tail extension): far_caller's
# `JSL __call_near_from_far; RTL` now folds to a single long jmp ($5C TailJML,
# R_MOS_ADDR24) to the bank-0 thunk — the thunk's own RTL pops far_caller's caller's
# 3-byte return, so control returns PAST far_caller (tail-call style). The far-tail arm of
# MOSLateOptimization::tailJMP matches the __call_near_from_far external symbol by name.
# Distinguish the $5C long jmp from a near $4C jmp by the R_MOS_ADDR24 reloc; assert NO
# jsl/rtl survive in far_caller. (A near $4C / R_MOS_ADDR16 or a leftover jsl/rtl = FAIL.)
if printf '%s\n' "$CALLER" | grep -iqE '\bjmp\b' \
   && printf '%s\n' "$CALLER" | grep -q '__call_near_from_far' \
   && printf '%s\n' "$CALLER" | grep -q 'R_MOS_ADDR24' \
   && ! printf '%s\n' "$CALLER" | grep -iqE '\bjsl\b' \
   && ! printf '%s\n' "$CALLER" | grep -iqE '\brtl\b'; then
  echo "  PASS: far_caller's far->near tail folded to a long jmp __call_near_from_far (\$5C, R_MOS_ADDR24); no jsl/rtl"
else
  echo "  FAIL: far->near thunk tail did not fold (expected long jmp + R_MOS_ADDR24, no jsl/rtl)"; rc=1
fi
# The near helpers must still use a near JSR/RTS (they run at PBR=$00, unchanged).
printf '%s\n' "$DIS" | grep -qiE '\brts\b' && echo "  PASS: near helper still returns via RTS" || { echo "  FAIL: near helper lost its RTS"; rc=1; }

echo "==> thunk gate: __call_near_from_far is linked (gc kept it) with pea/jmp-indirect/rtl body"
CRT0="$(find "$INSTALL" -name crt0.o -path '*snes*' 2>/dev/null | head -1 || true)"
if [ -n "$CRT0" ]; then
  TDIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$CRT0" 2>/dev/null)"
  printf '%s\n' "$TDIS" | awk '/__call_near_from_far/{p=1} p{print} p&&/rtl/{exit}' | grep -iE 'pea|jmp|rtl' || true
  if printf '%s\n' "$TDIS" | awk '/__call_near_from_far/{p=1} p&&/pea/{a=1} p&&/jmp/{b=1} p&&/rtl/{c=1} END{exit !(a&&b&&c)}'; then
    echo "  PASS: thunk body = pea + jmp(ind) + rtl"
  else
    echo "  WARN: could not confirm thunk body shape in $CRT0 (execution gate still authoritative)"
  fi
fi
if grep -qE '\b__call_near_from_far\b' "$MAP"; then
  echo "  PASS: __call_near_from_far linked into the ROM"
else
  echo "  FAIL: __call_near_from_far not in the link (gc dropped a referenced symbol?)"; rc=1
fi

echo "==> link gate: far_caller is placed in bank \$01 (\$018000-\$01FFFF)"
FARVMA="$(grep -E '\bfar_caller\b' "$MAP" | awk '{print $1}' | head -1 || true)"
printf '  far_caller VMA = 0x%s\n' "${FARVMA:-?}"
if [ -n "${FARVMA:-}" ] && [ "$((16#$FARVMA))" -ge "$((16#18000))" ] && [ "$((16#$FARVMA))" -lt "$((16#20000))" ]; then
  echo "  PASS: far_caller in bank \$01"
else
  echo "  FAIL: far_caller not in bank \$01 (VMA 0x${FARVMA:-none})"; rc=1
fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (codegen/link gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (value folded up main->far->near->near)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "far->near mixed-banking TAIL call folded to a long jmp __call_near_from_far (TailJML \$5C); thunk ran the near callee at PBR=\$00 incl. its own near JSR, then RTL'd past far_caller; value == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
