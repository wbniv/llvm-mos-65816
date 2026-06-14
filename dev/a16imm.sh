#!/usr/bin/env bash
# dev/a16imm.sh — #321 Increment 1b: 16-bit-accumulator ALU with an immediate operand.
#
# Builds examples/65816/a16imm.c with +mos-a16 and proves g = a OP #imm16 lowers to
# lda a; OP #imm; sta g on the A16 accumulator (subtract-by-constant folds to add of
# the negated constant). corpus_result == 0x1545 (0x1200 + 0x0345) on BOTH MAME and
# bsnes-jg. Also shows the three immediate ops share ONE rep/sep bracket — the
# carry-init (clc) is M-width-agnostic and no longer splits the run.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16imm. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
# bsnes-jg cross-check reuses build/jgxcheck (built by dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-increment-1b-dual-width-accumulator.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16imm   # build a16imm.c +mos-a16, assert adc/and #imm16 + corpus_result==0x1545 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16imm.c"
ROM="$BUILD/a16imm.sfc"; MAP="$BUILD/a16imm.map"; OBJ="$BUILD/a16imm.o"
WANT=0x1545
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16imm.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: ALU-with-constant selects to adc/and #imm16 (immediate forms)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|69|29)\b' | head
nadci=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*69\b')   # 69 = adc #imm
nandi=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*29\b')   # 29 = and #imm
[ "$nadci" -ge 1 ] && echo "  PASS: adc #imm16 present" || { echo "  FAIL: no adc #imm16"; rc=1; }
[ "$nandi" -ge 1 ] && echo "  PASS: and #imm16 present" || { echo "  FAIL: no and #imm16"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0x1200 + 0x0345)"
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
[ $rc -eq 0 ] && echo "RESULT: PASS — 16-bit ALU-with-immediate computes 0x1545; both emulators agree" \
             || echo "RESULT: FAIL"
exit $rc
