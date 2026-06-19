#!/usr/bin/env bash
# dev/a16shift.sh — #321 native 16-bit constant shifts (`<<`, unsigned `>>`).
#
# Builds examples/65816/a16shift.c with +mos-a16. A small constant s16 shift must
# compile to single-byte 16-bit accumulator shifts (`lda; asl/lsr ×k; sta`) under
# one rep/sep bracket — NOT the 8-bit asl/rol (or lsr/ror) byte-pair chain, and NOT
# a __ashlhi3/__lshrhi3 libcall. `x << 4` is 4× `asl`, `x >> 2` is 2× `lsr`; the
# shifts + the final add share ONE rep/sep run. corpus_result == 0x1278
# (0x1230 + 0x0048) on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16shift. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-16bit-constant-shifts.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16shift   # 16-bit constant shifts (asl/lsr under rep/sep, no rol/ror, no libcall); corpus_result==0x1278 both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16shift.c"
ROM="$BUILD/a16shift.sfc"; MAP="$BUILD/a16shift.map"; OBJ="$BUILD/a16shift.o"
WANT=0x1278
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16shift.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: native 16-bit asl/lsr under rep/sep — no 8-bit rol/ror, no shift libcall"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|0a|4a|2a|6a)\b' | head -20
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2 20\b' || true)
nasl=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*0a\b' || true)  # asl a
nlsr=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*4a\b' || true)  # lsr a
nrot=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(2a|6a)\b' || true)  # rol/ror a (8-bit chain)
nlib=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(20|22)\b' || true)  # jsr/jsl (shift libcall)
[ "$nrep" -ge 1 ] && echo "  PASS: $nrep rep #\$20 bracket(s)" || { echo "  FAIL: no rep #\$20"; rc=1; }
[ "$nsep" -le 1 ] && echo "  PASS: $nsep sep #\$20 (<=1; trailing store merges in, main never returns)" || { echo "  FAIL: expected <=1 sep #\$20, got $nsep"; rc=1; }
[ "$nasl" -eq 4 ] && echo "  PASS: 4 asl a (x << 4, one per bit, 16-bit)" || { echo "  FAIL: expected 4 asl a, got $nasl"; rc=1; }
[ "$nlsr" -eq 2 ] && echo "  PASS: 2 lsr a (x >> 2, one per bit, 16-bit)" || { echo "  FAIL: expected 2 lsr a, got $nlsr"; rc=1; }
[ "$nrot" -eq 0 ] && echo "  PASS: no 8-bit rol/ror (not the byte-pair chain)" || { echo "  FAIL: found $nrot rol/ror — shift narrowed to 8-bit pairs"; rc=1; }
[ "$nlib" -eq 0 ] && echo "  PASS: no shift libcall (no __ashlhi3/__lshrhi3 jsr/jsl)" || { echo "  FAIL: found $nlib jsr/jsl — shift went to a libcall"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0x1230 + 0x0048)"
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
emu_verdict "$rc" "native 16-bit constant shifts (asl/lsr under rep/sep) compute 0x1278; both emulators agree"
exit $rc
