#!/usr/bin/env bash
# dev/a16ashift.sh — #321 native 16-bit signed (arithmetic) right shift (`>>`).
#
# Builds examples/65816/a16ashift.c with +mos-a16. A small constant arithmetic
# right shift on a `short` must compile to `cmp #$8000; ror a` per bit under one
# rep/sep bracket (the cmp sets carry = sign bit, ror replicates it) — NOT the 8-bit
# lsr/ror byte chain, and NOT a libcall. `x >> 3` is 3× `cmp #$8000; ror a`.
# corpus_result == 0xFE01 (0xF000 >> 3 = 0xFE00, +1) on BOTH MAME and bsnes-jg; a
# logical shift would read 0x1E01.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16ashift. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-16bit-signed-shift-ashr.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16ashift   # 16-bit signed >> (cmp #\$8000; ror per bit, no lsr/ror byte chain); corpus_result==0xFE01 both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16ashift.c"
ROM="$BUILD/a16ashift.sfc"; MAP="$BUILD/a16ashift.map"; OBJ="$BUILD/a16ashift.o"
WANT=0xFE01
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16ashift.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: native 16-bit cmp #\$8000 / ror under rep/sep — no 8-bit lsr/ror chain, no libcall"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|c9 00 80|6a|4a)\b' | head -20
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2 20\b' || true)
ncmp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c9 00 80\b' || true)  # cmp #$8000
nror=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*6a\b' || true)        # ror a
nlsr=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*4a\b' || true)        # lsr a (8-bit chain)
nlib=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(20|22)\b' || true)   # jsr/jsl (shift libcall)
ninca=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*1a\b' || true)       # inc a (the trailing +1)
[ "$nrep" -ge 1 ] && echo "  PASS: $nrep rep #\$20 bracket(s)" || { echo "  FAIL: no rep #\$20"; rc=1; }
# The trailing `+1` is now a native `inc a` (not an 8-bit byte inc), so the whole run
# stays in one M16 region — no `sep` is forced mid-function (nsep may legitimately be 0).
[ "$ninca" -ge 1 ] && echo "  PASS: trailing +1 is native inc a — stays M16, no forced sep (nsep=$nsep)" || { echo "  FAIL: trailing +1 not native inc a (nsep=$nsep)"; rc=1; }
[ "$ncmp" -eq 3 ] && echo "  PASS: 3 cmp #\$8000 (sign probe, one per bit)" || { echo "  FAIL: expected 3 cmp #\$8000, got $ncmp"; rc=1; }
[ "$nror" -eq 3 ] && echo "  PASS: 3 ror a (sign rotate, one per bit, 16-bit)" || { echo "  FAIL: expected 3 ror a, got $nror"; rc=1; }
[ "$nlsr" -eq 0 ] && echo "  PASS: no 8-bit lsr a (not the byte chain)" || { echo "  FAIL: found $nlsr lsr a — shift narrowed to 8-bit"; rc=1; }
[ "$nlib" -eq 0 ] && echo "  PASS: no shift libcall (no jsr/jsl)" || { echo "  FAIL: found $nlib jsr/jsl — shift went to a libcall"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0xF000 >> 3 = 0xFE00, +1)"
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
emu_verdict "$rc" "native 16-bit signed >> (cmp #\$8000; ror) sign-extends to 0xFE01; both emulators agree"
exit $rc
