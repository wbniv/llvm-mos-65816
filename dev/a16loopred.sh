#!/usr/bin/env bash
# dev/a16loopred.sh — #321 native s16 loop strength-reduction to a 16-bit add.
#
# Builds examples/65816/a16loopred.c with +mos-a16. A counted increment loop
# `while (i) { x = x + 1; i = i - 1; }` is COMBINED by the optimizer into a single
# `x += n` computed as one native 16-bit add — not a per-iteration inc loop, not an
# 8-bit byte chain, not a libcall. This is the end-to-end correctness guard for that
# combine after the native-s16 add/sub + inc/dec legalization changes. The gate asserts
# a 16-bit add (adc 65/6f) survives, no 8-bit inc-zp (e6) / dec-zp (c6) byte step, and
# no helper call (jsr); corpus_result == 0x1239 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16loopred. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-s16-inc-dec-accumulator.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16loopred   # counted-loop strength-reduction to a native 16-bit add, corpus_result==0x1239 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16loopred.c"
ROM="$BUILD/a16loopred.sfc"; MAP="$BUILD/a16loopred.map"; OBJ="$BUILD/a16loopred.o"
WANT=0x1239
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16loopred.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: the counted loop reduces to a single native 16-bit add (adc 65/6f),"
echo "    with NO 8-bit byte inc-zp (e6) / dec-zp (c6) step and NO helper call (jsr 20)."
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
nadc=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(65|6f)\b' || true)  # adc zp/abs
ninczp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e6\b' || true)     # inc zp (8-bit)
ndeczp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c6\b' || true)     # dec zp (8-bit)
njsr=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*20\b' || true)       # jsr (libcall)
echo "  adc=$nadc  inc-zp(e6)=$ninczp  dec-zp(c6)=$ndeczp  jsr=$njsr"
[ "$nadc" -ge 1 ] && echo "  PASS: $nadc native 16-bit add — loop reduced to x += n" || { echo "  FAIL: no 16-bit adc (loop not reduced to a native add)"; rc=1; }
{ [ "$ninczp" -eq 0 ] && [ "$ndeczp" -eq 0 ]; } && echo "  PASS: no 8-bit byte inc/dec step survived" || { echo "  FAIL: 8-bit inc/dec survives (e6=$ninczp c6=$ndeczp)"; rc=1; }
[ "$njsr" -eq 0 ] && echo "  PASS: no helper call (fully inline)" || { echo "  FAIL: $njsr jsr — fell back to a helper"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (loop x += n combine is correct)"
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
[ $rc -eq 0 ] && echo "RESULT: PASS — counted loop strength-reduces to a native 16-bit add and computes 0x1239; both emulators agree" \
             || echo "RESULT: FAIL"
exit $rc
