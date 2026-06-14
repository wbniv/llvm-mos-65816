#!/usr/bin/env bash
# dev/a16localimm.sh — #321 native s16 immediate-operand optimization (adc #imm).
#
# Builds examples/65816/a16localimm.c with +mos-a16, where `t = a16v + 0x0345` is
# a multi-use LOCAL — so the 1b/1c combiner peephole can't fold it and the add
# goes native. selectAlu16Native folds the 16-bit constant into the immediate form
# (clc; rep; lda a; adc #$0345; sta; sep) instead of materializing it into an
# Imag16 pair, dropping ~4 instructions. Result corpus_result == 0x1545 (0x1200 +
# 0x0345) on BOTH MAME and bsnes-jg, driven solely by the native-mode crt0.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16localimm. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
# bsnes-jg cross-check reuses build/jgxcheck (built by dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-native-s16-immediate-operand-optimization-adc.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16localimm   # build a16localimm.c +mos-a16, assert clc/rep/lda/adc/sta/sep + corpus_result==0x1122 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16localimm.c"
ROM="$BUILD/a16localimm.sfc"; MAP="$BUILD/a16localimm.map"; OBJ="$BUILD/a16localimm.o"
WANT=0x1545
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16localimm.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: the 16-bit immediate folds to 'adc #\$0345' (opcode 69), NOT a"
echo "    materialized constant read from zero page (opcode 65 = adc zp)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(18|c2 20|e2 20|69|a5|85)\b' | head
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2 20\b' || true)
nimm=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*69\b' || true)   # 69 = adc #imm (folded)
nzp=$(printf '%s\n'  "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*65\b' || true)   # 65 = adc zp  (un-folded)
fsz=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:' || true)
[ "$nrep" -eq 1 ] && echo "  PASS: exactly one rep #\$20 (single bracket open)" || { echo "  FAIL: expected 1 rep #\$20, got $nrep"; rc=1; }
[ "$nsep" -le 1 ] && echo "  PASS: <=1 sep #\$20 (single 16-bit region; trailing store merges in, main never returns)" || { echo "  FAIL: expected <=1 sep #\$20, got $nsep"; rc=1; }
[ "$nimm" -ge 1 ] && echo "  PASS: adc #imm present (immediate folded, opcode 69)" || { echo "  FAIL: no adc #imm — constant not folded"; rc=1; }
[ "$nzp"  -eq 0 ] && echo "  PASS: no adc zp — constant is NOT materialized into Imag16" || { echo "  FAIL: found adc zp ($nzp) — constant still materialized"; rc=1; }
echo "  (main is $fsz instructions — the immediate fold drops the ~4-instr constant materialization)"
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (native s16 local: 0x1000 + 0x0122)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> bsnes-jg: assert corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then
    echo "  $line"
  else echo "  $line"; rc=1; fi
else
  echo "==> bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — 16-bit immediate folds to adc #\$0345 (no materialization); computes 0x1545 on both emulators" \
             || echo "RESULT: FAIL"
exit $rc
