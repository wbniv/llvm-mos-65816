#!/usr/bin/env bash
# dev/a16eqval.sh — #321 native s16 equality-as-value: `b = (a == c)` stored as a VALUE.
# examples/65816/a16eqval.c (a,b,c,d are globals). Two assertions:
#   1. NATIVE: under +mos-a16 each global `==`/`!=` is a native 16-bit compare with the
#      #321 v3 abs-fold (`cmp abs/long`), NOT the 8-bit cpx/cmp chain. (This SUPERSEDES
#      the 2026-06-16 byte-wise stopgap, which is itself documented inline.)
#   2. VALUE: corpus_result == 0x0101 host == default == +mos-a16 on MAME + bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16eqval. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16eqval   # s16 global equality-as-value: native 16-bit cmp abs/long (v3 abs-fold), corpus_result==0x0101"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16eqval.c"
DROM="$BUILD/a16eqval_default.sfc"; DMAP="$BUILD/a16eqval_default.map"
AROM="$BUILD/a16eqval_a16.sfc";     AMAP="$BUILD/a16eqval_a16.map"
OBJ="$BUILD/a16eqval.o"
WANT=0x0101
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean + NATIVE 16-bit equality (no 8-bit cpx/cpy chain)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/a16eqval.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/a16eqval.vlog" | head -3; rc=1; }
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
# #321 v3 superseded the byte-wise stopgap for GLOBAL equality-as-value: a,b,c,d are
# globals, so each `==`/`!=` now goes NATIVE 16-bit and the abs-fold reads them via
# `cmp abs/long` (CmpBrAbsAbs16) instead of the 8-bit cpx/cmp two-byte chain. Assert
# native (a 16-bit cmp present, no 8-bit cpx/cpy). See
# docs/plans/2026-06-17-321-native-s16-eq-as-value-v3-abs-fold-globals.md.
ncmp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c[59df]\b' || true)        # cmp zp/imm/abs/long
ncpxy=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(e4|ec|c4|cc)\b' || true) # 8-bit cpx/cpy chain
[ "$ncmp" -ge 2 ] && echo "  PASS: $ncmp native 16-bit cmp ops (globals folded via cmp abs/long)" || { echo "  FAIL: expected >=2 native 16-bit cmp, got $ncmp"; rc=1; }
[ "$ncpxy" -eq 0 ] && echo "  PASS: no 8-bit cpx/cpy chain (fully native 16-bit equality-as-value)" || { echo "  FAIL: found $ncpxy cpx/cpy — equality narrowed to 8-bit"; rc=1; }

echo "==> 2) build default + +mos-a16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816          -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$DROM" >/dev/null
python3 "$ROOT/tools/snes-checksum.py" "$AROM" >/dev/null

echo "==> 3) MAME: host == default == +mos-a16 (corpus_result == $WANT)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
echo "  default:";  run_assert "$DROM" "$DMAP" corpus_result "$WANT" || rc=1
echo "  +mos-a16:"; run_assert "$AROM" "$AMAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> 4) bsnes-jg: +mos-a16 corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$AMAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$AROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> 4) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — s16 global equality-as-value is native 16-bit (v3 abs-fold) and computes 0x0101 (both emulators)" \
             || echo "RESULT: FAIL"
exit $rc
