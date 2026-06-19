#!/usr/bin/env bash
# dev/a16absidx.sh — #321 native 16-bit abs,x indexed load (`lda abs,x` in M16).
#
# Builds examples/65816/a16absidx.c with +mos-a16. A 16-bit indexed read through an
# 8-bit byte offset must compile to ONE native `rep #$20; lda abs,x; sep #$20`
# (opcode BD) — NOT the 4-op 8-bit byte-pair `lda abs,x; sta lo; lda abs+1,x; sta hi`.
# corpus_result == 0x9ABC (LE short at g_bytes[4]) on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16absidx. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-18-321-abs-x-indiry-16bit-indexed-load-store.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16absidx   # 16-bit abs,x indexed load (lda abs,x in M16, no byte pair); corpus_result==0x9ABC both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16absidx.c"
ROM="$BUILD/a16absidx.sfc"; MAP="$BUILD/a16absidx.map"; OBJ="$BUILD/a16absidx.o"
WANT=0x9ABC
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16absidx.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: native 16-bit lda abs[_long],x (BD or BF) under rep — no byte-pair"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|bd|bf|9d|9f)\b' | head -20
nrep=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
# BD = lda abs,x (16-bit base); BF = lda abs_long,x (24-bit base). SNES globals use
# 24-bit addressing so the linker promotes BD -> BF (same mechanism as LDAbs16 AD->AF).
nldax=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*b[df]\b' || true)  # lda abs[_long],x
[ "$nrep" -ge 1 ] && echo "  PASS: $nrep rep #\$20 bracket(s) — native 16-bit indexed access" \
  || { echo "  FAIL: no rep #\$20"; rc=1; }
[ "$nldax" -ge 1 ] && echo "  PASS: $nldax lda abs[_long],x (16-bit indexed load, opcode BD or BF)" \
  || { echo "  FAIL: no lda abs[_long],x (BD/BF) — byte-pair path still used"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT"
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
emu_verdict "$rc" "native 16-bit abs,x load (lda abs[_long],x / opcode BD/BF) reads 0x9ABC; both emulators agree"
exit $rc
