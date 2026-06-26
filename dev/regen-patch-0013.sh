#!/usr/bin/env bash
# dev/regen-patch-0013.sh — regenerate patches/llvm-mos/0013-320-far-memops.patch
# from the live (directly-edited) vendor/llvm-mos tree.
#
# What 0013 is: the #320 far (addrspace 2) memset/memcpy/memmove correctness fix.
# A far memop the backend can't inline-expand (variable size, or constant size over
# MOSLegalizerInfo's SizeLimit) used to fall through legalizeMemOp into the generic
# createMemLibcall, which calls the NEAR runtime (__memset/memcpy, 16-bit char*)
# while passing the 32-bit far pointer — the bank byte was silently dropped, a
# wrong-bank store/load. 0013 adds two static helpers to MOSLegalizerInfo.cpp
# (anyFarPointerOperand + createFarMemLibcall) and a divert in legalizeMemOp that
# routes far memops to the far runtime (__memset_far/__memcpy_far/__memmove_far,
# defined in the tracked platforms/snes/mem-far.c overlay). Touches only
# MOSLegalizerInfo.cpp; the runtime + test live in the main repo, not in a patch.
#
# MOSLegalizerInfo.cpp is a SHARED file (0001/0002/0005/0006 also edit it), so 0013
# is captured by the delta method: reconstruct pristine + 0001..0012, overlay the
# live MOSLegalizerInfo.cpp, and diff — that delta is exactly the new far-memops
# hunks (legalizeMemOp/createMemLibcall are otherwise untouched by any patch).
#
# 0013 = (live) - (pristine + 0001..0012), restricted to the single file it touches.
# Runs on the HOST (needs git + diff; no container).
# See docs/plans/2026-06-26-fix-the-far-addrspace-2-memset-memcpy-memmove-sile.md.
set -euo pipefail

usage() { echo "Usage: dev/regen-patch-0013.sh   # regenerate + round-trip-verify patches/llvm-mos/0013-320-far-memops.patch"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/llvm-mos"
PATCHES="$ROOT/patches/llvm-mos"
PSTACK=(
  "$PATCHES/0001-320-far-addrspace.patch"
  "$PATCHES/0002-321-accum16.patch"
  "$PATCHES/0003-late-opt-txy-dead-flag.patch"
  "$PATCHES/0004-320-far-cc.patch"
  "$PATCHES/0005-320-far-ptr-value-legalize.patch"
  "$PATCHES/0006-320-packed24.patch"
  "$PATCHES/0007-65816-near-abs-bank-relax.patch"
  "$PATCHES/0008-mos-dp-arg-cc.patch"
  "$PATCHES/0009-321-a16-pressure-incdec.patch"
  "$PATCHES/0010-coalesce-rotate-ac.patch"
  "$PATCHES/0011-mos-scavenger-live-p-save.patch"
  "$PATCHES/0012-mos-ldcimm-set-lowering.patch"
)
P13="$PATCHES/0013-320-far-memops.patch"

# The single file 0013 modifies. Diff'd individually so foreign WIP elsewhere never leaks in.
MEMOP_FILES=(
  "llvm/lib/Target/MOS/MOSLegalizerInfo.cpp"
)

[ -d "$VENDOR/.git" ] || { echo "FATAL: no vendor/llvm-mos checkout (run dev/run.sh toolchain)"; exit 1; }
PRISTINE="$(git -C "$VENDOR" rev-parse HEAD)"
echo "==> pristine vendor HEAD: $(git -C "$VENDOR" rev-parse --short HEAD)"

WT=""
cleanup() {
  [ -n "$WT" ] && git -C "$VENDOR" worktree remove --force "$WT" 2>/dev/null || true
  git -C "$VENDOR" worktree prune 2>/dev/null || true
  [ -n "$WT" ] && rm -rf "$WT"
}
trap cleanup EXIT
GIT_ID=(-c user.email=patchgen@local -c user.name=patchgen)
mkwt() { WT="$(mktemp -d)"; git -C "$VENDOR" worktree add --detach "$WT" "$PRISTINE" >/dev/null; }
rmwt() { git -C "$VENDOR" worktree remove --force "$WT" 2>/dev/null || true; rm -rf "$WT"; WT=""; }

apply_stack() { for p in "${PSTACK[@]}"; do [ -f "$p" ] && git -C "$WT" apply "$p"; done; }

echo "==> [gen] baseline = pristine + 0001..0012; overlay live MOSLegalizerInfo.cpp; diff"
mkwt
apply_stack
git -C "$WT" add -A
git "${GIT_ID[@]}" -C "$WT" commit -q -m "stack baseline (0001-0012)"
for f in "${MEMOP_FILES[@]}"; do cp "$VENDOR/$f" "$WT/$f"; done
git -C "$WT" diff > "$P13"
echo "    wrote $P13 ($(wc -l < "$P13") lines, $(grep -c '^diff --git' "$P13") files)"
rmwt

echo "==> [verify] pristine + 0001..0013 reproduces the live $MEMOP_FILES exactly"
mkwt
apply_stack
git -C "$WT" apply "$P13"
rc=0
for f in "${MEMOP_FILES[@]}"; do
  if ! diff -q "$WT/$f" "$VENDOR/$f" >/dev/null 2>&1; then
    echo "  MISMATCH $f"; rc=1
  fi
done
rmwt
if [ $rc -eq 0 ]; then
  echo "RESULT: PASS — 0013 round-trips (0001..0013 reproduces MOSLegalizerInfo.cpp)"
else
  echo "RESULT: FAIL — round-trip mismatch"; exit 1
fi
