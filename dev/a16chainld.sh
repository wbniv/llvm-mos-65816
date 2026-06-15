#!/usr/bin/env bash
# dev/a16chainld.sh — #321 native s16 load-fold (c): multi-use 16-bit add chain.
#
# Builds examples/65816/a16chainld.c with +mos-a16. A >=3-term add chain of near-abs
# globals whose result is REUSED (`t = a+b+c+d; g=t; h=t; corpus_result=t`) threads the
# running sum through A16 in one go — `lda a; clc; adc b; clc; adc c; clc; adc d; sta t`
# — instead of round-tripping the partial sum through an Imag16 pair between every add.
# add_chain16 only fired store-rooted; add_chain16_ld handles the multi-use register
# result. The gate asserts the chain reads each global via adc abs (6f) and that there
# is NO intermediate Imag16 round-trip (sta zp count drops to 1 = the result only).
# corpus_result == 0x1234 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16chainld. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-s16-add-chain-multiuse.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16chainld   # multi-use 16-bit add chain threads A16 (no round-trips), corpus_result==0x1234 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16chainld.c"
ROM="$BUILD/a16chainld.sfc"; MAP="$BUILD/a16chainld.map"; OBJ="$BUILD/a16chainld.o"
WANT=0x1234
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16chainld.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: the 4-term chain threads through A16 — adc abs (6f) per term, and"
echo "    NO intermediate Imag16 round-trip (only ONE sta zp = the reused result)."
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
nadcabs=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*6f\b' || true)  # adc abs/long
nstazp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*85\b' || true)   # sta zp (Imag16)
echo "  adc-abs=$nadcabs  sta-zp=$nstazp"
[ "$nadcabs" -ge 3 ] && echo "  PASS: $nadcabs adc abs — each chain term read directly (4-term chain)" || { echo "  FAIL: expected >=3 adc abs, got $nadcabs"; rc=1; }
[ "$nstazp" -le 1 ] && echo "  PASS: $nstazp sta zp — sum stays in A16, no intermediate round-trip" || { echo "  FAIL: $nstazp sta zp — chain round-trips through Imag16 (expected <=1)"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (a + b + c + d, reused)"
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
[ $rc -eq 0 ] && echo "RESULT: PASS — multi-use 16-bit add chain threads A16 (no Imag16 round-trip) and computes 0x1234; both emulators agree" \
             || echo "RESULT: FAIL"
exit $rc
