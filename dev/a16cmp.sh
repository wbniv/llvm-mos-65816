#!/usr/bin/env bash
# dev/a16cmp.sh — #321 native 16-bit unsigned-ordering compares (< <= > >=).
#
# Builds examples/65816/a16cmp.c with +mos-a16. Each `if (a < b)` etc. compiles to
# a single 16-bit compare — rep #$20; lda; cmp; sep #$20; bcc/bcs — instead of the
# old multi-block 8-bit cpx/cpy chain. The loval<hival case (low byte bigger, high
# byte smaller) proves all 16 bits compare. corpus_result == 0x1103 on BOTH MAME
# and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16cmp. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-14-321-native-16bit-compares.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16cmp   # 16-bit compares (rep/lda/cmp/sep), corpus_result==0x1103 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16cmp.c"
ROM="$BUILD/a16cmp.sfc"; MAP="$BUILD/a16cmp.map"; OBJ="$BUILD/a16cmp.o"
WANT=0x1103
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16cmp.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: each 16-bit compare is a single 16-bit cmp under rep/sep,"
echo "    NOT the old multi-block 8-bit cpx/cpy chain (cpx=e4/ec, cpy=c4/cc)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|c[59df]|90|b0)\b' | head
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
ncmp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c[59df]\b' || true)  # cmp zp/imm/abs/long
ncpxy=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(e4|ec|c4|cc)\b' || true) # 8-bit cpx/cpy chain
[ "$nrep" -ge 1 ] && echo "  PASS: $nrep rep #\$20 bracket(s) — 16-bit compares" || { echo "  FAIL: no rep #\$20"; rc=1; }
[ "$ncmp" -ge 4 ] && echo "  PASS: $ncmp 16-bit cmp ops (one per compare)" || { echo "  FAIL: expected >=4 16-bit cmp, got $ncmp"; rc=1; }
[ "$ncpxy" -eq 0 ] && echo "  PASS: no 8-bit cpx/cpy compare-chain (fully native 16-bit)" || { echo "  FAIL: found $ncpxy cpx/cpy — compare narrowed to 8-bit"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (four orderings + high-byte-differs case)"
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
[ $rc -eq 0 ] && echo "RESULT: PASS — native 16-bit unsigned-ordering compares (rep/lda/cmp/sep/bcc) compute 0x1103; both emulators agree" \
             || echo "RESULT: FAIL"
exit $rc
