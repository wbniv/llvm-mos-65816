#!/usr/bin/env bash
# dev/a16eq.sh — #321 native 16-bit equality compares (`==` / `!=`).
#
# Builds examples/65816/a16eq.c with +mos-a16. Each 16-bit ==/!= feeding a branch
# must compile to a fused 16-bit compare-branch — rep; lda; cmp; sep; beq/bne —
# NOT the old two-block 8-bit cmp/cpx chain. corpus_result == 0x0011 on BOTH MAME
# and bsnes-jg (operands differ in both bytes, so a single-byte compare misfires).
#
# Runs INSIDE the dev container; drive: dev/run.sh a16eq. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-16bit-equality-compares.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16eq   # 16-bit ==/!= -> rep/lda/cmp/sep/beq, no 8-bit cmp/cpx chain; corpus_result==0x0011 both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16eq.c"
ROM="$BUILD/a16eq.sfc"; MAP="$BUILD/a16eq.map"; OBJ="$BUILD/a16eq.o"
WANT=0x0011
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16eq.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: each ==/!= is one 16-bit cmp under rep/sep, NOT the 8-bit cmp/cpx chain"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|c[59d]|d0|f0)\b' | head -20
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2 20\b' || true)
ncmp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c[59d]\b' || true)        # cmp zp/imm/abs
ncpxy=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(e4|ec|c4|cc)\b' || true) # 8-bit cpx/cpy chain
[ "$nrep" -ge 2 ] && echo "  PASS: $nrep rep #\$20 bracket(s) — native 16-bit compares" || { echo "  FAIL: expected >=2 rep #\$20, got $nrep"; rc=1; }
[ "$nsep" -ge 2 ] && echo "  PASS: $nsep sep #\$20" || { echo "  FAIL: expected >=2 sep #\$20, got $nsep"; rc=1; }
[ "$ncmp" -ge 2 ] && echo "  PASS: $ncmp 16-bit cmp ops" || { echo "  FAIL: expected >=2 16-bit cmp, got $ncmp"; rc=1; }
[ "$ncpxy" -eq 0 ] && echo "  PASS: no 8-bit cpx/cpy chain (fully native 16-bit)" || { echo "  FAIL: found $ncpxy cpx/cpy — equality narrowed to 8-bit"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (==, != true; == false)"
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
[ $rc -eq 0 ] && echo "RESULT: PASS — native 16-bit ==/!= (rep/lda/cmp/sep/beq) compute 0x0011; both emulators agree" \
             || echo "RESULT: FAIL"
exit $rc
