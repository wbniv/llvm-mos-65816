#!/usr/bin/env bash
# dev/far_loop.sh — #321: prove a far (addrspace 2) pointer used as a LOOP
# INDUCTION VARIABLE compiles and runs. A far pointer carried across a loop
# back-edge forms a G_PHI(p2); the MOS legalizer made G_PHI legal only for
# {s1,s8,p0,p1}, so a far-ptr IV loop ABORTED the backend ("unable to legalize
# ... G_PHI (p2)"). The fix (MOSLegalizerInfo::legalizePhi) custom-legalizes a
# far-pointer phi to an s32 phi (ptrtoint each incoming value, inttoptr the
# result back), the same bridge far load/store + legalizePtrAdd use.
#
# The test advances by a RUNTIME stride (p += s, s==1 at runtime but opaque to
# the optimizer) so the far-ptr phi SURVIVES indvars/LSR to the legalizer at
# -Os/-O2 — a plain unit-stride p++ is strength-reduced to an integer index and
# would compile even without the fix.
#
# Gate: (1) the program COMPILES at all (pre-fix this aborted) and the far-ptr
# IV loops lower to indirect-long far accesses (sta [dp] / lda [dp]); (2) execution
# at BOTH -Os and -O2 — fill HIGH WRAM ($7E2000) via a far-ptr IV write loop
# (hi[i]=i), read it back via a far-ptr IV load loop and SUM -> corpus_result ==
# 0xC9 (sum(0..49)=1225 & 0xFF; a wrong-bank write reads back wrong, changing the
# sum). Host-expected == +mos-a16 on MAME (here) + bsnes-jg (dev/run.sh xcheck);
# the default 8-bit build can't hold a 32-bit far pointer as a register value.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_loop.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# See docs/plans/2026-06-26-fix-the-far-pointer-g-phi-p2-backend-gap.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_loop   # build examples/65816/far_loop.c (snes, +mos-a16) at -Os/-O2, boot in MAME, assert a far-ptr IV loop fills bank \$7E (corpus_result == 0xC9)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_loop.c"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0xC9   # sum(0..49) = 1225 & 0xFF

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0
echo "==> compile gate: a far-ptr INDUCTION-VARIABLE loop compiles (pre-fix this aborted: G_PHI(p2))"
OBJ="$BUILD/far_loop.o"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/far_loop.cc.log"; then
  echo "  PASS: compiled (no 'unable to legalize ... G_PHI (p2)' abort)"
else
  echo "  FAIL: compile aborted:"; sed 's/^/    /' "$BUILD/far_loop.cc.log" | head; rc=1
fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (compile gate)"; exit 1; }

echo "==> disasm gate: far-ptr IV accesses lower to indirect-long (sta [dp] / lda [dp])"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
if printf '%s\n' "$DIS" | grep -qE '\bsta\s+\[' && printf '%s\n' "$DIS" | grep -qE '\blda\s+\['; then
  echo "  PASS: far indirect-long store + load present (sta [dp] / lda [dp])"
else
  echo "  FAIL: expected far indirect-long sta [dp] + lda [dp]:"; printf '%s\n' "$DIS" | grep -nE '\b(sta|lda)\b' | head; rc=1
fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

source "$ROOT/dev/_emu.sh"
require_bios || exit $?

for OPT in -Os -O2; do
  ROM="$BUILD/far_loop${OPT}.sfc"
  MAP="$BUILD/far_loop${OPT}.map"
  echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes.cfg -mcpu=mosw65816 +mos-a16 $OPT)"
  "$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" "$OPT" \
    -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$ROM"
  echo "==> execution gate ($OPT): boot in MAME, assert corpus_result == $WANT (far-ptr IV write+read-back)"
  if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
    echo "  PASS ($OPT)"
  else
    emu_verdict 1 ""; exit 1
  fi
done

emu_verdict 0 "far-pointer induction-variable write+read-back loops fill bank \$7E at -Os and -O2; read back == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
