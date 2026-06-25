#!/usr/bin/env bash
# dev/a16regpress.sh — #321 POSITIVE gate for the (FIXED) +mos-a16 register-allocation
# deadlock. examples/65816/a16regpress.c (reduced from corpus globals.c) used to abort
# "ran out of registers during register allocation in function 'main'" under +mos-a16
# -O1/-Os: a strength-reduced i8 byte index stepped `i += 2` selected to A-pinned ADCImm
# (class Ac={A}) and collided, across the 16-bit indexed-load Ac16 transit, with the
# single accumulator. Fork patch 0009 lowers a small-constant i8 add/sub to a relocatable
# G_INC/G_DEC chain under +mos-a16, so the byte index lives in X (inx; inx; cpx) and frees
# A16. This gate asserts the program now compiles clean AND computes the SAME corpus_result
# host == default == +mos-a16 on BOTH MAME and bsnes-jg (0x01A7), with a disasm gate that
# the byte index increments via inx (not an A-pinned adc).
#
# Runs INSIDE the dev container; drive: dev/run.sh a16regpress. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-24-321-a16-pressure-fix-implementation.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16regpress   # FIXED a16 RA-pressure deadlock now compiles + corpus_result==0x01A7 both emulators (byte index via inx, not A-pinned adc)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16regpress.c"
ROM="$BUILD/a16regpress.sfc"; MAP="$BUILD/a16regpress.map"; OBJ="$BUILD/a16regpress.o"
WANT=0x01A7
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16, -Os, -verify-machineinstrs) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16regpress.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: the strength-reduced byte index increments via inx (relocated off A), no A-pinned adc deadlock"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
ninx=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(e8|c8)\b' || true)  # inx / iny
[ "$ninx" -ge 1 ] && echo "  PASS: $ninx inx/iny — byte index relocated off the singleton {A}" \
  || { echo "  FAIL: no inx/iny — byte index still A-pinned (fix inactive?)"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (host==default==+mos-a16)"
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
emu_verdict "$rc" "FIXED a16 RA-pressure deadlock: compiles clean + corpus_result==0x01A7; both emulators agree"
exit $rc
