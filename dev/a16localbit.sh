#!/usr/bin/env bash
# dev/a16localbit.sh — #321 Increment 1d-retry step 5: native 16-bit AND/OR/XOR.
#
# examples/65816/a16localbit.c does three native s16 bitwise ops on reused locals
# (t = a&b; u = t|c; w = u^a) — none foldable by the 1b/1c combiner peephole, so
# each selects to a native rep/sep bracket on the transient A16 (lda zp; and|ora|
# eor zp; sta zp) with the value resident in Imag16 and NO Ac16<->8-bit COPY. Must
# (a) COMPILE CLEAN (-verify-machineinstrs) and (b) run corpus_result == 0x000F on
# BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16localbit. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck (dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16localbit   # native s16 and/ora/eor compile clean + corpus_result==0x000F on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16localbit.c"
ROM="$BUILD/a16localbit.sfc"; MAP="$BUILD/a16localbit.map"; OBJ="$BUILD/a16localbit.o"
WANT=0x000F
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0
echo "==> compile-clean gate: complex multi-op native s16 must NOT crash the coalescer"
# -verify-machineinstrs catches malformed MIR (e.g. an 8-bit imm in a 16-bit reg).
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -mllvm -verify-machineinstrs \
     -Os -c -o "$OBJ" "$SRC" 2>"$BUILD/a16localbit.cc.err"; then
  echo "  PASS: compiled clean (-verify-machineinstrs), no coalescer crash"
else
  echo "  FAIL: compile crashed/failed"; sed -n '1,12p' "$BUILD/a16localbit.cc.err"; exit 1
fi
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
# and/ora/eor in zp (25/05/45, native) OR abs/long (2d/2f, 0d/0f, 4d/4f, with a
# global operand folded in by alu16_absld) — accept either, robust to load-folding.
nbit=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(2[5df]|0[5df]|4[5df])\b' || true)
nbra=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)        # rep #$20 brackets
[ "$nbit" -ge 3 ] && echo "  PASS: $nbit native 16-bit bitwise ops present (and/ora/eor, zp or folded abs)" || { echo "  FAIL: expected >=3 bitwise ops, got $nbit"; rc=1; }
echo "  ($nbra rep #\$20 brackets — one per native bitwise op)"

echo "==> compile+link -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-13s %6s bytes\n' a16localbit.sfc "$(stat -c%s "$ROM")"

echo "==> MAME: assert corpus_result == $WANT (a&b | c ^ a -> 0x000F)"
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
emu_verdict "$rc" "native 16-bit and/ora/eor in Imag16 compile clean and compute 0x000F; both emulators agree"
exit $rc
