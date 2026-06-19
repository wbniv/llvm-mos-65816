#!/usr/bin/env bash
# dev/a16chain.sh — #321 Increment 1c: a chained 16-bit ADD, value stays live in A16.
#
# Builds examples/65816/a16chain.c with +mos-a16 and proves g = a + b + c fuses to a
# single REP/SEP-bracketed sequence that threads the running sum through A16 —
# rep #$20; lda; clc; adc; clc; adc; sta; sep #$20 — so the intermediate (a+b)
# survives in the accumulator for the +c. corpus_result == 0x1230
# (0x1000 + 0x0200 + 0x0030) on BOTH MAME and bsnes-jg, driven by the native crt0.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16chain. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
# bsnes-jg cross-check reuses build/jgxcheck (built by dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-increment-1c-chained-16bit-alu.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16chain   # build a16chain.c +mos-a16, assert one rep/sep bracket with 2 adc + corpus_result==0x1230 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16chain.c"
ROM="$BUILD/a16chain.sfc"; MAP="$BUILD/a16chain.map"; OBJ="$BUILD/a16chain.o"
WANT=0x1230
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16chain.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: a+b+c fuses to one rep/sep bracket threading A16 (lda + 2 adc + sta)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|af|6f|8f)\b' | head
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2 20\b' || true)
nadc=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*6[df]\b')   # 6d/6f = adc abs/long
[ "$nrep" -eq 1 ] && echo "  PASS: exactly one rep #\$20 (single bracket — chain stays in A16)" || { echo "  FAIL: expected 1 rep #\$20, got $nrep"; rc=1; }
[ "$nsep" -le 1 ] && echo "  PASS: <=1 sep #\$20 (single 16-bit region; trailing store merges in, main never returns)" || { echo "  FAIL: expected <=1 sep #\$20, got $nsep"; rc=1; }
[ "$nadc" -ge 2 ] && echo "  PASS: >=2 chained adc" || { echo "  FAIL: expected >=2 adc, got $nadc"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0x1000 + 0x0200 + 0x0030)"
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
emu_verdict "$rc" "chained 16-bit add threads A16; computes 0x1230 on both emulators"
exit $rc
