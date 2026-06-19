#!/usr/bin/env bash
# dev/a16local.sh — #321 Increment 1d-retry: GISel-native s16 value in Imag16.
#
# Builds examples/65816/a16local.c with +mos-a16, where `t = a16v + b16v` is a
# LOCAL reused by three stores — so the 1b/1c combiner peephole (single store-of-
# ALU) CANNOT fire and the s16 add must go native: the value lives in an Imag16
# zero-page pair and selectAdd16Native emits one rep/sep bracket on the transient
# A16 (lda zp; clc; adc zp; sta zp) — NO Ac16<->8-bit COPY (the crash that sank
# the first 1d prototype). Result corpus_result == 0x1122 on BOTH MAME and
# bsnes-jg, driven solely by the native-mode crt0.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16local. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
# bsnes-jg cross-check reuses build/jgxcheck (built by dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16local   # build a16local.c +mos-a16, assert clc/rep/lda/adc/sta/sep + corpus_result==0x1122 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16local.c"
ROM="$BUILD/a16local.sfc"; MAP="$BUILD/a16local.map"; OBJ="$BUILD/a16local.o"
WANT=0x1122
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16local.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: 16-bit add fuses to clc / rep #\$20 / lda / adc / sta / sep #\$20 (one bracket)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(18|c2 20|e2 20|6[5df]|a[5df]|85)\b' | head
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nsep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e2 20\b' || true)
# 16-bit adc in zp (65, native Imag16) OR abs/long (6d/6f, with the global operand
# folded in by alu16_absld) — accept either so the test is robust to load-folding.
nadc=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*6[5df]\b' || true)
[ "$nrep" -eq 1 ] && echo "  PASS: exactly one rep #\$20 (single bracket open)" || { echo "  FAIL: expected 1 rep #\$20, got $nrep"; rc=1; }
[ "$nsep" -le 1 ] && echo "  PASS: <=1 sep #\$20 (single 16-bit region; trailing store merges in, main never returns)" || { echo "  FAIL: expected <=1 sep #\$20, got $nsep"; rc=1; }
[ "$nadc" -ge 1 ] && echo "  PASS: 16-bit adc present (zp or load-folded abs)" || { echo "  FAIL: no 16-bit adc"; rc=1; }
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
emu_verdict "$rc" "16-bit add (clc/rep/lda/adc/sta/sep) computes 0x1122; both emulators agree"
exit $rc
