#!/usr/bin/env bash
# dev/a16eqvalc.sh — #321 native s16 equality-as-value v2: COMPUTED / Imag16-resident operands.
# examples/65816/a16eqvalc.c. An s16 `(a+b) == (c+d)` used as a VALUE now goes NATIVE 16-bit
# — `rep; lda imag; cmp imag; sep; beq/bne` + 0/1 (CmpBrImag16) — and `(a+b) == 0x1234` folds
# the constant via `cmp #imm` (CmpBrImm16), instead of narrowing to the 8-bit cpx/cmp chain
# even though both operands are already in Imag16. A register/param operand deliberately stays
# 8-bit (the native form would spill it — the +8 B regression the spike measured). Assertions:
#   1. -verify-machineinstrs clean under +mos-a16.
#   2. DISASM: native 16-bit cmp present (cmp zp / cmp #imm), NO 8-bit cpx/cpy chain.
#   3. VALUE: corpus_result == 0x1101 host == default == +mos-a16 on MAME + bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16eqvalc. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-17-321-native-s16-eq-v2-computed-imag16-lhs.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16eqvalc   # computed s16 equality-as-value goes native 16-bit (v2), corpus_result==0x1101"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16eqvalc.c"
DROM="$BUILD/a16eqvalc_default.sfc"; DMAP="$BUILD/a16eqvalc_default.map"
AROM="$BUILD/a16eqvalc_a16.sfc";     AMAP="$BUILD/a16eqvalc_a16.map"
OBJ="$BUILD/a16eqvalc.o"
WANT=0x1101
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

echo "==> 1) +mos-a16 -verify-machineinstrs clean"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC" 2>"$BUILD/a16eqvalc.vlog" \
  || { echo "  FAIL: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/a16eqvalc.vlog" | head -3; rc=1; }

echo "==> 2) disasm gate: computed operands compared natively (cmp zp / cmp #imm), no 8-bit cpx/cpy"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|c5|c9|f0|d0)\b' | head -24
nrep=$(printf '%s\n'  "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b' || true)
ncmp16=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c[59]\b' || true)        # cmp zp / cmp #imm (native 16-bit)
ncmpimm=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c9\b' || true)          # cmp #imm16 (computed==const fold)
ncpxy=$(printf '%s\n'   "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(e4|ec|c4|cc)\b' || true)  # 8-bit cpx/cpy chain
[ "$nrep" -ge 1 ]    && echo "  PASS: $nrep rep #\$20 bracket(s) — native 16-bit compares" || { echo "  FAIL: no rep #\$20 — not native"; rc=1; }
[ "$ncmp16" -ge 2 ]  && echo "  PASS: $ncmp16 native 16-bit cmp ops (computed operands compared in Imag16)" || { echo "  FAIL: expected >=2 native 16-bit cmp, got $ncmp16 — v2 didn't fire"; rc=1; }
[ "$ncmpimm" -ge 1 ] && echo "  PASS: $ncmpimm cmp #imm16 (computed==const folds to cmp #imm)" || { echo "  FAIL: expected >=1 cmp #imm16, got $ncmpimm"; rc=1; }
[ "$ncpxy" -eq 0 ]   && echo "  PASS: no 8-bit cpx/cpy compare-chain (fully native 16-bit)" || { echo "  FAIL: found $ncpxy cpx/cpy — compare narrowed to 8-bit"; rc=1; }

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
emu_verdict "$rc" "computed s16 equality-as-value is native 16-bit (v2) and computes 0x1101; both emulators agree"
exit $rc
