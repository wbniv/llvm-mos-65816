#!/usr/bin/env bash
# dev/a16abscmp.sh — #321 native 16-bit compare-operand fold (lda abs / cmp abs).
#
# Builds examples/65816/a16abscmp.c with +mos-a16. Every compare is global-vs-global,
# so both operands are near-abs 16-bit loads. With the selectSbc16 fold each `if`
# compiles to `rep; lda abs; cmp abs; sep; bcc/bcs` — the global RHS is read directly
# by `cmp abs` (no `cmp zp` off a materialized Imag16 pair) and the LHS by `lda abs`
# (no `lda abs; sta tmp` round-trip). corpus_result == 0x4303 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16abscmp. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-16bit-compare-abs-operand-fold.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16abscmp   # 16-bit compare-operand fold (lda abs/cmp abs), corpus_result==0x4303 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16abscmp.c"
ROM="$BUILD/a16abscmp.sfc"; MAP="$BUILD/a16abscmp.map"; OBJ="$BUILD/a16abscmp.o"
WANT=0x4303
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16abscmp.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: each compare reads BOTH globals directly — lda abs; cmp abs"
echo "    (cmp abs/long cd/cf); NO cmp zp (c5, RHS materialized into Imag16) and NO"
echo "    8-bit cpx/cpy chain (e4/ec/c4/cc)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|af|cf|cd|c5|90|b0)\b' | head -20
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
ncmpabs=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c[df]\b' || true)   # cmp abs/long
ncmpzp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c5\b' || true)       # cmp zp = Imag16 RHS
ncpxy=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(e4|ec|c4|cc)\b' || true) # 8-bit cpx/cpy chain
[ "$nrep" -ge 1 ] && echo "  PASS: $nrep rep #\$20 bracket(s) — 16-bit compares" || { echo "  FAIL: no rep #\$20"; rc=1; }
[ "$ncmpabs" -ge 4 ] && echo "  PASS: $ncmpabs cmp abs/long (RHS global read directly, one per compare)" || { echo "  FAIL: expected >=4 cmp abs, got $ncmpabs"; rc=1; }
[ "$ncmpzp" -eq 0 ] && echo "  PASS: no cmp zp — RHS never materialized into an Imag16 pair" || { echo "  FAIL: found $ncmpzp cmp zp — RHS still goes through Imag16"; rc=1; }
[ "$ncpxy" -eq 0 ] && echo "  PASS: no 8-bit cpx/cpy compare-chain (fully native 16-bit)" || { echo "  FAIL: found $ncpxy cpx/cpy — compare narrowed to 8-bit"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (four true orderings + high-byte-differs case)"
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
[ $rc -eq 0 ] && echo "RESULT: PASS — 16-bit compare folds both global operands (lda abs; cmp abs) and computes 0x4303; both emulators agree" \
             || echo "RESULT: FAIL"
exit $rc
