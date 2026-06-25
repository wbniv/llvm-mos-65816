#!/usr/bin/env bash
# dev/k_trig32.sh — #321 trig compiler-test, Phase 1: the full fixed-point trig set in
# Q16.16 via the VENDORED libfixmath reference (examples/65816/libfixmath/, MIT, upstream
# 9318ccd), headless. examples/65816/k_trig32.c. Functions: sin/cos/tan/asin/acos/atan/atan2.
# Plan: docs/plans/2026-06-25-trig-functions-as-a-c-compiler-differential-test-1.md.
#
# Four assertions:
#   1. CLEAN + s32 + NO 64-BIT LEAK: under +mos-a16 every source (kernel + libfixmath) compiles
#      -verify-machineinstrs clean, the 32-bit libcall paths fire (__mulsi3/__divsi3/__udivsi3),
#      native 16-bit is active (rep/sep brackets), and NO 64-bit __*di3 libcall leaks (the
#      build contract -DFIXMATH_NO_64BIT -DFIXMATH_NO_HARD_DIVISION must hold on the target).
#   2. HOST ORACLE: the host build (cc -DHOST, same FIXMATH flags) reproduces the golden
#      0x068A6933 AND every function is within libm precision (ACCURACY: PASS) — golden computed,
#      not asserted by fiat.
#   3. DIFFERENTIAL: corpus_result == 0x068A6933 for host == default == +mos-a16 on MAME,
#      and +mos-a16 on bsnes-jg (independent second emulator).
#
# Runs INSIDE the dev container; drive: dev/run.sh k_trig32. Prereqs: from-source toolchain +
# SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh k_trig32   # libfixmath Q16.16 trig (sin/cos/tan/asin/acos/atan/atan2): s32 codegen, no 64-bit leak, corpus_result==0x068A6933 host==default==+mos-a16 (MAME+bsnes-jg)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/k_trig32.c"
LIBFIX="$ROOT/examples/65816/libfixmath"
# libfixmath translation units Phase 1 compiles (fix16_exp.c is vendored but Phase-3-only).
LIBSRC=("$LIBFIX/fix16.c" "$LIBFIX/fix16_trig.c" "$LIBFIX/fix16_sqrt.c")
DROM="$BUILD/k_trig32_default.sfc"; DMAP="$BUILD/k_trig32_default.map"
AROM="$BUILD/k_trig32_a16.sfc";     AMAP="$BUILD/k_trig32_a16.map"
HOSTBIN="$BUILD/k_trig32_host"
WANT=0x068A6933
A16=(-Xclang -target-feature -Xclang +mos-a16)
# libfixmath build contract — MUST be identical on host and target (else the differential
# fails for the wrong reason): 32-bit-only mul/div, no mutable cache. See the plan / kernel header.
FIX=(-DFIXMATH_NO_64BIT -DFIXMATH_NO_HARD_DIVISION -DFIXMATH_NO_CACHE -I "$ROOT/examples/65816")
# The sweep runs 32 samples x 7 trig functions of real libfixmath math (Taylor sin, restoring
# division, bit-by-bit sqrt). On the FPU-less, divide-less 65816 the software 32-bit mul/div make
# this the heaviest kernel yet: main() takes ~600 emulated frames (~10 s) to store corpus_result
# (measured via build/jgxcheck). So the sampler must wait well past that AND MAME's backstop must
# exceed the wait (-seconds_to_run S caps the run at ~60*S frames) — see dev/_emu.sh SMOKE_SECONDS.
export SMOKE_SETTLE="${SMOKE_SETTLE:-720}"     # ticks (~frames) before sampling; > ~600 with margin
export SMOKE_SECONDS="${SMOKE_SECONDS:-14}"    # MAME backstop in emu-seconds: 60*14=840 frames > 720
JG_FRAMES="${JG_FRAMES:-900}"                  # bsnes-jg frame count (deterministic; > ~600 with margin)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean + s32 codegen + native 16-bit + NO 64-bit leak"
OBJS=()
for f in "$SRC" "${LIBSRC[@]}"; do
  o="$BUILD/$(basename "${f%.c}").a16.o"; OBJS+=("$o")
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" "${FIX[@]}" -Os -mllvm -verify-machineinstrs \
    -c -o "$o" "$f" 2>"$BUILD/$(basename "${f%.c}").vlog" \
    || { echo "  FAIL: verify-machineinstrs on $(basename "$f")"; grep -iE "error|Bad machine" "$BUILD/$(basename "${f%.c}").vlog" | head -3; rc=1; }
done
# No 64-bit libcall may leak (di3 = the libgcc/compiler-rt 64-bit helpers).
leak="$("$TOOL/llvm-nm" "${OBJS[@]}" 2>/dev/null | awk '$1=="U"||$2=="U"{print $NF}' | grep -iE 'di3|__(mul|div|mod|ashl|ashr|lshr)di|64' || true)"
[ -z "$leak" ] \
  && echo "  PASS: no 64-bit libcall (FIXMATH_NO_64BIT/NO_HARD_DIVISION held on target)" \
  || { echo "  FAIL: 64-bit libcall leaked:"; printf '    %s\n' $leak; rc=1; }
# s32 paths must actually fire (this is a 32-bit-math kernel).
s32="$("$TOOL/llvm-nm" "${OBJS[@]}" 2>/dev/null | awk '$1=="U"||$2=="U"{print $NF}' | grep -cE '__(mul|div|udiv|mod)si3' || true)"
[ "$s32" -ge 1 ] \
  && echo "  PASS: 32-bit libcall paths exercised ($s32 distinct __*si3)" \
  || { echo "  FAIL: expected __*si3 32-bit libcalls, found none"; rc=1; }
# native 16-bit active under +mos-a16.
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "${OBJS[@]}")"
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2\b' || true)
[ "$nrep" -ge 4 ] && [ "$nsep" -ge 4 ] \
  && echo "  PASS: native 16-bit active ($nrep rep / $nsep sep brackets)" \
  || { echo "  FAIL: expected >=4 rep and >=4 sep, got $nrep/$nsep"; rc=1; }

echo "==> 2) host oracle reproduces the golden ($WANT) + libm accuracy within precision"
if command -v cc >/dev/null 2>&1; then
  cc -DHOST "${FIX[@]}" -O2 -o "$HOSTBIN" "$SRC" "${LIBSRC[@]}" -lm
  hostval="$("$HOSTBIN" 2>"$BUILD/k_trig32.acc")"
  [ "$hostval" = "$WANT" ] \
    && echo "  PASS: host oracle corpus_result=$hostval == golden $WANT" \
    || { echo "  FAIL: host oracle=$hostval != golden $WANT (kernel/library changed — update WANT)"; rc=1; }
  if grep -q '^ACCURACY: PASS' "$BUILD/k_trig32.acc"; then
    echo "  PASS: every function within libm precision"; sed 's/^/    /' "$BUILD/k_trig32.acc"
  else
    echo "  FAIL: accuracy breach"; sed 's/^/    /' "$BUILD/k_trig32.acc"; rc=1
  fi
else
  echo "  SKIP: no host cc in container; trusting documented golden $WANT"
fi

echo "==> 3) build default + +mos-a16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816          "${FIX[@]}" -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC" "${LIBSRC[@]}"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" "${FIX[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC" "${LIBSRC[@]}"
python3 "$ROOT/tools/snes-checksum.py" "$DROM" >/dev/null
python3 "$ROOT/tools/snes-checksum.py" "$AROM" >/dev/null

echo "==> 4) MAME: host == default == +mos-a16 (corpus_result == $WANT)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
echo "  default:";  run_assert "$DROM" "$DMAP" corpus_result "$WANT" || rc=1
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
emu_verdict "$rc" "libfixmath Q16.16 trig (7 fns) compiles clean with s32 codegen and no 64-bit leak, folds to 0x068A6933, host == default == +mos-a16 (both emulators)"
exit $rc
