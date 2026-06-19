#!/usr/bin/env bash
# dev/xy16spillr.sh — #321 xy16 soft-stack spill gate: +mos-xy16 (implies +mos-a16) must
# not break the Ac16 soft-stack spill path (MOSRegisterInfo::expandLDSTStk) updated in
# Layer 4. A recursive function spills an Ac16 value to the soft stack; the new IsXc16/
# IsYc16 booleans (inert at this source level) and the extended pointer-forming guard must
# not disturb the Ac16 path. Expected corpus_result: 0x3457.
#
# Parallel to dev/a16spillr.sh; differs only in the feature flag (+mos-xy16 vs +mos-a16).
# Runs INSIDE the dev container; drive: dev/run.sh xy16spillr.
# Prereqs: from-source toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh xy16spillr   # xy16 soft-stack Ac16 spill: corpus_result==0x3457 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/xy16spillr.c"
DROM="$BUILD/xy16spillr_default.sfc"; DMAP="$BUILD/xy16spillr_default.map"
AROM="$BUILD/xy16spillr_xy16.sfc";   AMAP="$BUILD/xy16spillr_xy16.map"
WANT=0x3457
XY16=(-Xclang -target-feature -Xclang +mos-xy16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-xy16 -verify-machineinstrs must compile CLEAN (soft-stack Ac16 spill under +mos-xy16)"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$BUILD/xy16spillr.o" "$SRC" 2>"$BUILD/xy16spillr.vlog"; then
  echo "  PASS: clean (exit 0)"
else
  echo "  FAIL: backend rejected the build:"; grep -iE "Scavenger|Flag register|SelectImm|fatal|Bad machine" "$BUILD/xy16spillr.vlog" | head -4; rc=1
fi

echo "==> 2) the indexed access must use LDXImag16+LDAbsXIdx16 (Increment 1e gate: no Imag16→Xc16 COPY)"
mir="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -print-after=instruction-select -c -o /dev/null "$SRC" 2>&1 || true)"
nldx=$(printf '%s\n' "$mir" | grep -ciE 'LDXImag16' || true)
nidx=$(printf '%s\n' "$mir" | grep -ciE 'LDAbsXIdx16|STAbsXIdx16' || true)
if [ "$nldx" -ge 1 ] && [ "$nidx" -ge 1 ]; then
  echo "  PASS: $nldx LDXImag16 + $nidx LDAbsXIdx16/STAbsXIdx16 — Increment 1e indexed path fires, no Imag16→Xc16 COPY crash"
else
  echo "  FAIL: expected LDXImag16 + LDAbsXIdx16 (nldx=$nldx nidx=$nidx) — selectXY16 not firing or regressed"; rc=1
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
emu_verdict "$rc" "LDXImag16+LDAbsXIdx16 indexed access under +mos-xy16; corpus_result==0x3457; both emulators agree"
exit $rc
