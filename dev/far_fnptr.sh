#!/usr/bin/env bash
# dev/far_fnptr.sh — #320 follow-up (a) FAR FUNCTION POINTERS: prove an INDIRECT
# call through a far (24-bit) code pointer. A .far_text function (bank $01) has its
# full 24-bit address taken as a far (addrspace 2) value — the bank byte via
# R_MOS_ADDR24_BANK (#mos24bank) — stashed into __mos_far_target, and called by a
# JSL to __call_indir_far which `jml (__mos_far_target)`s (long-indirect, $DC) to
# it; the far target's RTL returns to the original call site. Builds
# examples/65816/far_fnptr.c against snes-far with -mcpu=mosw65816 AND +mos-a16 (a
# far pointer is a 32-bit value; 32-bit value legalization is a16-gated, as in
# far_cast/far_indir), asserts the call site is a JSL to __call_indir_far, the
# 24-bit target materialization carries a bank (#mos24bank) reloc, far_leaf returns
# via RTL and is placed in bank $01, boots the ROM in MAME, and verifies
# far_leaf(0x5A) == 0xFF round-trips through the whole mechanism.
#
# The __call_indir_far + __mos_far_target runtime stub lives in
# platforms/snes/call-indir-far.s (gc-sectioned, pulled only by the JSL here).
# Until that stub landed, this call failed to link (undefined __call_indir_far) —
# see docs/plans/2026-06-26-320-thunk-tail-calls.md (Phase B).
#
# Gate is host-expected == +mos-a16 on both emulators (MAME here + bsnes-jg via
# dev/run.sh xcheck); there is no default leg (the 8-bit build can't decompose a
# 32-bit far-pointer value).
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_fnptr.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_fnptr   # build examples/65816/far_fnptr.c (snes-far, +mos-a16), boot in MAME, assert a far indirect call via __call_indir_far returns 0xFF"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_fnptr.c"
ROM="$BUILD/far_fnptr.sfc"
MAP="$BUILD/far_fnptr.map"
OBJ="$BUILD/far_fnptr.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0xFF   # far_leaf(0x5A) = 0x5A ^ 0xA5 = 0xFF (the value crossed the bank via the far indirect call)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
echo "==> disasm gate: call site is JSL __call_indir_far; 24-bit target carries a bank reloc; far_leaf RTLs"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"
"$TOOL/llvm-objdump" -h "$OBJ" >/dev/null 2>&1 \
  || { echo "FAIL: -verify-machineinstrs emitted no real object (vacuous verify)"; exit 1; }
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '\bjsl\b|__call_indir_far|ADDR24_BANK|mos24bank|\brtl\b' || true
if printf '%s\n' "$DIS" | grep -iqE '\bjsl\b' && printf '%s\n' "$DIS" | grep -q '__call_indir_far'; then
  echo "  PASS: far indirect call -> JSL __call_indir_far"
else
  echo "  FAIL: call did not route through __call_indir_far (JSL)"; rc=1
fi
if printf '%s\n' "$DIS" | grep -qiE 'ADDR24_BANK|mos24bank'; then
  echo "  PASS: 24-bit target materialization carries a bank (R_MOS_ADDR24_BANK) reloc"
else
  echo "  FAIL: no bank reloc on the far target (address-of dropped the bank?)"; rc=1
fi
if printf '%s\n' "$DIS" | grep -qiE '\brtl\b'; then
  echo "  PASS: far_leaf returns via RTL"
else
  echo "  FAIL: far_leaf did not return via RTL"; rc=1
fi

echo "==> thunk gate: __call_indir_far is linked (gc kept it) with a jml-indirect body"
CRT0="$(find "$INSTALL" -name crt0.o -path '*snes*' 2>/dev/null | head -1 || true)"
if [ -n "$CRT0" ]; then
  TDIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$CRT0" 2>/dev/null)"
  printf '%s\n' "$TDIS" | awk '/__call_indir_far/{p=1} p{print} p&&/jml/{exit}' | grep -iE 'jml' || true
  if printf '%s\n' "$TDIS" | awk '/__call_indir_far/{p=1} p&&/jml/{j=1} END{exit !j}'; then
    echo "  PASS: thunk body = jml (indirect-long)"
  else
    echo "  WARN: could not confirm thunk body shape in $CRT0 (execution gate still authoritative)"
  fi
fi
if grep -qE '\b__call_indir_far\b' "$MAP"; then
  echo "  PASS: __call_indir_far linked into the ROM"
else
  echo "  FAIL: __call_indir_far not in the link (gc dropped a referenced symbol?)"; rc=1
fi

echo "==> link gate: far_leaf is placed in bank \$01 (\$018000-\$01FFFF)"
FARVMA="$(grep -E '\bfar_leaf\b' "$MAP" | awk '{print $1}' | head -1 || true)"
printf '  far_leaf VMA = 0x%s\n' "${FARVMA:-?}"
if [ -n "${FARVMA:-}" ] && [ "$((16#$FARVMA))" -ge "$((16#18000))" ] && [ "$((16#$FARVMA))" -lt "$((16#20000))" ]; then
  echo "  PASS: far_leaf in bank \$01"
else
  echo "  FAIL: far_leaf not in bank \$01 (VMA 0x${FARVMA:-none})"; rc=1
fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (codegen/link gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (value crossed the bank via the far indirect call)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "far indirect call through a 24-bit code pointer via __call_indir_far (JSL -> jml (__mos_far_target)); far_leaf ran in bank \$01 and RTL'd back; value == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
