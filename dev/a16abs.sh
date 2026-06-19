#!/usr/bin/env bash
# dev/a16abs.sh — #321 native 16-bit absolute load/store (`g = gg`).
#
# Builds examples/65816/a16abs.c with +mos-a16. A 16-bit global-to-global copy must
# use native 16-bit absolute load/store (lda abs / sta abs, opcodes ad/8d or the
# platform's long forms af/8f) under rep/sep — NOT the 4-op 8-bit X/Y byte shuffle
# (ldx gg=ae; ldy gg+1=ac; stx g=8e; sty g+1=8c). corpus_result == 0x5A3D
# (0x5A3C copied via g, +1) on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16abs. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-16bit-absolute-load-store.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16abs   # 16-bit absolute load/store (lda abs/sta abs in M16, no X/Y byte shuffle); corpus_result==0x5A3D both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16abs.c"
ROM="$BUILD/a16abs.sfc"; MAP="$BUILD/a16abs.map"; OBJ="$BUILD/a16abs.o"
WANT=0x5A3D
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16abs.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: native 16-bit lda abs/sta abs under rep/sep — no X/Y byte shuffle"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|a[df]|8[df]|ae|ac|8e|8c)\b' | head -20
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nlda=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*a[df]\b' || true)        # lda abs (ad) / long (af)
nsta=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*8[df]\b' || true)        # sta abs (8d) / long (8f)
nshuf=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(ae|ac|8e|8c)\b' || true) # ldx/ldy/stx/sty abs (8-bit byte shuffle)
[ "$nrep" -ge 1 ] && echo "  PASS: $nrep rep #\$20 bracket(s) — native 16-bit absolute access" || { echo "  FAIL: no rep #\$20"; rc=1; }
[ "$nlda" -ge 2 ] && echo "  PASS: $nlda lda abs (16-bit absolute load)" || { echo "  FAIL: expected >=2 lda abs, got $nlda"; rc=1; }
[ "$nsta" -ge 2 ] && echo "  PASS: $nsta sta abs (16-bit absolute store)" || { echo "  FAIL: expected >=2 sta abs, got $nsta"; rc=1; }
[ "$nshuf" -eq 0 ] && echo "  PASS: no ldx/ldy/stx/sty byte shuffle (fully native 16-bit)" || { echo "  FAIL: found $nshuf X/Y byte-shuffle ops — copy narrowed to 8-bit"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0x5A3C copied via g, +1)"
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
emu_verdict "$rc" "native 16-bit absolute load/store (lda abs/sta abs) copies 0x5A3C; both emulators read 0x5A3D"
exit $rc
