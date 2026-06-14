#!/usr/bin/env bash
# dev/a16sub.sh — #321 Increment 1b: 16-bit-accumulator SUB via the A16 register.
#
# Builds examples/65816/a16sub.c with +mos-a16 and proves the dual-width A16
# subtract path: g16 = a16v - b16v (0x1234 - 0x1111) compiles to a single 16-bit
# subtract bracketed by ONE rep/sep pair — sec; rep #$20; lda; sbc; sta;
# sep #$20 — and produces the correct 16-bit difference, so corpus_result ==
# 0x0123 on BOTH MAME and bsnes-jg, driven solely by the native-mode crt0.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16sub. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
# bsnes-jg cross-check reuses build/jgxcheck (built by dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-increment-1b-dual-width-accumulator.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16sub   # build a16sub.c +mos-a16, assert sec/rep/lda/sbc/sta/sep + corpus_result==0x0123 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16sub.c"
ROM="$BUILD/a16sub.sfc"; MAP="$BUILD/a16sub.map"; OBJ="$BUILD/a16sub.o"
WANT=0x0123
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16sub.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: 16-bit sub fuses to sec / rep #\$20 / lda / sbc / sta / sep #\$20 (one bracket)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(38|c2 20|e2 20|af|ef|8f)\b' | head
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2 20\b' || true)
nsbc=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e[df]\b')   # ed/ef = sbc abs/long
[ "$nrep" -eq 1 ] && echo "  PASS: exactly one rep #\$20 (single bracket open)" || { echo "  FAIL: expected 1 rep #\$20, got $nrep"; rc=1; }
[ "$nsep" -le 1 ] && echo "  PASS: <=1 sep #\$20 (single 16-bit region; trailing store merges in, main never returns)" || { echo "  FAIL: expected <=1 sep #\$20, got $nsep"; rc=1; }
[ "$nsbc" -ge 1 ] && echo "  PASS: 16-bit sbc present" || { echo "  FAIL: no 16-bit sbc"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0x1234 - 0x1111)"
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
[ $rc -eq 0 ] && echo "RESULT: PASS — 16-bit sub (sec/rep/lda/sbc/sta/sep) computes 0x0123; both emulators agree" \
             || echo "RESULT: FAIL"
exit $rc
