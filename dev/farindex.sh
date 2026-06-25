#!/usr/bin/env bash
# dev/farindex.sh — #320 "far data > 2 banks" GATE. A const FAR uint16_t tbl[] spanning HiROM
# banks $C1/$C2/$C3 (98304 x uint16 = 192 KiB in .far_rodata) is read at three runtime (volatile)
# indices — 100/50000/90000 — that land in three DISTINCT banks, folded to corpus_result. Proves
# far load/store works across MORE than two banks (the deferred-past-Inc-3 case), formalizing what
# dev/run.sh k_trig32lut exercised as a side-effect on the real ~200 KiB sin LUT.
# examples/65816/farindex.c + tools/gen-farindex-lut-asm.py + platforms/snes-hirom. Plan:
# docs/plans/2026-06-26-formalize-far-data-2-banks-into-a-dedicated-passin.md.
#
# Depends on the clang far-subscript fix (patches/llvm-mos/0001): before it, a far array index
# >= 32768 truncated to 16 bits and mis-addressed the bank (this file was the BUG repro).
#
# a16-only (no default leg): a far pointer is a 32-bit value, so the far load needs +mos-a16 —
# exactly like the far_* tests. The differential is host == +mos-a16 on MAME + bsnes-jg.
#
#   1. CLEAN + FAR: +mos-a16 -verify clean; tbl lands in .far_rodata ($C1+); the access uses
#      R_MOS_ADDR24 + `lda [dp]` (A7).
#   2. HOST ORACLE: cc -DHOST reproduces the golden 0x0001D8A1 (the value contract closed form).
#   3. DIFFERENTIAL: corpus_result == 0x0001D8A1 for host == +mos-a16 on MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh farindex. Prereqs: from-source toolchain
# (with the 0001 clang fix) + SDK built WITH platforms/snes-hirom. bsnes-jg reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh farindex   # far data > 2 banks: a const FAR tbl[] across banks \$C1/\$C2/\$C3 (snes-hirom) read at 3 runtime indices via lda [dp] folds corpus_result==0x0001D8A1 host==+mos-a16 (MAME+bsnes-jg)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/farindex.c"
LUTASM="$BUILD/farindex_tbl.s"
AROM="$BUILD/farindex_a16.sfc"; AMAP="$BUILD/farindex_a16.map"
OBJ="$BUILD/farindex.o"
HOSTBIN="$BUILD/farindex_host"
WANT=0x0001D8A1
A16=(-Xclang -target-feature -Xclang +mos-a16)
HIROMCFG="$INSTALL/bin/mos-snes-hirom.cfg"
# Tiny settle budget: main() does 3 far loads + a fold and stores corpus_result almost
# immediately (no heavy compute), so the window can be far smaller than k_trig32lut's 720/14/900.
export SMOKE_SETTLE="${SMOKE_SETTLE:-120}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-4}"
JG_FRAMES="${JG_FRAMES:-240}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$HIROMCFG" ] || { echo "FATAL: snes-hirom platform not built (rebuild SDK: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 0) generate the far table asm (tbl[i] = (i + (i>>16)) & 0xFFFF, 3 banks \$C1..\$C3)"
python3 "$ROOT/tools/gen-farindex-lut-asm.py" "$LUTASM"

echo "==> 1) +mos-a16 -verify clean + far table (R_MOS_ADDR24 + lda [dp])"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs \
  -c -o "$OBJ" "$SRC" 2>"$BUILD/farindex.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/farindex.vlog" | head -3; rc=1; }
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
# here-strings (not `printf ... | grep -q`): under `set -o pipefail`, grep -q exits on the first
# match, SIGPIPEs the upstream printf, and pipefail then reports the (matching!) check as failed.
grep -q 'R_MOS_ADDR24_BANK.*tbl' <<< "$DIS" \
  && echo "  PASS: tbl accessed via 24-bit far address (R_MOS_ADDR24_BANK tbl)" \
  || { echo "  FAIL: tbl not far-addressed (the clang far-subscript fix missing?)"; rc=1; }
grep -qiE '^\s*[0-9a-f]+:\s*a7\b' <<< "$DIS" \
  && echo "  PASS: far load (lda [dp], a7) present" \
  || { echo "  FAIL: no far load opcode"; rc=1; }

echo "==> 2) host oracle reproduces the golden ($WANT)"
if command -v cc >/dev/null 2>&1; then
  cc -DHOST -O2 -o "$HOSTBIN" "$SRC"
  hostval="$("$HOSTBIN")"
  [ "$hostval" = "$WANT" ] \
    && echo "  PASS: host oracle corpus_result=$hostval == golden $WANT" \
    || { echo "  FAIL: host oracle=$hostval != golden $WANT"; rc=1; }
else
  echo "  SKIP: no host cc; trusting documented golden $WANT"
fi

echo "==> 3) build the +mos-a16 HiROM ROM (far table) + HiROM checksum"
"$TOOL/mos-clang" --config "$HIROMCFG" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$AMAP" -o "$AROM" "$SRC" "$LUTASM"
python3 "$ROOT/tools/snes-checksum.py" --hirom "$AROM" >/dev/null

echo "==> 4) MAME: host == +mos-a16 (corpus_result == $WANT)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
echo "  +mos-a16:"; run_assert "$AROM" "$AMAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> 5) bsnes-jg: +mos-a16 corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$AMAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$AROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" "$JG_FRAMES" 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> 5) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
emu_verdict "$rc" "far table spanning 3 banks (\$C1/\$C2/\$C3) read via lda [dp] folds to $WANT, host == +mos-a16 (both emulators)"
exit $rc
