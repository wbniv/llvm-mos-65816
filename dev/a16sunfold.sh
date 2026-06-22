#!/usr/bin/env bash
# dev/a16sunfold.sh — #321 native s16 load-fold (b): single-use-non-store results.
#
# Builds examples/65816/a16sunfold.c with +mos-a16. Each inner 16-bit ALU op has two
# near-abs global operands and a single-use result that does NOT feed a near-abs store,
# so neither combiner peephole fires — selectAlu16Native folds both globals directly
# (`lda abs a; adc|sbc|and abs b`). The gate asserts NO global is materialized into an
# Imag16 pair (`lda abs; sta zp`) and the absolute ALU forms appear. corpus_result ==
# 0x3480 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16sunfold. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-s16-single-use-non-store-fold.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16sunfold   # single-use-non-store fold (both globals read directly), corpus_result==0x3480 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16sunfold.c"
ROM="$BUILD/a16sunfold.sfc"; MAP="$BUILD/a16sunfold.map"; OBJ="$BUILD/a16sunfold.o"
WANT=0x3480
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16sunfold.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: each both-global single-use op reads BOTH operands directly —"
echo "    lda abs (a[df]) + adc/sbc/and/ora/eor abs (6/e/2/0/4 [df]) — and NO global is"
echo "    materialized into an Imag16 pair (lda abs; sta zp adjacency == 0)."
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
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
ndirect=$(( ldabs + absalu ))
echo "  lda-abs=$ldabs  abs-ALU=$absalu  materializations(lda abs;sta zp)=$mat  direct-global-reads=$ndirect"
[ "$mat" -eq 0 ] && echo "  PASS: no global materialized into an Imag16 pair (every operand read in place)" || { echo "  FAIL: $mat lda abs;sta zp round-trips (expected 0)"; rc=1; }
[ "$absalu" -ge 3 ] && echo "  PASS: $absalu absolute ALU ops — second operands folded (>=1 per inner op)" || { echo "  FAIL: only $absalu abs ALU ops (expected >=3)"; rc=1; }
[ "$ndirect" -ge 6 ] && echo "  PASS: $ndirect direct global reads — both operands of each inner op read in place" || { echo "  FAIL: only $ndirect direct global reads (expected >=6)"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (ADD/SUB/AND both-global single-use ops)"
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
emu_verdict "$rc" "both-global single-use-non-store ops read every operand directly (no Imag16 round-trip) and compute 0x3480; both emulators agree"
exit $rc
