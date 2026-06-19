#!/usr/bin/env bash
# dev/xy16ops.sh — #321 xy16 B2 legalizer gate: unmasked 16-bit index → G_LOAD_ABS_IDX16.
#
# Verifies the B2 legalizer gate in tryAbsoluteIndexedAddressing: a volatile unsigned
# short index (no 8-bit compile-time proof) must trigger G_LOAD_ABS_IDX16 and select
# LDXImag16 + LDAbsXIdx16 (rep #10 / ldx ZP / rep #20 / lda arr,x — no byte-pair load).
# Expected corpus_result: 0x2A42 (arr[42]; value encodes the index in both bytes).
#
# Parallel to dev/xy16spillr.sh; differs in test shape (direct array read, no recursion).
# Runs INSIDE the dev container; drive: dev/run.sh xy16ops.
# Prereqs: from-source toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh xy16ops   # xy16 B2 legalizer: G_LOAD_ABS_IDX16 fires; corpus_result==0x2A42"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/xy16ops.c"
DROM="$BUILD/xy16ops_default.sfc"; DMAP="$BUILD/xy16ops_default.map"
AROM="$BUILD/xy16ops_xy16.sfc";   AMAP="$BUILD/xy16ops_xy16.map"
WANT=0x2A42
XY16=(-Xclang -target-feature -Xclang +mos-xy16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-xy16 -verify-machineinstrs must compile CLEAN (unmasked 16-bit index under +mos-xy16)"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$BUILD/xy16ops.o" "$SRC" 2>"$BUILD/xy16ops.vlog"; then
  echo "  PASS: clean (exit 0)"
else
  echo "  FAIL: backend rejected the build:"; grep -iE "Scavenger|Flag register|SelectImm|fatal|Bad machine" "$BUILD/xy16ops.vlog" | head -4; rc=1
fi

echo "==> 2) the indexed access must use G_LOAD_ABS_IDX16 → LDXImag16+LDAbsXIdx16 (B2 gate)"
leg="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -print-after=legalizer -c -o /dev/null "$SRC" 2>&1 || true)"
mir="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -print-after=instruction-select -c -o /dev/null "$SRC" 2>&1 || true)"
nidx16=$(printf '%s\n' "$leg" | grep -ciE 'G_LOAD_ABS_IDX16' || true)
nldx=$(printf '%s\n' "$mir" | grep -ciE 'LDXImag16' || true)
nidx=$(printf '%s\n' "$mir" | grep -ciE 'LDAbsXIdx16|STAbsXIdx16' || true)
if [ "$nidx16" -ge 1 ] && [ "$nldx" -ge 1 ] && [ "$nidx" -ge 1 ]; then
  echo "  PASS: $nidx16 G_LOAD_ABS_IDX16 (legalizer) + $nldx LDXImag16 + $nidx LDAbsXIdx16 (selector) — B2 gate fires"
else
  echo "  FAIL: expected G_LOAD_ABS_IDX16+LDXImag16+LDAbsXIdx16 (nidx16=$nidx16 nldx=$nldx nidx=$nidx) — B2 regressed"; rc=1
fi

echo "==> 3) build default + +mos-xy16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816          -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${XY16[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$DROM" >/dev/null
python3 "$ROOT/tools/snes-checksum.py" "$AROM" >/dev/null

echo "==> 4) MAME: host == default == +mos-xy16 (corpus_result == $WANT)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
echo "  default:"; run_assert "$DROM" "$DMAP" corpus_result "$WANT" || rc=1
echo "  +mos-xy16:"; run_assert "$AROM" "$AMAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> 5) bsnes-jg: +mos-xy16 corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$AMAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$AROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> 5) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
emu_verdict "$rc" "G_LOAD_ABS_IDX16+LDXImag16+LDAbsXIdx16 B2 path under +mos-xy16; corpus_result==$WANT; both emulators agree"
exit $rc
