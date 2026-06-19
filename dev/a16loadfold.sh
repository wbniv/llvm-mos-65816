#!/usr/bin/env bash
# dev/a16loadfold.sh — #321 native s16 load-fold: read global operands directly.
#
# Builds examples/65816/a16loadfold.c with +mos-a16, where `t = a16v + b16v` is a
# multi-use LOCAL (both operands near-abs globals) — the 1b store-fused peephole
# can't fold a multi-use result. The alu16_absld combiner rule reads the globals
# directly via the 16-bit absolute forms (lda a16v; adc b16v) inside the rep/sep
# bracket, with the result in an Imag16 pair, instead of copying each operand
# byte-wise into Imag16 first (~8 instrs dropped). No Ac16<->8-bit COPY. Result
# corpus_result == 0x2345 (0x1234 + 0x1111) on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16loadfold. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
# bsnes-jg cross-check reuses build/jgxcheck (built by dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-native-s16-fold-global-operand-loads-into-the.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16loadfold   # load-fold: globals read via lda/adc abs, corpus_result==0x2345 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16loadfold.c"
ROM="$BUILD/a16loadfold.sfc"; MAP="$BUILD/a16loadfold.map"; OBJ="$BUILD/a16loadfold.o"
WANT=0x2345
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16loadfold.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: both global operands are read DIRECTLY via 16-bit absolute"
echo "    (lda abs = ad, adc abs = 6d) — NOT materialized into Imag16 (adc zp = 65)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(18|c2 20|e2 20|6[df]|a[df]|85)\b' | head
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2 20\b' || true)
nadcabs=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*6[df]\b' || true)  # 6d/6f = adc abs/long (folded)
nldabs=$(printf '%s\n'  "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*a[df]\b' || true)  # ad/af = lda abs/long (folded)
nadczp=$(printf '%s\n'  "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*65\b' || true)     # 65 = adc zp (un-folded)
[ "$nrep" -eq 1 ] && echo "  PASS: exactly one rep #\$20 (single bracket open)" || { echo "  FAIL: expected 1 rep #\$20, got $nrep"; rc=1; }
[ "$nsep" -le 1 ] && echo "  PASS: <=1 sep #\$20 (single 16-bit region; trailing store merges in, main never returns)" || { echo "  FAIL: expected <=1 sep #\$20, got $nsep"; rc=1; }
[ "$nadcabs" -ge 1 ] && echo "  PASS: adc abs/long present (operand read directly, opcode 6d/6f)" || { echo "  FAIL: no adc abs — load not folded"; rc=1; }
[ "$nldabs"  -ge 1 ] && echo "  PASS: lda abs/long present (operand read directly, opcode ad/af)" || { echo "  FAIL: no lda abs — load not folded"; rc=1; }
[ "$nadczp"  -eq 0 ] && echo "  PASS: no adc zp — operands are NOT materialized into Imag16" || { echo "  FAIL: found adc zp ($nadczp) — operand still materialized"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0x1234 + 0x1111, operands read directly)"
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
emu_verdict "$rc" "global operands read directly via lda/adc abs (no Imag16 materialization); computes 0x2345 on both emulators"
exit $rc
