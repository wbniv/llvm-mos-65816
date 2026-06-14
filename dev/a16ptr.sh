#!/usr/bin/env bash
# dev/a16ptr.sh — #321 native 16-bit indirect load/store (`*p`, `a[i]`, `a[i]=v`).
#
# Builds examples/65816/a16ptr.c with +mos-a16. A 16-bit value through a runtime
# pointer must compile to ONE native 16-bit indirect op — `rep #$20; lda (zp)` /
# `sta (zp); sep #$20` (opcodes B2 / 92) — NOT two 8-bit indirect ops
# (lda (zp); lda (zp),y). corpus_result == 0xABCE (0xABCD stored via *p, read back,
# +1) on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16ptr. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-16bit-indirect-load-store.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16ptr   # 16-bit indirect load/store (lda (zp)/sta (zp) in M16, no byte pair); corpus_result==0xABCE both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16ptr.c"
ROM="$BUILD/a16ptr.sfc"; MAP="$BUILD/a16ptr.map"; OBJ="$BUILD/a16ptr.o"
WANT=0xABCE
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16ptr.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: native 16-bit lda (zp)/sta (zp) under rep/sep — no (zp),y byte pair"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|b2|92|b1|91)\b' | head -20
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nldai=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*b2\b' || true)        # lda (zp)
nstai=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*92\b' || true)        # sta (zp)
nidxy=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(b1|91)\b' || true)   # lda/sta (zp),y byte pair
[ "$nrep" -ge 2 ] && echo "  PASS: $nrep rep #\$20 bracket(s) — native 16-bit indirect access" || { echo "  FAIL: expected >=2 rep #\$20, got $nrep"; rc=1; }
[ "$nldai" -ge 1 ] && echo "  PASS: $nldai lda (zp) (16-bit indirect load)" || { echo "  FAIL: no lda (zp) (b2)"; rc=1; }
[ "$nstai" -ge 1 ] && echo "  PASS: $nstai sta (zp) (16-bit indirect store)" || { echo "  FAIL: no sta (zp) (92)"; rc=1; }
[ "$nidxy" -eq 0 ] && echo "  PASS: no (zp),y byte pair (fully native 16-bit)" || { echo "  FAIL: found $nidxy (zp),y ops — access narrowed to 8-bit"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0xABCD via *p, read back, +1)"
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
[ $rc -eq 0 ] && echo "RESULT: PASS — native 16-bit indirect load/store (lda (zp)/sta (zp)) round-trips 0xABCE; both emulators agree" \
             || echo "RESULT: FAIL"
exit $rc
