#!/usr/bin/env bash
# dev/k_trig32lut.sh — #321 trig compiler-test, Phase 1c: the libfixmath Q16.16 trig set
# built with the ACCURATE sin LUT (FIXMATH_SIN_LUT) on the HiROM big-ROM platform, so the
# ~200 KiB LUT lives in far rodata (banks $C1+) and is read by 24-bit far loads. This is the
# accurate counterpart of dev/k_trig32.sh (which uses the Taylor sin on the 32 KiB platform).
# examples/65816/k_trig32.c + platforms/snes-hirom. Plan:
# docs/plans/2026-06-25-trig-accurate-sin-lut-hirom.md.
#
# Depends on the clang far-subscript fix (patches/llvm-mos/0001): before it, a far array index
# >= 32768 truncated to 16 bits and mis-addressed the bank (examples/65816/farindex.c).
#
# a16-only (no default leg): a far pointer is a 32-bit value, so the far LUT load needs +mos-a16
# — exactly like the far_* tests. The differential is host == +mos-a16 on MAME + bsnes-jg.
#
#   1. CLEAN + FAR LUT: +mos-a16 -verify clean; the LUT lands in .far_rodata ($C1+); the access
#      uses R_MOS_ADDR24 + `lda [dp]`; no 64-bit __*di3 leak.
#   2. HOST ORACLE: cc -DHOST -DFIXMATH_SIN_LUT reproduces the golden 0x87F0B404 AND every fn is
#      within libm precision — sin/cos/tan now ~1e-5 (vs the Taylor build's ~6e-3/3e-2).
#   3. DIFFERENTIAL: corpus_result == 0x87F0B404 for host == +mos-a16 on MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh k_trig32lut. Prereqs: from-source toolchain
# (with the 0001 clang fix) + SDK built WITH platforms/snes-hirom. bsnes-jg reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh k_trig32lut   # libfixmath Q16.16 trig with the ACCURATE sin LUT in HiROM far rodata: corpus_result==0x87F0B404 host==+mos-a16 (MAME+bsnes-jg)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/k_trig32.c"
LIBFIX="$ROOT/examples/65816/libfixmath"
LIBSRC=("$LIBFIX/fix16.c" "$LIBFIX/fix16_trig.c" "$LIBFIX/fix16_sqrt.c")
LUTASM="$BUILD/fix16_sin_lut_far.s"
AROM="$BUILD/k_trig32lut_a16.sfc"; AMAP="$BUILD/k_trig32lut_a16.map"
OBJ="$BUILD/k_trig32lut.o"
HOSTBIN="$BUILD/k_trig32lut_host"
WANT=0x87F0B404
A16=(-Xclang -target-feature -Xclang +mos-a16)
# Accurate-LUT build: FIXMATH_SIN_LUT selects the LUT sin; TRIG_FAR_LUT puts the LUT in far
# rodata (extern, supplied by the generated asm). Same NO_64BIT/NO_HARD_DIVISION/NO_CACHE contract.
FIX=(-DFIXMATH_SIN_LUT -DFIXMATH_NO_64BIT -DFIXMATH_NO_HARD_DIVISION -DFIXMATH_NO_CACHE -I "$ROOT/examples/65816")
HIROMCFG="$INSTALL/bin/mos-snes-hirom.cfg"
export SMOKE_SETTLE="${SMOKE_SETTLE:-720}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-14}"
JG_FRAMES="${JG_FRAMES:-900}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$HIROMCFG" ] || { echo "FATAL: snes-hirom platform not built (rebuild SDK: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 0) generate the far sin-LUT assembly from the header (host==target identical bytes)"
python3 "$ROOT/tools/gen-sin-lut-asm.py" "$LIBFIX/fix16_trig_sin_lut.h" "$LUTASM"

echo "==> 1) +mos-a16 -verify clean + far LUT (R_MOS_ADDR24 + lda [dp]) + no 64-bit leak"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -DTRIG_FAR_LUT "${FIX[@]}" -Os -mllvm -verify-machineinstrs \
  -c -o "$OBJ" "$LIBFIX/fix16_trig.c" 2>"$BUILD/k_trig32lut.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/k_trig32lut.vlog" | head -3; rc=1; }
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
# here-strings (not `printf ... | grep -q`): under `set -o pipefail`, grep -q exits on the first
# match, SIGPIPEs the upstream printf, and pipefail then reports the (matching!) check as failed.
grep -q 'R_MOS_ADDR24_BANK.*_fix16_sin_lut' <<< "$DIS" \
  && echo "  PASS: LUT accessed via 24-bit far address (R_MOS_ADDR24_BANK _fix16_sin_lut)" \
  || { echo "  FAIL: LUT not far-addressed (the clang far-subscript fix / TRIG_FAR_LUT missing?)"; rc=1; }
grep -qiE '^\s*[0-9a-f]+:\s*a7\b' <<< "$DIS" \
  && echo "  PASS: far load (lda [dp], a7) present" \
  || { echo "  FAIL: no far load opcode"; rc=1; }
leak="$("$TOOL/llvm-nm" "$OBJ" 2>/dev/null | awk '$1=="U"||$2=="U"{print $NF}' | grep -iE 'di3|__(mul|div|mod)di' || true)"
[ -z "$leak" ] && echo "  PASS: no 64-bit libcall" || { echo "  FAIL: 64-bit leak: $leak"; rc=1; }

echo "==> 2) host oracle reproduces the golden ($WANT) + libm accuracy (sin/cos/tan ~1e-5)"
if command -v cc >/dev/null 2>&1; then
  cc -DHOST "${FIX[@]}" -O2 -o "$HOSTBIN" "$SRC" "${LIBSRC[@]}" -lm   # host: inline LUT (no TRIG_FAR_LUT)
  hostval="$("$HOSTBIN" 2>"$BUILD/k_trig32lut.acc")"
  [ "$hostval" = "$WANT" ] \
    && echo "  PASS: host oracle corpus_result=$hostval == golden $WANT" \
    || { echo "  FAIL: host oracle=$hostval != golden $WANT"; rc=1; }
  grep -q '^ACCURACY: PASS' "$BUILD/k_trig32lut.acc" \
    && { echo "  PASS: within libm precision"; sed 's/^/    /' "$BUILD/k_trig32lut.acc"; } \
    || { echo "  FAIL: accuracy breach"; sed 's/^/    /' "$BUILD/k_trig32lut.acc"; rc=1; }
else
  echo "  SKIP: no host cc; trusting documented golden $WANT"
fi

echo "==> 3) build the +mos-a16 HiROM ROM (far LUT) + HiROM checksum"
"$TOOL/mos-clang" --config "$HIROMCFG" -mcpu=mosw65816 "${A16[@]}" -DTRIG_FAR_LUT "${FIX[@]}" -Os \
  -Wl,-Map="$AMAP" -o "$AROM" "$SRC" "${LIBSRC[@]}" "$LUTASM"
python3 "$ROOT/tools/snes-checksum.py" --hirom "$AROM" >/dev/null

echo "==> 4) MAME: host == +mos-a16 (corpus_result == $WANT)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
echo "  +mos-a16:"; run_assert "$AROM" "$AMAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> 5) bsnes-jg: +mos-a16 corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$AMAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$AROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" "$JG_FRAMES" 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> 5) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
emu_verdict "$rc" "libfixmath accurate sin LUT (~200 KiB in HiROM far rodata) — sin/cos/tan ~1e-5 — folds to 0x87F0B404, host == +mos-a16 (both emulators)"
exit $rc
