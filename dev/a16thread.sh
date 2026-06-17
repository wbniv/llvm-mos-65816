#!/usr/bin/env bash
# dev/a16thread.sh — #321 A16-threading (Phase 1): the redundant Imag16 round-trip
# between two dependent native-s16 ops is eliminated, so the running value threads
# through the accumulator across the chain.
#
# examples/65816/a16thread.c runs a dependent heterogeneous chain (ADD/AND/SUB/OR/
# XOR, single-use intermediates -> fully threaded) plus a reused intermediate
# (store stays, reload drops). The gate: (a) compile clean (-verify-machineinstrs),
# (b) ZERO `sta __rcN ; lda __rcN` store-then-reload round-trips in the native
# chain, (c) corpus_result == 0x2544 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16thread. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck (dev/run.sh xcheck).
# See docs/plans/2026-06-17-321-a16-threading.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16thread   # A16-threading: no Imag16 round-trip + corpus_result==0x2544 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16thread.c"
ROM="$BUILD/a16thread.sfc"; MAP="$BUILD/a16thread.map"; OBJ="$BUILD/a16thread.o"; ASM="$BUILD/a16thread.s"
WANT=0x2544
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0
echo "==> compile-clean gate (-verify-machineinstrs): threaded chain must not crash"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -mllvm -verify-machineinstrs \
     -Os -c -o "$OBJ" "$SRC" 2>"$BUILD/a16thread.cc.err"; then
  echo "  PASS: compiled clean (-verify-machineinstrs)"
else
  echo "  FAIL: compile crashed/failed"; sed -n '1,12p' "$BUILD/a16thread.cc.err"; exit 1
fi

echo "==> threading gate: ZERO 'sta __rcN ; lda __rcN' Imag16 round-trips"
# Symbolic operands need assembly (.o prints zp operands as $0 relocation stubs).
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -S -o "$ASM" "$SRC"
nrt=$(awk '
  /^[[:space:]]*sta[[:space:]]+__rc[0-9]+$/ { prev=$2; have=1; next }
  /^[[:space:]]*lda[[:space:]]+__rc[0-9]+$/ { if (have && $2==prev) n++; have=0; next }
  { have=0 }
  END { print n+0 }' "$ASM")
[ "$nrt" -eq 0 ] && echo "  PASS: 0 store-then-reload round-trips (value threads through A16)" \
                 || { echo "  FAIL: $nrt redundant 'sta __rcN; lda __rcN' round-trip(s) remain"; rc=1; }
# Confirm it really is native 16-bit (the chain ops are present, value in M=16).
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
nbra=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b') # rep #$20
echo "  ($nbra rep #\$20 bracket(s) — native 16-bit chain)"

echo "==> compile+link -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-13s %6s bytes\n' a16thread.sfc "$(stat -c%s "$ROM")"

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
[ $rc -eq 0 ] && echo "RESULT: PASS — A16-threading: no Imag16 round-trip, corpus_result==0x2544 on both emulators" \
             || echo "RESULT: FAIL"
exit $rc
