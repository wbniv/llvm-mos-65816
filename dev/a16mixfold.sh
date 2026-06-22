#!/usr/bin/env bash
# dev/a16mixfold.sh — #321 native s16 mixed-operand load-fold (one global + one local).
#
# Builds examples/65816/a16mixfold.c with +mos-a16. Each 16-bit ALU op mixes a single-use
# near-abs global (a16v) with a multi-use Imag16 local (loc). With the selectAlu16Native
# fold the global is read directly — `lda abs` when it is the LHS, or `adc|sbc|and|ora|eor
# abs` when it is the ALU operand — so a16v is NEVER materialized into an Imag16 pair
# (`lda abs; sta zp`). The only such materialization is loc's own one-time init from
# `seed`. corpus_result == 0x2DC0 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16mixfold. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-s16-mixed-operand-load-fold.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16mixfold   # mixed-operand load-fold (global read directly), corpus_result==0x2DC0 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16mixfold.c"
ROM="$BUILD/a16mixfold.sfc"; MAP="$BUILD/a16mixfold.map"; OBJ="$BUILD/a16mixfold.o"
WANT=0x2DC0
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16mixfold.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: the global (a16v) is read directly in each of the 6 mixed ops —"
echo "    lda abs/long (a[df]) as LHS, or adc/sbc/and/ora/eor abs/long (6/e/2/0/4 [df]) as"
echo "    operand — and is NEVER materialized into an Imag16 pair (lda abs; sta zp); the"
echo "    only such round-trip is loc's one-time init from seed."
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
# Count, over the instruction stream: lda-abs (a[df]), abs/long ALU ops, and the
# `lda abs; sta zp` (a[df] immediately followed by 85) materialization adjacency.
# Both the absolute (Xd) and absolute-long (Xf) forms count: a near-global operand reads
# as abs since the 0007 near-abs relaxation fix (was long pre-fix); the gate only cares
# the global is read DIRECTLY (in place), not which relaxation form it took.
read -r ldabs absalu mat < <(printf '%s\n' "$DIS" | awk '
  /^[[:space:]]*[0-9a-f]+:[[:space:]]*[0-9a-f][0-9a-f] / {
    line=$0; sub(/^[^:]*:[ \t]*/,"",line); op=substr(line,1,2);
    if ((prev=="af"||prev=="ad") && op=="85") mat++;
    if (op ~ /^(6[df]|e[df]|2[df]|0[df]|4[df])$/) absalu++;
    if (op=="af"||op=="ad") ldabs++;
    prev=op;
  }
  END { printf "%d %d %d\n", ldabs+0, absalu+0, mat+0 }')
# Direct global reads = lda-abs-as-LHS (af not part of a materialization) + abs ALU ops.
ndirect=$(( (ldabs - mat) + absalu ))
echo "  lda-abs=$ldabs  abs-ALU=$absalu  materializations(lda abs;sta zp)=$mat  direct-global-reads=$ndirect"
[ "$mat" -eq 1 ] && echo "  PASS: a16v never materialized into an Imag16 pair (sole lda abs;sta zp is loc init)" || { echo "  FAIL: $mat lda abs;sta zp round-trips (expected 1 = loc init only)"; rc=1; }
[ "$ndirect" -ge 6 ] && echo "  PASS: $ndirect direct global reads — each of the 6 mixed ops reads a16v in place" || { echo "  FAIL: only $ndirect direct global reads (expected >=6)"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (ADD/SUB-both-ways/AND/OR/XOR mixed)"
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
emu_verdict "$rc" "mixed-operand ALU reads the global directly (no Imag16 round-trip) and computes 0x2DC0; both emulators agree"
exit $rc
