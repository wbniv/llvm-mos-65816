#!/usr/bin/env bash
# dev/k_hopalong.sh — #321 realistic kernel: Barry Martin's "Hopalong" attractor in
# Q8.8 fixed point (the math heart of Blossom), headless. examples/65816/k_hopalong.c.
# Phase 1 of the SNES Blossom port; the on-screen Mode-7 renderer is TODO (#3).
# Plan: docs/plans/2026-06-24-blossom-snes.md.
#
# Three assertions:
#   1. CLEAN+NATIVE: under +mos-a16 the orbit compiles -verify-machineinstrs clean and
#      runs native 16-bit (rep/sep brackets present) — not a fully byte-wise expansion.
#   2. HOST ORACLE: the host build (cc -DHOST) reproduces the documented golden 0x1BBC,
#      so the golden is computed, not asserted by fiat.
#   3. DIFFERENTIAL: corpus_result == 0x1BBC for host == default == +mos-a16 on MAME,
#      and +mos-a16 on bsnes-jg (independent second emulator).
#
# Runs INSIDE the dev container; drive: dev/run.sh k_hopalong. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh k_hopalong   # Hopalong attractor (Blossom) Q8.8 kernel: native 16-bit, corpus_result==0x1BBC host==default==+mos-a16 (MAME+bsnes-jg)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/k_hopalong.c"
DROM="$BUILD/k_hopalong_default.sfc"; DMAP="$BUILD/k_hopalong_default.map"
AROM="$BUILD/k_hopalong_a16.sfc";     AMAP="$BUILD/k_hopalong_a16.map"
OBJ="$BUILD/k_hopalong.o"
HOSTBIN="$BUILD/k_hopalong_host"
WANT=0x1BBC
A16=(-Xclang -target-feature -Xclang +mos-a16)
# The orbit is a real 1024-iteration loop (heavier than the single-shot corpus tests),
# so give MAME's sampler headroom before it reads corpus_result (still < the 3 s backstop).
export SMOKE_SETTLE="${SMOKE_SETTLE:-120}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean + NATIVE 16-bit orbit (rep/sep brackets)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/k_hopalong.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/k_hopalong.vlog" | head -3; rc=1; }
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2\b' || true)   # rep #imm (enter 16-bit)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2\b' || true)   # sep #imm (leave 16-bit)
[ "$nrep" -ge 4 ] && [ "$nsep" -ge 4 ] \
  && echo "  PASS: native 16-bit active ($nrep rep / $nsep sep brackets on the orbit arithmetic)" \
  || { echo "  FAIL: expected >=4 rep and >=4 sep, got $nrep/$nsep (orbit not going native 16-bit)"; rc=1; }

echo "==> 2) host oracle reproduces the golden ($WANT)"
if command -v cc >/dev/null 2>&1; then
  cc -DHOST -O2 -o "$HOSTBIN" "$SRC"
  hostval="$("$HOSTBIN")"
  [ "$hostval" = "$WANT" ] \
    && echo "  PASS: host oracle corpus_result=$hostval == golden $WANT" \
    || { echo "  FAIL: host oracle=$hostval != golden $WANT (kernel changed — update WANT)"; rc=1; }
else
  echo "  SKIP: no host cc in container; trusting documented golden $WANT"
fi

echo "==> 3) build default + +mos-a16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816          -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC"
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
  if line="$("$BUILD/jgxcheck" "$AROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> 5) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
emu_verdict "$rc" "Hopalong (Blossom) Q8.8 attractor runs native 16-bit and folds to 0x1BBC, host == default == +mos-a16 (both emulators)"
exit $rc
