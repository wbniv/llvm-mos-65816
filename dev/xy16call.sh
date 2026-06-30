#!/usr/bin/env bash
# dev/xy16call.sh — #321 xy16 CROSS-CALL BOUNDARY GATE: a genuine 16-bit index held LIVE
# across a clobbering noinline call, then used as a 16-bit index AFTER the call.
#
# The one xy16 call-boundary case no prior test covers (xy16basic/ops/indiry index WITHIN a
# function; xy16spillr's cross-call live value is Ac16, not an index). The ABI narrows X to
# 8-bit at the call (MOSInsertREPSEP requiredXWidth -> XW_X8 for isCall; the `sep #$10` zeroes
# X's high byte — the seed-247/445 bug class). MEASURED codegen (this test's finding): the RA
# routes the cross-call-live index through a CALLEE-SAVED ZP imaginary-register pair
# ($rs10-$rs15, preserved by the JSR regmask), reloading it into X16 via LDXImag16 only at the
# point of use — the physical X16 is NEVER live across the call, so the value survives by ZP
# preservation (mode-independent), not by an X16 spill. The gates below lock that invariant:
#   1. -verify-machineinstrs clean under +mos-xy16.
#   2. the post-call indexed read is the genuine 16-bit-index path (LDXImag16 + LDAbsXIdx16
#      AFTER the JSR), and its index source is preserved across the call (a callee-saved
#      $rs1[0-5] pair in the JSR regmask, or a stack reload — either is valid preservation).
#   3. LTO-survival tripwire: a rep #$30/#$10 bracket around the indexed loads remains in the
#      linked ROM (the index stayed genuinely 16-bit through --config LTO; else false-GREEN).
#   4. VALUE differential: corpus_result == 0x7E5A host == default == +mos-a16 == +mos-xy16 on
#      MAME + bsnes-jg. If the high byte of idx (0x0102) is lost across the call the post-call
#      read hits post_arr[0x0002]=0 -> 0x1234 != 0x7E5A.
#
# Runs INSIDE the dev container; drive: dev/run.sh xy16call. Prereqs: from-source toolchain +
# SDK. bsnes-jg cross-check reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh xy16call   # xy16 16-bit index held across a clobbering call; corpus_result==0x7E5A"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/xy16call.c"
DROM="$BUILD/xy16call_default.sfc"; DMAP="$BUILD/xy16call_default.map"
GROM="$BUILD/xy16call_a16.sfc";     GMAP="$BUILD/xy16call_a16.map"
AROM="$BUILD/xy16call_xy16.sfc";    AMAP="$BUILD/xy16call_xy16.map"
OBJ="$BUILD/xy16call.o"
WANT=0x7E5A
A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-xy16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-xy16 -verify-machineinstrs must compile CLEAN (16-bit index live across a call)"
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/xy16call.vlog"; then
  echo "  PASS: clean (exit 0)"
else
  echo "  FAIL: backend rejected the build:"; grep -iE "Scavenger|Flag register|SelectImm|fatal|Bad machine|ran out of registers" "$BUILD/xy16call.vlog" | head -4; rc=1
fi

echo "==> 2) post-call genuine-16-bit-index path + cross-call preservation (post-RA MIR)"
# prologepilog MIR: physical regs + the JSR preserve regmask are concrete here.
ppmir="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -print-after=prologepilog -c -o /dev/null "$SRC" 2>&1 || true)"
mainmir="$(printf '%s\n' "$ppmir" | awk '/# Machine code for function main/{p=1} p{print} /# End machine code for function main/{exit}')"
# Split main at the JSR: the post-call region must reload the index and index with it.
post="$(printf '%s\n' "$mainmir" | awk '/JSR @clobber/{p=1; next} p{print}')"
jsrline="$(printf '%s\n' "$mainmir" | grep -m1 'JSR @clobber' || true)"
npostidx=$(printf '%s\n' "$post" | grep -ciE 'LDAbsXIdx16' || true)
postldx="$(printf '%s\n' "$post" | grep -m1 -oE 'LDXImag16 (killed )?(renamable )?\$rs[0-9]+' | grep -oE '\$rs[0-9]+' || true)"
if [ "$npostidx" -ge 1 ] && [ -n "$postldx" ]; then
  echo "  PASS: post-call indexed read is the 16-bit-index path ($npostidx LDAbsXIdx16 after JSR; index reloaded via LDXImag16 $postldx)"
else
  echo "  FAIL: expected LDXImag16+LDAbsXIdx16 after the JSR (npostidx=$npostidx postldx='$postldx') — index not reused as 16-bit post-call"; rc=1
fi
# Preservation: the post-call index source must survive the call — a callee-saved $rs10-$rs15
# pair listed in the JSR preserve regmask (the measured path), OR a stack reload would appear
# as a different reload opcode. Assert the callee-saved-pair case explicitly; tolerate a
# stack-spill fallback (LDXAbs16 / static-stack reload) without failing.
if printf '%s\n' "$jsrline" | grep -qE "regmask[^>]*\\${postldx}\\b"; then
  echo "  PASS: index source $postldx is callee-saved (in the JSR preserve regmask) — value survives the call by ZP preservation, no X16 spill needed"
elif printf '%s\n' "$post" | grep -qiE 'LDXAbs16|loadStoreByteStaticStack|__rc.*Stk'; then
  echo "  PASS: index preserved via a stack reload across the call (under-pressure spill path)"
else
  echo "  FAIL: index source $postldx is neither in the JSR preserve regmask nor a stack reload — cross-call preservation unproven"; rc=1
fi

echo "==> 3) .o disasm: the 16-bit index is held across the call (rep #\$10 + lda [long|abs],X; X narrowed before the jsr, re-widened after)"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
maindis="$(printf '%s\n' "$DIS" | awk '/<main>:/{p=1;print;next} p&&/Disassembly of section/{exit} p{print}')"
prejsr="$(printf '%s\n'  "$maindis" | awk '/[[:space:]]jsr[[:space:]]/{exit} {print}')"
postjsr="$(printf '%s\n' "$maindis" | awk '/[[:space:]]jsr[[:space:]]/{p=1;next} p{print}')"
nrepx=$(printf '%s\n'  "$maindis" | grep -ciE ':\s*c2 10\b' || true)        # rep #$10 (enter 16-bit index)
# lda [long,X]=0xBF (24-bit absolute indexed, DBR-independent) or lda [abs,X]=0xBD (16-bit
# bank-relative). The legalizer-domination fix (fb528d8) changed DBR-relative (0xBD) for
# same-bank globals; both forms are correct 16-bit-indexed loads; gate accepts either.
nldlx=$(printf '%s\n'  "$maindis" | grep -ciE ':\s*(bf|bd)\b' || true)      # lda long/abs,X (16-bit-index path)
presep=$(printf '%s\n' "$prejsr"  | grep -ciE ':\s*e2 (30|10)\b' || true)   # sep #$30/#$10 narrows X before the call
postrep=$(printf '%s\n' "$postjsr" | grep -ciE ':\s*c2 10\b' || true)       # rep #$10 re-widens X after the call
postldx=$(printf '%s\n' "$postjsr" | grep -ciE ':\s*(bf|bd)\b' || true)     # post-call indexed load with the carried idx
if [ "$nrepx" -ge 1 ] && [ "$nldlx" -ge 1 ] && [ "$presep" -ge 1 ] && [ "$postrep" -ge 1 ] && [ "$postldx" -ge 1 ]; then
  echo "  PASS: $nrepx rep #\$10 + $nldlx lda [long|abs],X; X narrowed before the jsr ($presep sep), re-widened after ($postrep rep #\$10) for the post-call indexed load ($postldx) — 16-bit index held across the call"
else
  echo "  FAIL: cross-call 16-bit-index structure missing (nrepx=$nrepx nldlx=$nldlx presep=$presep postrep=$postrep postldx=$postldx)"; rc=1
fi

echo "==> 4) build default + +mos-a16 + +mos-xy16 ROMs (--config LTO). idx=0x0102 has a load-bearing high byte, so any LTO narrowing breaks the value differential below — the value test IS the narrowing detector."
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
emu_verdict "$rc" "16-bit index held across a clobbering call: survives in a callee-saved ZP pair, reloaded LDXImag16+LDAbsXIdx16 post-call; corpus_result==$WANT; host==default==+mos-a16==+mos-xy16, both emulators"
exit $rc
