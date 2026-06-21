#!/usr/bin/env bash
# dev/a16bitchain.sh — #321 native s16 bitwise chains (AND/OR/XOR).
#
# Builds examples/65816/a16bitchain.c with +mos-a16. A homogeneous >=3-term AND/OR/XOR
# chain of near-abs globals threads the running value through A16 (`lda a; and b; and c;
# sta`) with NO carry-init, instead of round-tripping each partial result through an
# Imag16 pair. The bitwise analogue of the add chain; covers store-rooted (bit_chain16)
# and multi-use (bit_chain16_ld) forms. The gate asserts each chain reads its globals
# via and/ora/eor abs (2f/0f/4f) and threads (low sta-zp count). corpus_result == 0x6261
# on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16bitchain. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-s16-bitwise-chains.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16bitchain   # 16-bit AND/OR/XOR chains thread A16 (no carry, no round-trips), corpus_result==0x6261 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16bitchain.c"
ROM="$BUILD/a16bitchain.sfc"; MAP="$BUILD/a16bitchain.map"; OBJ="$BUILD/a16bitchain.o"
WANT=0x6261
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16bitchain.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: each AND/OR/XOR chain reads its globals via and/ora/eor abs"
echo "    (2[df]/0[df]/4[df]) and threads through A16 (no carry-init, low sta-zp = no round-trip)."
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
# Match BOTH the absolute (2d/0d/4d) and absolute-long (2f/0f/4f) forms: a near-global
# operand reads as abs since the 0007 near-abs relaxation fix; far would be long. The
# gate cares that the global is read DIRECTLY, not which relaxation form (super-set [df]).
nand=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*2[df]\b' || true)  # and abs/long
nora=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*0[df]\b' || true)  # ora abs/long
neor=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*4[df]\b' || true)  # eor abs/long
nstazp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*85\b' || true)  # sta zp (Imag16)
echo "  and-abs=$nand  ora-abs=$nora  eor-abs=$neor  sta-zp=$nstazp"
[ "$nand" -ge 2 ] && echo "  PASS: $nand and abs — AND chain reads globals directly" || { echo "  FAIL: expected >=2 and abs, got $nand"; rc=1; }
[ "$nora" -ge 2 ] && echo "  PASS: $nora ora abs — OR chain reads globals directly" || { echo "  FAIL: expected >=2 ora abs, got $nora"; rc=1; }
[ "$neor" -ge 2 ] && echo "  PASS: $neor eor abs — XOR chain reads globals directly" || { echo "  FAIL: expected >=2 eor abs, got $neor"; rc=1; }
[ "$nstazp" -le 4 ] && echo "  PASS: $nstazp sta zp — chains thread A16, no per-op round-trip" || { echo "  FAIL: $nstazp sta zp — chains round-trip through Imag16"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (AND + XOR + OR chains)"
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
emu_verdict "$rc" "16-bit AND/OR/XOR chains thread A16 (no carry, no round-trip) and compute 0x6261; both emulators agree"
exit $rc
