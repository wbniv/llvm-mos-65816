#!/usr/bin/env bash
# dev/xy16indiry.sh — #321 xy16 (zp),Y16 16-bit-index indirect-indexed GATE (B2: G_LOAD_INDIR_IDX16).
#
# Sibling to dev/xy16ops.sh (which gates the abs,X16 B2 path, G_LOAD_ABS_IDX16). This
# gates the (zp),Y16 path that was wired but unexercised: a runtime zp pointer + an
# unmasked volatile u16 offset (no 8-bit compile-time proof) must, under +mos-xy16,
# trigger G_LOAD_INDIR_IDX16 and select LDYImag16 + LDIndirYIdx16 (rep #$30; lda (dp),Y
# in 16-bit M/X — opcode B1, no 8-bit iny/dey byte-walk). The offset is 0x102 (>255), so
# a wrongly-8-bit Y reads the wrong address and the differential catches the miscompile.
# Expected corpus_result: 0x7E5A (host == default == +mos-a16 == +mos-xy16, both emulators).
#
# Runs INSIDE the dev container; drive: dev/run.sh xy16indiry. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh xy16indiry   # xy16 (zp),Y16 B2: G_LOAD_INDIR_IDX16 fires; corpus_result==0x7E5A"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/xy16indiry.c"
DROM="$BUILD/xy16indiry_default.sfc"; DMAP="$BUILD/xy16indiry_default.map"
GROM="$BUILD/xy16indiry_a16.sfc";     GMAP="$BUILD/xy16indiry_a16.map"
AROM="$BUILD/xy16indiry_xy16.sfc";    AMAP="$BUILD/xy16indiry_xy16.map"
OBJ="$BUILD/xy16indiry.o"
WANT=0x7E5A
A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-xy16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-xy16 -verify-machineinstrs must compile CLEAN (unmasked 16-bit (zp) offset)"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/xy16indiry.vlog"; then
  echo "  PASS: clean (exit 0)"
else
  echo "  FAIL: backend rejected the build:"; grep -iE "Scavenger|Flag register|SelectImm|fatal|Bad machine|ran out of registers" "$BUILD/xy16indiry.vlog" | head -4; rc=1
fi

echo "==> 2) the indexed access must use G_LOAD_INDIR_IDX16 → LDYImag16+LDIndirYIdx16 (B2 (zp),Y16 gate)"
leg="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -print-after=legalizer -c -o /dev/null "$SRC" 2>&1 || true)"
mir="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -print-after=instruction-select -c -o /dev/null "$SRC" 2>&1 || true)"
nidx16=$(printf '%s\n' "$leg" | grep -ciE 'G_LOAD_INDIR_IDX16' || true)
nldy=$(printf '%s\n' "$mir"  | grep -ciE 'LDYImag16' || true)
nidx=$(printf '%s\n' "$mir"  | grep -ciE 'LDIndirYIdx16' || true)
if [ "$nidx16" -ge 1 ] && [ "$nldy" -ge 1 ] && [ "$nidx" -ge 1 ]; then
  echo "  PASS: $nidx16 G_LOAD_INDIR_IDX16 (legalizer) + $nldy LDYImag16 + $nidx LDIndirYIdx16 (selector) — (zp),Y16 B2 gate fires"
else
  echo "  FAIL: expected G_LOAD_INDIR_IDX16+LDYImag16+LDIndirYIdx16 (nidx16=$nidx16 nldy=$nldy nidx=$nidx) — (zp),Y16 B2 regressed"; rc=1
fi

echo "==> 3) disasm corroboration: native lda (dp),Y (B1) under rep — no 8-bit iny/dey byte-walk"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
nldiy=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*b1\b' || true)          # lda (dp),Y (B1)
niny=$(printf '%s\n' "$DIS"  | grep -ciE '^\s*[0-9a-f]+:\s*(88|c8)\b' || true)     # dey (88) / iny (c8)
[ "$nldiy" -ge 1 ] && echo "  PASS: $nldiy lda (dp),Y (B1) — native indirect-indexed load" \
  || { echo "  FAIL: no lda (dp),Y (B1)"; rc=1; }
[ "$niny" -eq 0 ] && echo "  PASS: no iny/dey (no 8-bit byte-walk)" \
  || { echo "  FAIL: found $niny iny/dey ops — index narrowed to 8-bit"; rc=1; }

echo "==> 4) build default + +mos-a16 + +mos-xy16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816            -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}"  -Os -Wl,-Map="$GMAP" -o "$GROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${XY16[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$DROM" >/dev/null
python3 "$ROOT/tools/snes-checksum.py" "$GROM" >/dev/null
python3 "$ROOT/tools/snes-checksum.py" "$AROM" >/dev/null

echo "==> 5) MAME: host == default == +mos-a16 == +mos-xy16 (corpus_result == $WANT)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
echo "  default:";   run_assert "$DROM" "$DMAP" corpus_result "$WANT" || rc=1
echo "  +mos-a16:";  run_assert "$GROM" "$GMAP" corpus_result "$WANT" || rc=1
echo "  +mos-xy16:"; run_assert "$AROM" "$AMAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> 6) bsnes-jg: +mos-xy16 corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$AMAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$AROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> 6) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — G_LOAD_INDIR_IDX16+LDYImag16+LDIndirYIdx16 (zp),Y16 B2 path under +mos-xy16; corpus_result==$WANT; host==default==+mos-a16==+mos-xy16, both emulators" \
             || echo "RESULT: FAIL"
exit $rc
