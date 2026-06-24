#!/usr/bin/env bash
# dev/a16s32.sh — #321 32-bit `long`/`int32_t` value differential.
# examples/65816/a16s32.c folds every s32 hazard (2x s16 carry add/sub, 4x s8<->s32
# (un)merge, const/arith shifts, __mulsi3 / __udivsi3 / __umodsi3 libcalls, s16->s32
# ext, s32 compare-as-value) into a 32-bit corpus_result. Full 4-way differential:
#   host == default@MAME == +mos-a16@MAME == +mos-a16@bsnes-jg
# (s32 has a DEFAULT leg — `long` works in the 8-bit build too — so this is stronger
# than the a16-only far tests). Three assertions:
#   1. both default + +mos-a16 are -verify-machineinstrs clean.
#   2. the a16 build routes s32 through the real machinery (libcalls + rep/sep
#      bracket present) — i.e. the value wasn't constant-folded away.
#   3. corpus_result == WANT on both emulators, both builds.
#
# WANT is the host-oracle value of the IDENTICAL uint32_t arithmetic (uint32_t is
# 32-bit on host and target), reproducible with:  cc -DHOST_ORACLE a16s32.c && ./a.out
# Baked below; if a host `cc` is present the script recomputes + asserts no drift.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16s32. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# Plan: docs/plans/2026-06-23-321-32bit-long-verification.md
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16s32   # 32-bit long/int32_t value differential: host==default==+mos-a16 (both emulators), s32 routed through 2x s16 + libcalls"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16s32.c"
DROM="$BUILD/a16s32_default.sfc"; DMAP="$BUILD/a16s32_default.map"
AROM="$BUILD/a16s32_a16.sfc";     AMAP="$BUILD/a16s32_a16.map"
OBJ="$BUILD/a16s32.o"
WANT=0x50F2B870   # host-oracle value of the uint32_t arithmetic in compute() (see header)
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

# Drift guard: if a host C compiler exists, recompute WANT from the SAME source and
# assert it matches the baked constant (catches an edit to compute() that forgot to
# update WANT). Skipped silently when no host cc is available.
if command -v cc >/dev/null 2>&1; then
  if cc -O2 -DHOST_ORACLE -o "$BUILD/a16s32_host" "$SRC" 2>/dev/null; then
    HV="$("$BUILD/a16s32_host")"
    if [ "$((HV))" -eq "$((WANT))" ]; then echo "==> host-oracle cross-check: WANT=$WANT confirmed ($HV)"; \
    else echo "  FAIL: baked WANT=$WANT != host-oracle $HV (compute() changed — update WANT)"; rc=1; fi
  fi
fi

echo "==> 1) build default + +mos-a16, -verify-machineinstrs clean"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816          -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/a16s32.dvlog" \
  || { echo "  FAIL: default verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/a16s32.dvlog" | head -3; rc=1; }
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -S -o "$BUILD/a16s32.s" "$SRC" 2>"$BUILD/a16s32.avlog" \
  || { echo "  FAIL: +mos-a16 verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/a16s32.avlog" | head -3; rc=1; }
[ $rc -eq 0 ] && echo "  PASS: both builds -verify-machineinstrs clean"

echo "==> 2) a16 disasm: s32 routed through the real machinery (libcalls + rep/sep bracket), not folded"
SS="$BUILD/a16s32.s"
for sym in __mulsi3 __udivsi3 __umodsi3; do
  if grep -qiE "\b$sym\b" "$SS"; then echo "  PASS: $sym libcall present"; else echo "  FAIL: $sym libcall missing (s32 op folded away?)"; rc=1; fi
done
nrep=$(grep -ciE '\brep\b' "$SS" || true)
[ "$nrep" -ge 1 ] && echo "  PASS: $nrep rep (16-bit-accumulator brackets — s32 went native-16 under a16)" || { echo "  FAIL: no rep bracket"; rc=1; }

echo "==> 3) build default + +mos-a16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816          -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$DROM" >/dev/null
python3 "$ROOT/tools/snes-checksum.py" "$AROM" >/dev/null

echo "==> 4) MAME: host == default == +mos-a16 (corpus_result == $WANT, 32-bit/4-byte)"
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
emu_verdict "$rc" "32-bit long/int32_t value differential: corpus_result==$WANT host==default==+mos-a16 (both emulators), s32 via 2x s16 + __mulsi3/__udivsi3/__umodsi3"
exit $rc
