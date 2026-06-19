#!/usr/bin/env bash
# dev/a16eqvalp.sh — #321 gated native s16 equality-as-value through an INDIRECT operand
# (`*p == c` stored as a VALUE). examples/65816/a16eqvalp.c. Two assertions:
#   1. NATIVE: under +mos-a16 the indirect-operand EQ-as-value compiles to a native 16-bit
#      compare (`rep; lda (zp); cmp; sep; beq/bne`) — NO 8-bit `cpx`/`cpy` byte chain
#      (gated native EQ, MOSLegalizerInfo::legalizeICmp). -verify-machineinstrs clean.
#   2. VALUE: corpus_result == 0x0101 host == default == +mos-a16 on MAME + bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16eqvalp. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16eqvalp   # indirect s16 equality-as-value: native 16-bit compare, corpus_result==0x0101"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16eqvalp.c"
DROM="$BUILD/a16eqvalp_default.sfc"; DMAP="$BUILD/a16eqvalp_default.map"
AROM="$BUILD/a16eqvalp_a16.sfc";     AMAP="$BUILD/a16eqvalp_a16.map"
OBJ="$BUILD/a16eqvalp.o"
WANT=0x0101
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean + NATIVE 16-bit compare (no 8-bit cpx/cpy byte chain)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/a16eqvalp.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/a16eqvalp.vlog" | head -3; rc=1; }
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
hascmp=$(printf '%s\n' "$DIS" | grep -cE '\bcmp\b' || true)
hascpxy=$(printf '%s\n' "$DIS" | grep -cE '\b(cpx|cpy)\b' || true)
if [ "$hascmp" -ge 1 ] && [ "$hascpxy" -eq 0 ]; then
  echo "  PASS: native 16-bit cmp present, no 8-bit cpx/cpy byte chain — indirect EQ-as-value is native"
else
  echo "  FAIL: expected a native cmp and no cpx/cpy (cmp=$hascmp cpx/cpy=$hascpxy) — gate didn't fire / fell back to 8-bit"; rc=1
fi

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
emu_verdict "$rc" "indirect s16 equality-as-value is native (both emulators), corpus_result==0x0101"
exit $rc
