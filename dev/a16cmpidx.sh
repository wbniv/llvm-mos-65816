#!/usr/bin/env bash
# dev/a16cmpidx.sh — #321 native 16-bit RHS-indexed unsigned-ordering compares.
#
# Builds examples/65816/a16cmpidx.c with +mos-a16. A single-use indexed element
# `arr[k]`/`p[k]` on the RHS of an unsigned-ordering compare folds into one
# `cmp (zp)` (CMPIndir16, opcode $D2) under a rep/sep bracket — instead of staging
# the value through an Imag16 temp (`lda (zp); sta __rc; lda lim; cmp __rc`). The
# `lim > arr[k]` cases swap arr[k] to the LHS (the already-optimal `lda (zp); cmp lim`,
# opcode $B2). The 0x0099-vs-0x0200 pair proves all 16 bits compare. corpus_result
# == 0x1111 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16cmpidx. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-19-321-native-s16-16-bit-indexed-comparisons-rhs-cmp.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16cmpidx   # RHS-indexed compare fold (cmp (zp)=\$D2), corpus_result==0x1111 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16cmpidx.c"
ROM="$BUILD/a16cmpidx.sfc"; MAP="$BUILD/a16cmpidx.map"; OBJ="$BUILD/a16cmpidx.o"
WANT=0x1111
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-14s %6s bytes\n' a16cmpidx.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: each RHS-indexed compare folds to cmp (zp) (\$D2) under rep/sep —"
echo "    NOT a staged lda (zp); sta \$__rc; lda lim; cmp \$__rc, and NOT an 8-bit cpx/cpy chain"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
nfold=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*d2\b' || true)   # cmp (zp) — the fold
ncpxy=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(e4|ec|c4|cc)\b' || true) # 8-bit cpx/cpy chain
[ "$nrep"  -ge 1 ] && echo "  PASS: $nrep rep #\$20 bracket(s) — 16-bit compares" || { echo "  FAIL: no rep #\$20"; rc=1; }
[ "$nfold" -ge 5 ] && echo "  PASS: $nfold cmp (zp) folds (one per RHS-indexed compare, value read in place)" || { echo "  FAIL: expected >=5 cmp (zp) folds, got $nfold — staging not eliminated"; rc=1; }
[ "$ncpxy" -eq 0 ] && echo "  PASS: no 8-bit cpx/cpy compare-chain (fully native 16-bit)" || { echo "  FAIL: found $ncpxy cpx/cpy — compare narrowed to 8-bit"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (RHS < folds + > swapped-to-LHS + high-byte-differs)"
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
emu_verdict "$rc" "native 16-bit RHS-indexed compare fold (cmp (zp)) computes 0x1111; both emulators agree"
exit $rc
