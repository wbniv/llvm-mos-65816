#!/usr/bin/env bash
# dev/a16eqvalg.sh — #321 native s16 equality-as-value v3: ABS-OPERAND FOLD for GLOBALS.
# examples/65816/a16eqvalg.c. An s16 `g1 == g2` used as a VALUE now reads BOTH globals
# in place — `rep; lda abs; cmp abs; sep; beq/bne` + 0/1 — instead of round-tripping each
# global through an Imag16 pair or narrowing to the 8-bit cpx/cmp chain. Mirror of
# selectSbc16 / a16abscmp on the equality path. Three assertions:
#   1. -verify-machineinstrs clean under +mos-a16.
#   2. DISASM: `cmp abs` present (globals read directly), NO `cmp zp` (no Imag16 RHS
#      round-trip) and NO 8-bit `cpx`/`cpy` byte chain (fully native 16-bit).
#   3. VALUE: corpus_result == 0x0101 host == default == +mos-a16 on MAME + bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16eqvalg. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-17-321-native-s16-eq-as-value-v3-abs-fold-globals.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16eqvalg   # global s16 equality-as-value abs-fold (lda abs/cmp abs), corpus_result==0x0101"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16eqvalg.c"
DROM="$BUILD/a16eqvalg_default.sfc"; DMAP="$BUILD/a16eqvalg_default.map"
AROM="$BUILD/a16eqvalg_a16.sfc";     AMAP="$BUILD/a16eqvalg_a16.map"
OBJ="$BUILD/a16eqvalg.o"
WANT=0x0101
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/a16eqvalg.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/a16eqvalg.vlog" | head -3; rc=1; }

echo "==> 2) disasm gate: both globals read in place (lda abs; cmp abs), no Imag16"
echo "    round-trip (cmp zp c5), no 8-bit cpx/cpy chain (e4/ec/c4/cc)"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|af|ad|cf|cd|c5|f0|d0)\b' | head -24
nrep=$(printf '%s\n'  "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
ncmpabs=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c[df]\b' || true)   # cmp abs/long (global RHS read directly)
ncmpzp=$(printf '%s\n'  "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c5\b' || true)      # cmp zp = Imag16 round-trip
ncpxy=$(printf '%s\n'   "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(e4|ec|c4|cc)\b' || true)  # 8-bit cpx/cpy chain
[ "$nrep" -ge 1 ]    && echo "  PASS: $nrep rep #\$20 bracket(s) — native 16-bit compares" || { echo "  FAIL: no rep #\$20 — not native"; rc=1; }
[ "$ncmpabs" -ge 2 ] && echo "  PASS: $ncmpabs cmp abs/long (g1==g2 globals read directly)" || { echo "  FAIL: expected >=2 cmp abs, got $ncmpabs — abs-fold didn't fire"; rc=1; }
[ "$ncmpzp" -eq 0 ]  && echo "  PASS: no cmp zp — no global round-tripped through an Imag16 pair" || { echo "  FAIL: found $ncmpzp cmp zp — a global still goes through Imag16"; rc=1; }
[ "$ncpxy" -eq 0 ]   && echo "  PASS: no 8-bit cpx/cpy compare-chain (fully native 16-bit)" || { echo "  FAIL: found $ncpxy cpx/cpy — compare narrowed to 8-bit"; rc=1; }

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
[ $rc -eq 0 ] && echo "RESULT: PASS — global s16 equality-as-value folds the operand (lda abs; cmp abs) and computes 0x0101; both emulators agree" \
             || echo "RESULT: FAIL"
exit $rc
