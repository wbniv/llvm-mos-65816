#!/usr/bin/env bash
# dev/k_trig16.sh — #321 trig compiler-test, Phase 2: 16-bit Q2.14 trig via a FRESH CORDIC
# re-implementation (examples/65816/cordic16.h + generated cordic16_tables.h), headless.
# examples/65816/k_trig16.c. Functions: sin/cos/atan/atan2.
# Plan: docs/plans/2026-06-26-trig-phase2-q214-cordic.md.
#
# The deliberate COMPLEMENT of Phase 1 (k_trig32.c): where Phase 1 ASSERTS the s32 libcall paths
# fire (__mulsi3/__divsi3), Phase 2 ASSERTS the opposite — CORDIC is pure shift-and-add, so under
# +mos-a16 it compiles to native 16-bit code (rep/sep) with ZERO arithmetic libcalls (no __*si3,
# no __*hi3 mul/div/shift). Same differential bar otherwise.
#
# Five assertions:
#   1. CLEAN + PURE-S16 + NO LIBCALL: under +mos-a16 the kernel compiles -verify-machineinstrs
#      clean, native 16-bit is active (rep/sep brackets), and NO arithmetic libcall is emitted
#      (no 64-bit __*di3, no 32-bit __*si3, no 16-bit __*hi3 mul/div/mod/shift).
#   2. HOST ORACLE: the host build (cc -DHOST) reproduces the golden 0x9446C734 AND every function
#      is within a few-LSB CORDIC precision (ACCURACY: PASS) — golden computed, not asserted.
#   3. DIFFERENTIAL: corpus_result == 0x9446C734 for host == default == +mos-a16 on MAME, and
#      +mos-a16 on bsnes-jg (independent second emulator).
#   4. CROSS-WIDTH: tools/trig-accuracy.c agrees Q2.14 CORDIC vs Q16.16 libfixmath within eps16.
#
# Runs INSIDE the dev container; drive: dev/run.sh k_trig16. Prereqs: from-source toolchain + SDK.
# bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh k_trig16   # Q2.14 CORDIC trig (sin/cos/atan/atan2): native 16-bit, NO arithmetic libcall, corpus_result==0x9446C734 host==default==+mos-a16 (MAME+bsnes-jg)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/k_trig16.c"
ACC="$ROOT/tools/trig-accuracy.c"
LIBFIX="$ROOT/examples/65816/libfixmath"
# libfixmath sources the cross-width harness compiles for its Q16.16 reference side (host-only).
LIBSRC=("$LIBFIX/fix16.c" "$LIBFIX/fix16_trig.c" "$LIBFIX/fix16_sqrt.c")
DROM="$BUILD/k_trig16_default.sfc"; DMAP="$BUILD/k_trig16_default.map"
AROM="$BUILD/k_trig16_a16.sfc";     AMAP="$BUILD/k_trig16_a16.map"
HOSTBIN="$BUILD/k_trig16_host"
ACCBIN="$BUILD/trig_accuracy"
WANT=0x9446C734
A16=(-Xclang -target-feature -Xclang +mos-a16)
INC=(-I "$ROOT/examples/65816")
# CORDIC is light (128 shift-add CORDIC calls, no 32-bit mul/div): corpus_result lands within the
# first emulated frames. Settle/backstop are smaller than k_trig32's but keep margin.
export SMOKE_SETTLE="${SMOKE_SETTLE:-300}"     # ticks (~frames) before sampling
export SMOKE_SECONDS="${SMOKE_SECONDS:-8}"     # MAME backstop: 60*8=480 frames > 300
JG_FRAMES="${JG_FRAMES:-420}"                  # bsnes-jg frame count (deterministic)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean + native 16-bit + NO arithmetic libcall"
o="$BUILD/k_trig16.a16.o"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" "${INC[@]}" -Os -mllvm -verify-machineinstrs \
  -c -o "$o" "$SRC" 2>"$BUILD/k_trig16.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/k_trig16.vlog" | head -3; rc=1; }
# NO arithmetic libcall may appear — this is the pure-s16 contract (the inverse of k_trig32).
leak="$("$TOOL/llvm-nm" "$o" 2>/dev/null | awk '$1=="U"||$2=="U"{print $NF}' | grep -iE '__(mul|div|udiv|mod|ashl|ashr|lshr)(hi|si|di)3|di3' || true)"
[ -z "$leak" ] \
  && echo "  PASS: no arithmetic libcall (CORDIC is pure shift-and-add native 16-bit)" \
  || { echo "  FAIL: arithmetic libcall leaked (CORDIC must be libcall-free):"; printf '    %s\n' $leak; rc=1; }
# native 16-bit active under +mos-a16.
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$o")"
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2\b' || true)
[ "$nrep" -ge 8 ] && [ "$nsep" -ge 8 ] \
  && echo "  PASS: native 16-bit active ($nrep rep / $nsep sep brackets)" \
  || { echo "  FAIL: expected >=8 rep and >=8 sep, got $nrep/$nsep"; rc=1; }

echo "==> 2) host oracle reproduces the golden ($WANT) + CORDIC accuracy within precision"
if command -v cc >/dev/null 2>&1; then
  cc -DHOST "${INC[@]}" -O2 -o "$HOSTBIN" "$SRC" -lm
  hostval="$("$HOSTBIN" 2>"$BUILD/k_trig16.acc")"
  [ "$hostval" = "$WANT" ] \
    && echo "  PASS: host oracle corpus_result=$hostval == golden $WANT" \
    || { echo "  FAIL: host oracle=$hostval != golden $WANT (kernel/tables changed — update WANT)"; rc=1; }
  if grep -q '^ACCURACY: PASS' "$BUILD/k_trig16.acc"; then
    echo "  PASS: every function within CORDIC precision"; sed 's/^/    /' "$BUILD/k_trig16.acc"
  else
    echo "  FAIL: accuracy breach"; sed 's/^/    /' "$BUILD/k_trig16.acc"; rc=1
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

echo "==> 6) cross-width accuracy: Q2.14 CORDIC vs Q16.16 libfixmath (host)"
if command -v cc >/dev/null 2>&1; then
  cc "${INC[@]}" -DFIXMATH_NO_64BIT -DFIXMATH_NO_HARD_DIVISION -DFIXMATH_NO_CACHE \
     -O2 -o "$ACCBIN" "$ACC" "${LIBSRC[@]}" -lm 2>"$BUILD/trig_accuracy.log"
  if "$ACCBIN" >"$BUILD/trig_accuracy.out" 2>&1 && grep -q '^CROSS-WIDTH: PASS' "$BUILD/trig_accuracy.out"; then
    echo "  PASS: 16-bit vs 32-bit within eps16"; sed 's/^/    /' "$BUILD/trig_accuracy.out"
  else
    echo "  FAIL: cross-width breach"; sed 's/^/    /' "$BUILD/trig_accuracy.out"; rc=1
  fi
else
  echo "  SKIP: no host cc in container"
fi

echo
emu_verdict "$rc" "Q2.14 CORDIC trig (sin/cos/atan/atan2) compiles native 16-bit with NO arithmetic libcall, folds to 0x9446C734, host == default == +mos-a16 (both emulators)"
exit $rc
