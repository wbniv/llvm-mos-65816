#!/usr/bin/env bash
# dev/k_trig16x.sh — #321 trig compiler-test, Phase 3: the DERIVED 16-bit functions (tan/asin/acos)
# + the HYPERBOLIC functions (sinh/cosh/tanh), all Q2.14 via the Phase 2 CORDIC primitives
# (examples/65816/cordic16.h). examples/65816/k_trig16x.c.
# Plan: docs/plans/2026-06-26-trig-phase3-derived-hyperbolic.md.
#
# Phase 3 completes the trig set across both widths:
#   Phase 1 (k_trig32):  Q16.16 libfixmath           — s32-libcall payload, sin/cos/tan/asin/acos/atan/atan2
#   Phase 2 (k_trig16):  Q2.14 CORDIC direct         — zero-libcall native-s16, sin/cos/atan/atan2
#   Phase 3 (k_trig16x): Q2.14 derived + hyperbolic  — s32-libcall-in-16-bit-context + CORDIC hyperbolic
# The derived functions use a Q2.14 divide/sqrt (so __mulsi3/__divsi3 fire — the 16-bit analogue of
# Phase 1's payload), and sinh/cosh/tanh use CORDIC *hyperbolic* mode (a path neither Phase 1/2 reach).
#
# Five assertions:
#   1. CLEAN + s32 + NO 64-BIT LEAK: under +mos-a16 -verify-machineinstrs clean, native 16-bit active
#      (rep/sep), the s32 mul/div paths fire (__mulsi3/__divsi3 — the derived/hyperbolic payload), and
#      NO 64-bit __*di3 libcall leaks.
#   2. HOST ORACLE: the host build reproduces the golden 0x759567C4 AND every function is within a
#      few-LSB CORDIC precision (ACCURACY: PASS).
#   3. DIFFERENTIAL: corpus_result == 0x759567C4 host == default == +mos-a16 on MAME, and +mos-a16 on
#      bsnes-jg.
#   4. CROSS-WIDTH: tools/trig-accuracy3.c agrees Q2.14 (derived + CORDIC-hyperbolic) vs Q16.16
#      libfixmath (incl. fix16_exp-derived hyperbolic) within eps16.
#
# Runs INSIDE the dev container; drive: dev/run.sh k_trig16x. Prereqs: from-source toolchain + SDK.
set -euo pipefail

usage() { echo "Usage: dev/run.sh k_trig16x   # Q2.14 derived (tan/asin/acos) + hyperbolic (sinh/cosh/tanh) CORDIC: corpus_result==0x759567C4 host==default==+mos-a16 (MAME+bsnes-jg)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/k_trig16x.c"
ACC="$ROOT/tools/trig-accuracy3.c"
LIBFIX="$ROOT/examples/65816/libfixmath"
# libfixmath sources the cross-width harness compiles (host): fix16_exp.c is the Phase-3 add — it
# was vendored but uncompiled until now (the 32-bit hyperbolic reference is derived from exp).
LIBSRC=("$LIBFIX/fix16.c" "$LIBFIX/fix16_trig.c" "$LIBFIX/fix16_sqrt.c" "$LIBFIX/fix16_exp.c")
DROM="$BUILD/k_trig16x_default.sfc"; DMAP="$BUILD/k_trig16x_default.map"
AROM="$BUILD/k_trig16x_a16.sfc";     AMAP="$BUILD/k_trig16x_a16.map"
HOSTBIN="$BUILD/k_trig16x_host"
ACCBIN="$BUILD/trig_accuracy3"
WANT=0x759567C4
A16=(-Xclang -target-feature -Xclang +mos-a16)
INC=(-I "$ROOT/examples/65816")
# Heavier than k_trig16 (s32 mul/div for tan/asin/acos + hyperbolic), lighter than k_trig32.
export SMOKE_SETTLE="${SMOKE_SETTLE:-420}"     # ticks (~frames) before sampling
export SMOKE_SECONDS="${SMOKE_SECONDS:-9}"     # MAME backstop: 60*9=540 frames > 420
JG_FRAMES="${JG_FRAMES:-540}"                  # bsnes-jg frame count (deterministic)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean + native 16-bit + s32 paths + NO 64-bit leak"
o="$BUILD/k_trig16x.a16.o"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" "${INC[@]}" -Os -mllvm -verify-machineinstrs \
  -c -o "$o" "$SRC" 2>"$BUILD/k_trig16x.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/k_trig16x.vlog" | head -3; rc=1; }
# No 64-bit libcall may leak.
leak="$("$TOOL/llvm-nm" "$o" 2>/dev/null | awk '$1=="U"||$2=="U"{print $NF}' | grep -iE 'di3|__(mul|div|mod|ashl|ashr|lshr)di|64' || true)"
[ -z "$leak" ] \
  && echo "  PASS: no 64-bit libcall" \
  || { echo "  FAIL: 64-bit libcall leaked:"; printf '    %s\n' $leak; rc=1; }
# s32 mul/div paths must fire (the derived/hyperbolic payload).
s32="$("$TOOL/llvm-nm" "$o" 2>/dev/null | awk '$1=="U"||$2=="U"{print $NF}' | grep -cE '__(mul|div|udiv|mod)si3' || true)"
[ "$s32" -ge 1 ] \
  && echo "  PASS: 32-bit libcall paths exercised ($s32 distinct __*si3 — derived/hyperbolic payload)" \
  || { echo "  FAIL: expected __*si3 32-bit libcalls, found none"; rc=1; }
# native 16-bit active.
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$o")"
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2\b' || true)
[ "$nrep" -ge 8 ] && [ "$nsep" -ge 8 ] \
  && echo "  PASS: native 16-bit active ($nrep rep / $nsep sep brackets)" \
  || { echo "  FAIL: expected >=8 rep and >=8 sep, got $nrep/$nsep"; rc=1; }

echo "==> 2) host oracle reproduces the golden ($WANT) + CORDIC accuracy within precision"
if command -v cc >/dev/null 2>&1; then
  cc -DHOST "${INC[@]}" -O2 -o "$HOSTBIN" "$SRC" -lm
  hostval="$("$HOSTBIN" 2>"$BUILD/k_trig16x.acc")"
  [ "$hostval" = "$WANT" ] \
    && echo "  PASS: host oracle corpus_result=$hostval == golden $WANT" \
    || { echo "  FAIL: host oracle=$hostval != golden $WANT (kernel/tables changed — update WANT)"; rc=1; }
  if grep -q '^ACCURACY: PASS' "$BUILD/k_trig16x.acc"; then
    echo "  PASS: every function within CORDIC precision"; sed 's/^/    /' "$BUILD/k_trig16x.acc"
  else
    echo "  FAIL: accuracy breach"; sed 's/^/    /' "$BUILD/k_trig16x.acc"; rc=1
  fi
else
  echo "  SKIP: no host cc in container; trusting documented golden $WANT"
fi

echo "==> 3) build default + +mos-a16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816          "${INC[@]}" -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" "${INC[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC"
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

echo "==> 6) cross-width accuracy: Q2.14 derived+hyperbolic vs Q16.16 libfixmath (host)"
if command -v cc >/dev/null 2>&1; then
  cc "${INC[@]}" -DFIXMATH_NO_64BIT -DFIXMATH_NO_HARD_DIVISION -DFIXMATH_NO_CACHE \
     -O2 -o "$ACCBIN" "$ACC" "${LIBSRC[@]}" -lm 2>"$BUILD/trig_accuracy3.log"
  if "$ACCBIN" >"$BUILD/trig_accuracy3.out" 2>&1 && grep -q '^CROSS-WIDTH: PASS' "$BUILD/trig_accuracy3.out"; then
    echo "  PASS: 16-bit vs 32-bit within eps16"; sed 's/^/    /' "$BUILD/trig_accuracy3.out"
  else
    echo "  FAIL: cross-width breach"; sed 's/^/    /' "$BUILD/trig_accuracy3.out"; rc=1
  fi
else
  echo "  SKIP: no host cc in container"
fi

echo
emu_verdict "$rc" "Q2.14 derived (tan/asin/acos) + hyperbolic (sinh/cosh/tanh) CORDIC compiles clean (s32 paths, no 64-bit leak), folds to 0x759567C4, host == default == +mos-a16 (both emulators)"
exit $rc
