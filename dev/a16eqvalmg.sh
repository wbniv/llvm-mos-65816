#!/usr/bin/env bash
# dev/a16eqvalmg.sh — #321 native s16 equality-as-value task7: COMPUTED vs GLOBAL (mixed fold).
# examples/65816/a16eqvalmg.c. One operand is Imag16-resident (computed ALU result) and the
# other is a near-abs global. Now selects CmpBrImagAbs16 (`lda zp_computed; cmp abs_global`)
# instead of materializing the global into an Imag16 pair first. Both orderings are tested:
# `computed == global` (LHS is computed) and `global == computed` (the legalizer swap puts
# computed on LHS so selectBrCondImm's foldableAbsLoad16(RHS16) finds the global). Assertions:
#   1. -verify-machineinstrs clean under +mos-a16.
#   2. DISASM: cmp abs (opcode cd) present (>= 4 sites); NO 8-bit cpx/cpy chain.
#   3. VALUE: corpus_result == 0x0111 host == default == +mos-a16 on MAME + bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16eqvalmg. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-17-321-task7-eq-residuals-indir-dst-xflag-varshift.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16eqvalmg   # computed vs global s16 equality-as-value (CmpBrImagAbs16), corpus_result==0x0111"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16eqvalmg.c"
DROM="$BUILD/a16eqvalmg_default.sfc"; DMAP="$BUILD/a16eqvalmg_default.map"
AROM="$BUILD/a16eqvalmg_a16.sfc";     AMAP="$BUILD/a16eqvalmg_a16.map"
OBJ="$BUILD/a16eqvalmg.o"
WANT=0x0111
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/a16eqvalmg.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/a16eqvalmg.vlog" | head -3; rc=1; }

echo "==> 2) disasm gate: cmp long (opcode cf) for global operand, no 8-bit cpx/cpy"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|cf|cd|e2 20|c5)\b' | head -32
nrep=$(printf '%s\n'    "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
ncmplong=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c[df]\b' || true)  # CMP abs/long = global fold (cf=long, cd=abs)
ncmpzp=$(printf '%s\n'   "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c5\b' || true)     # CMP zp = Imag16 round-trip (cross-block cases)
ncpxy=$(printf '%s\n'    "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(e4|ec|c4|cc)\b' || true)  # 8-bit cpx/cpy
[ "$nrep"     -ge 1 ] && echo "  PASS: $nrep rep #\$20 bracket(s)" || { echo "  FAIL: no rep #\$20 — not native"; rc=1; }
[ "$ncmplong" -ge 2 ] && echo "  PASS: $ncmplong cmp long/abs (cf/cd) — global folded in place for in-block cases" \
  || { echo "  FAIL: expected >=2 cmp long (cf), got $ncmplong — CmpBrImagAbs16 didn't fire"; rc=1; }
[ "$ncmpzp"   -le 2 ] && echo "  PASS: $ncmpzp cmp zp (c5) — at most 2 cross-block fallbacks (e2/e3 expected)" \
  || { echo "  FAIL: found $ncmpzp cmp zp — more fallbacks than expected (>2)"; rc=1; }
[ "$ncpxy"    -eq 0 ] && echo "  PASS: no 8-bit cpx/cpy chain" || { echo "  FAIL: found $ncpxy cpx/cpy — compare narrowed to 8-bit"; rc=1; }

echo "==> 3) build default + +mos-a16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816          -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$DROM" >/dev/null
python3 "$ROOT/tools/snes-checksum.py" "$AROM" >/dev/null

echo "==> 4) MAME: host == default == +mos-a16 (corpus_result == $WANT)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
echo "  default:";  run_assert "$DROM" "$DMAP" corpus_result "$WANT" || rc=1
echo "  +mos-a16:"; run_assert "$AROM" "$AMAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> 5) bsnes-jg: +mos-a16 corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$AMAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$AROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> 5) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
emu_verdict "$rc" "computed vs global s16 equality-as-value (CmpBrImagAbs16: lda zp; cmp long) computes 0x0111; both emulators agree"
exit $rc
