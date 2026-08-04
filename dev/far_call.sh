#!/usr/bin/env bash
# dev/far_call.sh — #320 Increment 4: prove a FAR CALL. main (bank $00) calls a
# function placed in bank $01 (the .far_text linker section) via JSL ($22); the far
# function returns via RTL ($6B). Builds examples/65816/far_call.c against the
# snes-far platform with -mcpu=mosw65816 (NO +mos-a16 — far calls are a16-
# independent), asserts the call site emits `jsl` and the far leaf emits `rtl`,
# checks the far function is linked into bank $01 ($018xxx), boots the ROM headless
# in MAME, and verifies the value returned across the bank boundary (0xA9^0x5A=0xF3).
#
# Gate is host-expected == mosw65816 on both emulators (MAME here + bsnes-jg via
# dev/run.sh xcheck).
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_call.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# See docs/plans/2026-06-20-320-inc4-far-calls-and-far-pointer-cc.md (Phase 1).
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_call   # build examples/65816/far_call.c (snes-far), boot in MAME, assert JSL/RTL far call returns 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_call.c"
ROM="$BUILD/far_call.sfc"
MAP="$BUILD/far_call.map"
OBJ="$BUILD/far_call.o"
WANT=0xF3   # seed (0xA9) ^ 0x5A, computed inside the far function and returned via RTL

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
echo "==> disasm gate: the call site is JSL (far call) and the far leaf returns with RTL"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"
"$TOOL/llvm-objdump" -h "$OBJ" >/dev/null 2>&1 \
  || { echo "FAIL: -verify-machineinstrs emitted no real object (vacuous verify)"; exit 1; }
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '\b(jsl|rtl)\b' || true
printf '%s\n' "$DIS" | grep -qiE '\bjsl\b' && echo "  PASS: far call site -> JSL (\$22)" || { echo "  FAIL: no JSL (far call) emitted"; rc=1; }
printf '%s\n' "$DIS" | grep -qiE '\brtl\b' && echo "  PASS: far leaf returns -> RTL (\$6b)" || { echo "  FAIL: no RTL (far return) emitted"; rc=1; }

echo "==> link gate: far_leaf is placed in bank \$01 (\$018000-\$01FFFF)"
FARVMA="$(grep -E '\bfar_leaf\b' "$MAP" | awk '{print $1}' | head -1 || true)"
printf '  far_leaf VMA = 0x%s\n' "${FARVMA:-?}"
if [ -n "${FARVMA:-}" ] && [ "$((16#$FARVMA))" -ge "$((16#18000))" ] && [ "$((16#$FARVMA))" -lt "$((16#20000))" ]; then
  echo "  PASS: far_leaf in bank \$01"
else
  echo "  FAIL: far_leaf not in bank \$01 (VMA 0x${FARVMA:-none})"; rc=1
fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (codegen/link gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (value returned across the bank boundary)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "far call (JSL to bank \$01) + RTL return; value crossed the bank boundary == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
