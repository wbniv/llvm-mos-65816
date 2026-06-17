#!/usr/bin/env bash
# dev/a16ret.sh — #321: lock the A (low) / X (high) RETURN CONVENTION as a tested,
# differential-regression-guarded ABI invariant. TEST + DOCS ONLY (no codegen change).
# examples/65816/a16ret.c. Plan: docs/plans/2026-06-17-321-ax-return-convention.md.
#
# Two assertions:
#   1. CONVENTION (disasm gate, +mos-a16, symbolic -S): the i16 return (add16) leaves the
#      LOW byte in A and the HIGH byte in X at the rts boundary — `ldx <high>; lda <low>;
#      rts`, with the X-load reading the imaginary-reg byte one HIGHER than the A-load
#      (high->X, low->A, byte-pinned). The i8 return (add8) delivers its result in A
#      alone — no X load at the return boundary. A later RetCC/A16/xy16 change that moves
#      the boundary trips this gate (forces a conscious update) instead of silently
#      breaking the ABI. (The +mos-a16 return round-trip optimization is a NON-GOAL — see
#      the plan/.c header; it may deliberately update this gate.)
#   2. VALUE (differential): corpus_result == 0x2387 host == default == +mos-a16 on
#      MAME + bsnes-jg. (The value test alone CANNOT catch an A<->X swap — production and
#      consumption would swap together and still round-trip — which is precisely why the
#      disasm gate above exists.)
#
# Runs INSIDE the dev container; drive: dev/run.sh a16ret. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16ret   # lock A(low)/X(high) return convention: i16->ldx<high>;lda<low>;rts, i8->A; corpus_result==0x2387"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16ret.c"
DROM="$BUILD/a16ret_default.sfc"; DMAP="$BUILD/a16ret_default.map"
AROM="$BUILD/a16ret_a16.sfc";     AMAP="$BUILD/a16ret_a16.map"
OBJ="$BUILD/a16ret.o"
ASM="$BUILD/a16ret.s"
WANT=0x2387
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/a16ret.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/a16ret.vlog" | head -3; rc=1; }
[ $rc -eq 0 ] && echo "  PASS: +mos-a16 compiles clean (-verify-machineinstrs)"

echo "==> 2) return-convention disasm gate (+mos-a16, symbolic -S): i16 -> ldx<high>;lda<low>;rts, i8 -> A"
# Symbolic assembly: named labels (add16:/add8:) + symbolic imaginary-reg operands
# (__rcN) — the .o would print zp operands as $0 relocation stubs, hiding the byte order.
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -S -o "$ASM" "$SRC"

# Trimmed instruction lines of a function, from its label to the first `rts` (inclusive):
# strip trailing comments, blank lines, .directives, and nested labels; keep mnemonics.
fn_body() { awk -v fn="$1" '
  $0 ~ ("^" fn ":") { g=1; next }
  g {
    l=$0; sub(/;.*/,"",l); gsub(/^[ \t]+|[ \t]+$/,"",l); gsub(/[ \t]+/," ",l)
    if (l=="" || l ~ /^\./ || l ~ /:$/) next
    print l
    if (l ~ /^rts$/) exit
  }' "$ASM"; }

# --- i16 return (add16): boundary must be `ldx <high>; lda <low>; rts`, byte-pinned ---
A16TAIL="$(fn_body add16 | tail -3)"
g1="$(printf '%s\n' "$A16TAIL" | sed -n '1p')"   # expect: ldx __rc<hi>
g2="$(printf '%s\n' "$A16TAIL" | sed -n '2p')"   # expect: lda __rc<lo>
g3="$(printf '%s\n' "$A16TAIL" | sed -n '3p')"   # expect: rts
xhi="$(printf '%s' "$g1" | grep -oE '__rc[0-9]+' | grep -oE '[0-9]+' || true)"
xlo="$(printf '%s' "$g2" | grep -oE '__rc[0-9]+' | grep -oE '[0-9]+' || true)"
if [ "${g1%% *}" = "ldx" ] && [ "${g2%% *}" = "lda" ] && [ "$g3" = "rts" ] \
   && [ -n "$xhi" ] && [ -n "$xlo" ] && [ "$xhi" -eq "$((xlo + 1))" ]; then
  echo "  PASS: i16 return boundary 'ldx __rc$xhi; lda __rc$xlo; rts' — HIGH byte->X, LOW byte->A (byte-pinned: X reads __rc$xhi = __rc$xlo+1)"
else
  echo "  FAIL: i16 return boundary expected 'ldx <high>; lda <low>; rts' with X reading the byte above A. Got:"; printf '          %s\n' "$A16TAIL"; rc=1
fi

# --- i8 return (add8): result in A alone; no X load at the return boundary ---
A8TAIL="$(fn_body add8 | tail -3)"
if printf '%s\n' "$A8TAIL" | grep -qE '^(ldx|tax)\b'; then
  echo "  FAIL: i8 return boundary loads X — i8 result must be delivered in A alone. Got:"; printf '          %s\n' "$A8TAIL"; rc=1
elif printf '%s\n' "$A8TAIL" | grep -q '^rts$'; then
  echo "  PASS: i8 return boundary delivers the result in A (no X load as a return register; value confirmed below)"
else
  echo "  FAIL: i8 return: no rts boundary found. Got:"; printf '          %s\n' "$A8TAIL"; rc=1
fi

echo "==> 3) build default + +mos-a16 ROMs"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816          -Os -Wl,-Map="$DMAP" -o "$DROM" "$SRC"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os -Wl,-Map="$AMAP" -o "$AROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$DROM" >/dev/null
python3 "$ROOT/tools/snes-checksum.py" "$AROM" >/dev/null

echo "==> 4) MAME: host == default == +mos-a16 (corpus_result == $WANT)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
echo "  default:";  run_assert "$DROM" "$DMAP" corpus_result "$WANT" || rc=1
echo "  +mos-a16:"; run_assert "$AROM" "$AMAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> 5) bsnes-jg: +mos-a16 corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$AMAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$AROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> 5) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — A(low)/X(high) return convention is locked: i16->ldx<high>;lda<low>;rts, i8->A; corpus_result==0x2387 (both emulators)" \
             || echo "RESULT: FAIL"
exit $rc
