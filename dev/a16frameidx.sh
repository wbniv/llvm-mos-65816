#!/usr/bin/env bash
# dev/a16frameidx.sh — #321 regression for the eliminateFrameIndex / CmpBrAbsImm16
# frame-index scramble (root-caused via c-torture 20071210-1; the one-line fix cleared 13
# differential miscompiles). Builds examples/65816/a16frameidx.c with +mos-a16 LTO, where a
# stack-resident s[6] compared element-by-element against constants folds each
# load+compare+branch into the static/zero-page-stack CmpBrAbsImm16 pseudo. The buggy
# MOSRegisterInfo::eliminateFrameIndex read the displacement from the operand after the
# frame index (the COMPARE immediate) instead of the frame index's own offset, so every
# s[i] read resolved to base+compareImm rather than base+2*i. Fixed: the checks pass and
# corpus_result == 0x4321 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16frameidx. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build). bsnes-jg
# cross-check reuses build/jgxcheck (built by dev/run.sh xcheck).
# See docs/plans/2026-06-19-321-cmpbrabsimm16-frameindex-elimination-scramble.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16frameidx   # build a16frameidx.c +mos-a16 LTO, assert static-stack CmpBrAbsImm16 compares + corpus_result==0x4321 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16frameidx.c"
ROM="$BUILD/a16frameidx.sfc"; MAP="$BUILD/a16frameidx.map"
WANT=0x4321
A16=(-Xclang -target-feature -Xclang +mos-a16)
# -O1: the static/zero-page-stack CmpBrAbsImm16 fold (and thus the bug) is reached at -O1;
# -O0 / per-TU route stack locals through LDStk, where no frame-index CmpBrAbsImm16 forms.
OPT=-O1

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16 $OPT, LTO) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" "$OPT" \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-16s %6s bytes\n' a16frameidx.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate (post-LTO): check() reads s[] over the static/zp stack via >=6 folded compares"
# The bug is LTO-only (the static/zero-page stack is assigned whole-program), so gate on the
# post-LTO asm, not a per-TU .o. A separate --lto-emit-asm link writes <out>.lto.s; its
# binary may be unusable (we only want the asm), hence the throwaway -o and `|| true`.
GATE="$BUILD/a16frameidx.gate"; GATEASM="$GATE.sfc.lto.s"
rm -f "$GATEASM"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" "$OPT" \
  -o "$GATE.sfc" "$SRC" -Wl,--lto-emit-asm -Wl,--save-temps >/dev/null 2>&1 || true
if [ -f "$GATEASM" ]; then
  CHK="$(awk '/^check:/{f=1} f{print} /\.size[ \t]+check/{f=0}' "$GATEASM")"
  nstk=$(printf '%s\n' "$CHK" | grep -ciE '_zp_stk|_sstk' || true)
  ncmp=$(printf '%s\n' "$CHK" | grep -ciE '^[[:space:]]*cmp[[:space:]]+#' || true)
  printf '%s\n' "$CHK" | grep -iE '_zp_stk|_sstk|cmp[[:space:]]+#' | head
  [ "$nstk" -ge 1 ] && echo "  PASS: check() uses the static/zero-page stack ($nstk refs)" || { echo "  FAIL: check() not on the static stack (bug path not exercised)"; rc=1; }
  [ "$ncmp" -ge 6 ] && echo "  PASS: >=6 folded immediate compares (the six s[i] checks)" || { echo "  FAIL: expected >=6 'cmp #', got $ncmp (compares not folded -> bug path not exercised)"; rc=1; }
  rm -f "$GATE".sfc* 2>/dev/null || true
else
  echo "  SKIP: post-LTO asm not emitted ($GATEASM missing) — relying on the value differential"
fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (each s[i] read at frame+2*i, not frame+compareImm)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> bsnes-jg: assert corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then
    echo "  $line"
  else echo "  $line"; rc=1; fi
else
  echo "==> bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
emu_verdict "$rc" "stack s[i] compared at frame+2*i (not frame+compareImm) -> 0x4321; both emulators agree"
exit $rc
