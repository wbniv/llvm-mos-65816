#!/usr/bin/env bash
# dev/farbank.sh — #321 Phase 2 inc 1 GATE: `lda [dp],y` (b7) ACROSS A BANK BOUNDARY.
#
# The constant-displacement fold (docs/plans/2026-09-25-dpy-indexed-phase2-increment1.md) replaces a
# 32-bit pointer add with `[dp],Y`. That is only correct because the 65816 adds Y to the FULL 24-bit
# pointer and carries INTO the bank byte — unlike `(dp),Y`, which wraps inside the bank. Nothing else
# in the tree tests that: `dev/run.sh farindex`'s tbl is uint16_t based at $C10000, so an element
# read is always 2-byte aligned and can never straddle $xxFFFF.
#
# examples/65816/farbank.c reads farindex's own generated table through a BYTE pointer as an
# unaligned 32-bit value at two offsets whose four bytes straddle a bank boundary — so Y = 1, 2, 3
# (the whole folded window) are exercised and Y = 2, 3 are the carry into the next bank:
#
#   byteoff 65534  -> $C1FFFE $C1FFFF | $C20000 $C20001     ($C1 -> $C2)
#   byteoff 131070 -> $C2FFFE $C2FFFF | $C30000 $C30001     ($C2 -> $C3)
#
# The offsets are chosen so a wrap-inside-the-bank defect CANNOT alias into the right answer:
# golden 0x00010000, a wrapping `[dp],Y` folds to 0x80000001.
#
# a16-only (no default leg): a far pointer is a 32-bit value, so the far load needs +mos-a16 —
# exactly like farindex and the far_* tests. The differential is host == +mos-a16 on MAME + bsnes-jg.
#
#   1. CLEAN + FOLDED: +mos-a16 -verify clean; tbl far-addressed (R_MOS_ADDR24); the access uses
#      `lda [dp]` (A7) for byte 0 AND `lda [dp],y` (B7) for bytes 1..3 — i.e. the fold actually fired.
#   2. HOST ORACLE: cc -DHOST reproduces the golden 0x00010000 (the value contract's closed form).
#   3. DIFFERENTIAL: corpus_result == 0x00010000 for host == +mos-a16 on MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh farbank. Prereqs: from-source toolchain + SDK
# built WITH platforms/snes-hirom. bsnes-jg reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh farbank   # [dp],y (b7) across a bank boundary: unaligned 32-bit far reads straddling \$C1/\$C2 and \$C2/\$C3 fold corpus_result==0x00010000 host==+mos-a16 (MAME+bsnes-jg)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/farbank.c"
LUTASM="$BUILD/farbank_tbl.s"   # own path: farindex generates the same table, but concurrently writing one file would race
AROM="$BUILD/farbank_a16.sfc"; AMAP="$BUILD/farbank_a16.map"
OBJ="$BUILD/farbank.o"
HOSTBIN="$BUILD/farbank_host"
WANT=0x00010000
A16=(-Xclang -target-feature -Xclang +mos-a16)
HIROMCFG="$INSTALL/bin/mos-snes-hirom.cfg"
# Same tiny settle budget as farindex: main() does 8 far loads + a fold and stores corpus_result
# almost immediately.
export SMOKE_SETTLE="${SMOKE_SETTLE:-120}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-4}"
JG_FRAMES="${JG_FRAMES:-240}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$HIROMCFG" ] || { echo "FATAL: snes-hirom platform not built (rebuild SDK: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 0) generate the far table asm (tbl[i] = (i + (i>>16)) & 0xFFFF, 3 banks \$C1..\$C3)"
python3 "$ROOT/tools/gen-farindex-lut-asm.py" "$LUTASM"

echo "==> 1) +mos-a16 -verify clean + the [dp],y fold fired"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs \
  -c -o "$OBJ" "$SRC" 2>"$BUILD/farbank.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/farbank.vlog" | head -3; rc=1; }
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
# here-strings (not `printf ... | grep -q`): under `set -o pipefail`, grep -q exits on the first
# match, SIGPIPEs the upstream printf, and pipefail then reports the (matching!) check as failed.
grep -q 'R_MOS_ADDR24_BANK.*tbl' <<< "$DIS" \
  && echo "  PASS: tbl accessed via 24-bit far address (R_MOS_ADDR24_BANK tbl)" \
  || { echo "  FAIL: tbl not far-addressed"; rc=1; }
grep -qiE '^\s*[0-9a-f]+:\s*a7\b' <<< "$DIS" \
  && echo "  PASS: far load (lda [dp], a7) present — displacement 0 stays unindexed" \
  || { echo "  FAIL: no lda [dp]"; rc=1; }
nb7="$(grep -ciE '^\s*[0-9a-f]+:\s*b7\b' <<< "$DIS" || true)"
[ "$nb7" -ge 6 ] \
  && echo "  PASS: $nb7 indexed far loads (lda [dp],y, b7) — 2 probes x Y=1,2,3 folded" \
  || { echo "  FAIL: only $nb7 lda [dp],y (want >= 6) — the constant-displacement fold did not fire"; rc=1; }

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
emu_verdict "$rc" "unaligned 32-bit far reads straddling banks \$C1/\$C2 and \$C2/\$C3 via lda [dp],y fold to $WANT, host == +mos-a16 (both emulators)"
exit $rc
