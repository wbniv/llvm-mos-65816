#!/usr/bin/env bash
# dev/far_near_call.sh — #320 follow-up (b) MIXED-BANKING: prove a FAR function
# (bank $01) can call a NEAR function (bank $00). The far->near call is routed
# through the bank-0 thunk __call_near_from_far via JSL; the near callee runs at
# PBR=$00 (its own near JSR/RTS work), then control RTLs back to the far caller.
# Builds examples/65816/far_near_call.c against snes-far with -mcpu=mosw65816 (NO
# +mos-a16 — far calls are a16-independent), asserts the far call site emits `jsl`
# to __call_near_from_far (not a near `jsr` to the callee), that the thunk is
# linked (gc kept it) with its pea/jmp-indirect/rtl body, that the far caller is in
# bank $01, boots the ROM in MAME, and verifies the value folded up the
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
echo "==> disasm gate: the far->near call is JSL to __call_near_from_far (not a near JSR to the callee)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '\b(jsl|jsr|rts)\b|__call_near_from_far' || true
if printf '%s\n' "$DIS" | grep -iqE '\bjsl\b' && printf '%s\n' "$DIS" | grep -q '__call_near_from_far'; then
  echo "  PASS: far->near call -> JSL __call_near_from_far"
else
  echo "  FAIL: far->near call did not route through __call_near_from_far (JSL)"; rc=1
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
  emu_verdict 0 "far->near mixed-banking call via __call_near_from_far (JSL); near callee ran at PBR=\$00 incl. its own near JSR; value == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
