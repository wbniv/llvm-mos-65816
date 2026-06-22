#!/usr/bin/env bash
# dev/a16chainimm.sh — #321 native s16 ALU-chain extension: immediate term in an add chain.
#
# Builds examples/65816/a16chainimm.c with +mos-a16. A 16-bit add chain that includes a
# CONSTANT term (`a + b + c + K`) now threads the running sum through A16 with the
# constant folded as a final `adc #imm` — `lda a; clc; adc b; clc; adc c; clc; adc #K;
# sta` — instead of falling off the chain at the constant and round-tripping each partial
# sum through an Imag16 pair. Covers both the store-rooted (add_chain16) and multi-use
# (add_chain16_ld) forms. The gate asserts each chain reads globals via adc abs (6f),
# folds its constant via adc #imm (69), and threads (low sta zp count). corpus_result ==
# 0x2569 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16chainimm. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-s16-add-chain-immediate.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16chainimm   # immediate term folded into a threaded 16-bit add chain, corpus_result==0x2569 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16chainimm.c"
ROM="$BUILD/a16chainimm.sfc"; MAP="$BUILD/a16chainimm.map"; OBJ="$BUILD/a16chainimm.o"
WANT=0x2569
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16chainimm.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: each chain reads globals via adc abs (6[df]) and folds its constant"
echo "    via adc #imm (69), threading through A16 (no per-add Imag16 round-trip)."
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
# 6d (abs) since the 0007 near-abs relaxation fix; 6f (long) pre-fix or for far. [df] = both.
nadcabs=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*6[df]\b' || true)  # adc abs/long
nadcimm=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*69\b' || true)  # adc #imm16
nstazp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*85\b' || true)   # sta zp (Imag16)
echo "  adc-abs=$nadcabs  adc-imm=$nadcimm  sta-zp=$nstazp"
[ "$nadcimm" -ge 2 ] && echo "  PASS: $nadcimm adc #imm — each chain's constant folded INTO the chain" || { echo "  FAIL: expected >=2 adc #imm, got $nadcimm"; rc=1; }
[ "$nadcabs" -ge 4 ] && echo "  PASS: $nadcabs adc abs — chain globals read directly" || { echo "  FAIL: expected >=4 adc abs, got $nadcabs"; rc=1; }
[ "$nstazp" -le 3 ] && echo "  PASS: $nstazp sta zp — chains thread A16, no per-add round-trip" || { echo "  FAIL: $nstazp sta zp — chain round-trips through Imag16"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (store + multi-use chains, each + a constant)"
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
emu_verdict "$rc" "constant term folds into a threaded 16-bit add chain and computes 0x2569; both emulators agree"
exit $rc
