#!/usr/bin/env bash
# dev/packed24_table.sh — #320 packed-24 (addrspace 3) Task A: prove a STATIC-initialized
# packed far-pointer TABLE is correct (each link-time 3-byte entry carries its bank byte)
# AND smaller than the AS_Far baseline. Builds examples/65816/packed24/packed24_table.c
# against snes-far (64 KiB, banks $00+$01) with -mcpu=mosw65816 +mos-a16, two ways:
#   * default  -> PACKED table (8 * 3 = 24 B)
#   * -DUSE_FAR -> AS_Far table (8 * 4 = 32 B)   (the storage baseline)
# Walks the 8-entry table at runtime, sums the bank-$01 derefs -> 0xFF, ^0x5A = 0xA5.
# If any entry's bank byte were dropped in the 3-byte packing, that deref reads bank $00
# -> the sum is wrong -> != 0xA5. Gate = host-expected == +mos-a16 on MAME (+ bsnes-jg
# via dev/run.sh xcheck).
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh packed24_table.
# See docs/plans/2026-06-21-320-packed24-productionization-handoff.md (Task A).
set -euo pipefail

usage() { echo "Usage: dev/run.sh packed24_table   # static packed far-ptr table: correct (bank byte survives) + 24 B vs 32 B; boot MAME, assert == 0xA5"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/packed24/packed24_table.c"
ROM="$BUILD/packed24_table.sfc"
MAP="$BUILD/packed24_table.map"
ROM_FAR="$BUILD/packed24_table_far.sfc"
MAP_FAR="$BUILD/packed24_table_far.map"
OBJ="$BUILD/packed24_table.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0xA5   # 0x01|0x02|...|0x80 = 0xFF ; 0xFF ^ 0x5A = 0xA5

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# Robust table-size read: llvm-nm --print-size on the object (the symbol size = 8*elt).
# The container's awk is mawk (no strtonum), so pull the hex size with awk and convert
# with bash 16# arithmetic.
OBJ_FAR="$BUILD/packed24_table_far.o"
tblsz() { local h; h="$("$TOOL/llvm-nm" --print-size "$1" | awk '/ table$/ { print $2; exit }')"; echo "$((16#$h))"; }

echo "==> compile+link PACKED table -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"

echo "==> compile AS_Far baseline (-DUSE_FAR) for the storage delta"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -DUSE_FAR -mllvm -verify-machineinstrs -c -o "$OBJ_FAR" "$SRC"
for o in "$OBJ" "$OBJ_FAR"; do
  "$TOOL/llvm-objdump" -h "$o" >/dev/null 2>&1 \
    || { echo "FAIL: -verify-machineinstrs emitted no real object for $(basename "$o") (vacuous verify)"; exit 1; }
done

rc=0
PSZ=$(tblsz "$OBJ"); FSZ=$(tblsz "$OBJ_FAR")
echo "==> storage gate: packed table 8*3=24 B vs AS_Far 8*4=32 B"
if [ "${PSZ:-0}" -eq 24 ] && [ "${FSZ:-0}" -eq 32 ]; then
  echo "  PASS: packed=$PSZ B vs far=$FSZ B  (saved $((FSZ-PSZ)) B, $(( (FSZ-PSZ)*100/FSZ ))%)"
else echo "  FAIL: packed=${PSZ:-?} far=${FSZ:-?} (expected 24 vs 32)"; rc=1; fi

echo "==> disasm gate: packed table deref is far indirect-long (A7 = lda [dp])"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"   # $OBJ already built in the storage gate
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*a7 ' && echo "  PASS: far deref via LDA IndirectLong (a7)" || { echo "  FAIL: no A7 far deref"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (build/storage/disasm gate)"; exit 1; }

echo "==> execution gate: boot PACKED ROM in MAME, assert corpus_result == $WANT (8 bank-\$01 reads via the static packed table)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "static packed far-ptr table (8x3=24 B, each entry's bank \$01 survives) walked + summed == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
