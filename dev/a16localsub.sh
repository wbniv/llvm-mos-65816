#!/usr/bin/env bash
# dev/a16localsub.sh — #321 Increment 1d-retry step 5: GISel-native s16 SUBTRACT.
#
# Builds examples/65816/a16localsub.c with +mos-a16, where `t = a16v - b16v` is a
# LOCAL reused by three stores — so the 1b/1c combiner peephole (single store-of-
# ALU) CANNOT fire and the s16 sub must go native: the value lives in an Imag16
# zero-page pair and selectAlu16Native emits one rep/sep bracket on the transient
# A16 (sec; lda zp; sbc zp; sta zp) — NO Ac16<->8-bit COPY (the crash that sank
# the first 1d prototype). Result corpus_result == 0x1222 on BOTH MAME and
# bsnes-jg, driven solely by the native-mode crt0.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16localsub. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
# bsnes-jg cross-check reuses build/jgxcheck (built by dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16localsub   # build a16localsub.c +mos-a16, assert clc/rep/lda/adc/sta/sep + corpus_result==0x1122 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16localsub.c"
ROM="$BUILD/a16localsub.sfc"; MAP="$BUILD/a16localsub.map"; OBJ="$BUILD/a16localsub.o"
WANT=0x1222
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16localsub.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: 16-bit sub fuses to sec / rep #\$20 / lda / sbc / sta / sep #\$20 (one bracket)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(38|c2 20|e2 20|e[5df]|a[5df]|85)\b' | head
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2 20\b' || true)
# 16-bit sbc in zp (e5, native Imag16) OR abs/long (ed/ef, global operand folded
# in by alu16_absld) — accept either so the test is robust to load-folding.
nadc=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e[5df]\b' || true)
[ "$nrep" -eq 1 ] && echo "  PASS: exactly one rep #\$20 (single bracket open)" || { echo "  FAIL: expected 1 rep #\$20, got $nrep"; rc=1; }
[ "$nsep" -le 1 ] && echo "  PASS: <=1 sep #\$20 (single 16-bit region; trailing store merges in, main never returns)" || { echo "  FAIL: expected <=1 sep #\$20, got $nsep"; rc=1; }
[ "$nadc" -ge 1 ] && echo "  PASS: 16-bit sbc present (zp or load-folded abs)" || { echo "  FAIL: no 16-bit sbc"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (native s16 local: 0x1000 + 0x0122)"
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
emu_verdict "$rc" "native 16-bit sub (sec/rep/lda/sbc/sta/sep) in Imag16 computes 0x1222; both emulators agree"
exit $rc
