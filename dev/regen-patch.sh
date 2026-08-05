#!/usr/bin/env bash
# dev/regen-patch.sh — regenerate patches/llvm-mos/0002-321-accum16.patch from the
# live (directly-edited) vendor/llvm-mos tree, via the isolated-worktree method.
#
# vendor/llvm-mos is gitignored and edited in place; its HEAD is pristine upstream
# (dev/toolchain.sh clones pristine then `git apply`s the patches WITHOUT
# committing). So the tracked source of truth for our backend changes is the patch
# series, which must be regenerated whenever the live tree changes.
#
# Method (baseline = pristine vendor HEAD + 0001 + 0003 committed):
#   1. fresh detached worktree at pristine HEAD;
#   2. apply 0001 (the #320 far-pointer patch) AND 0003 (the upstream-bound
#      mos-late-opt fix, if present) and commit them — this becomes the baseline so
#      the regenerated 0002 captures ONLY the accum16 delta. 0003 lives inside
#      llvm/lib/Target/MOS (MOSLateOptimization.cpp), so without it in the baseline
#      the mirror+diff below would wrongly absorb that edit into 0002;
#
#   ⚠ STALE BASELINE (2026-07-31): 0018-320-imag32-spill and
#     0019-mos-branch-range-diagnostic were historically omitted here. They
#     depend on the existing 0002 and therefore cannot be baked into a pristine
#     baseline. The current method mirrors live, then reverse-applies every
#     standalone patch in reverse stack order before deriving the new 0002.
#   3. mirror the live llvm/lib/Target/MOS dir over the worktree (all 0002 files
#      live there) with rsync --delete;
#   4. `git diff --cached` against the baseline -> 0002 (0003's MOSLateOptimization.cpp
#      is byte-identical in baseline and mirror, so it drops out of the diff).
# Then round-trip verify: apply 0001+the new 0002+0003 to another pristine worktree
# and `diff -rq` its MOS dir against the live vendor MOS dir — they must be identical.
# 0003 is optional: once it merges upstream and the vendor pin is bumped, drop the
# patch file and this script keeps regenerating 0002 unchanged.
#
# Runs on the HOST (needs git + rsync; no container). See the #321 plans.
set -euo pipefail

usage() { echo "Usage: dev/regen-patch.sh   # regenerate + round-trip-verify patches/llvm-mos/0002-321-accum16.patch"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/llvm-mos"
PATCHES="$ROOT/patches/llvm-mos"
P1="$PATCHES/0001-320-far-addrspace.patch"
P2="$PATCHES/0002-321-accum16.patch"
P3="$PATCHES/0003-late-opt-nongpr-ldimm-dest.patch"  # upstream-bound mos-late-opt fix; optional (dropped once merged)
MOSREL="llvm/lib/Target/MOS"

# Standalone upstream-bound patches that live INSIDE $MOSREL and are therefore
# absorbed into 0002 by the mirror+diff below unless they are in the baseline.
# Each is optional (dropped once it merges upstream and the vendor pin is bumped).
STANDALONE_MOSDIR=(
  "$PATCHES/0018-320-imag32-spill.patch"
  "$PATCHES/0019-mos-branch-range-diagnostic.patch"
  "$PATCHES/0020-mos-65816-block-move-bank-order.patch"
  "$PATCHES/0021-mos-zp-alloc-deterministic.patch"
  "$PATCHES/0022-mos-late-opt-cmpzero-lowering.patch"
  "$PATCHES/0023-mos-trunc-selection-regclasses.patch"
  "$PATCHES/0024-mos-brk-signature-operand.patch"
  "$PATCHES/0025-llvm-mc-preserve-motorola-default.patch"
)
TESTRELS=(
  "llvm/test/CodeGen/MOS/interrupt-width-65816.ll"
  "llvm/test/MC/MOS/all-65816-opcodes.s"
  "llvm/test/MC/MOS/motorola-integers-default.s"
)

[ -d "$VENDOR/.git" ] || { echo "FATAL: no vendor/llvm-mos checkout (run dev/run.sh toolchain)"; exit 1; }
command -v rsync >/dev/null || { echo "FATAL: rsync not found"; exit 1; }

PRISTINE="$(git -C "$VENDOR" rev-parse HEAD)"
echo "==> pristine vendor HEAD: $(git -C "$VENDOR" rev-parse --short HEAD)"

WT_GEN="$(mktemp -d)"; WT_VFY="$(mktemp -d)"
cleanup() {
  git -C "$VENDOR" worktree remove --force "$WT_GEN" 2>/dev/null || true
  git -C "$VENDOR" worktree remove --force "$WT_VFY" 2>/dev/null || true
  rm -rf "$WT_GEN" "$WT_VFY"
}
trap cleanup EXIT

GIT_ID=(-c user.email=patchgen@local -c user.name=patchgen)

echo "==> [gen] worktree @ pristine + commit 0001 (+0003) as baseline"
git -C "$VENDOR" worktree add --detach "$WT_GEN" "$PRISTINE" >/dev/null
git -C "$WT_GEN" apply "$P1"
[ -f "$P3" ] && { echo "    baking 0003 into baseline so it drops out of 0002"; git -C "$WT_GEN" apply "$P3"; }
git -C "$WT_GEN" add -A
git "${GIT_ID[@]}" -C "$WT_GEN" commit -q -m "0001(+0003) baseline"

echo "==> [gen] mirror live $MOSREL over the baseline, diff -> 0002"
rsync -a --delete "$VENDOR/$MOSREL/" "$WT_GEN/$MOSREL/"
for rel in "${TESTRELS[@]}"; do
  cp "$VENDOR/$rel" "$WT_GEN/$rel"
done
# The live mirror contains the post-0002 standalone patches. Remove them from
# the generation tree in reverse application order so the regenerated 0002
# remains the holistic +mos-a16 body and toolchain.sh can still apply each
# standalone artifact afterward.
for ((i=${#STANDALONE_MOSDIR[@]}-1; i>=0; i--)); do
  p="${STANDALONE_MOSDIR[$i]}"
  [ -f "$p" ] || continue
  echo "    reversing $(basename "$p") out of the 0002 generation tree"
  includes=(--include="$MOSREL/*")
  for rel in "${TESTRELS[@]}"; do includes+=(--include="$rel"); done
  git -C "$WT_GEN" apply --reverse "${includes[@]}" "$p"
done
git -C "$WT_GEN" add -A
git -C "$WT_GEN" diff --cached > "$P2"
# Empty context lines are conventionally emitted as a single space. Strip that
# marker so the patch artifact itself also passes the parent repo's whitespace
# check; git apply accepts the unmarked empty context lines.
sed -i 's/^ $//' "$P2"
echo "    wrote $P2 ($(wc -l < "$P2") lines, $(grep -c '^diff --git' "$P2") files)"

echo "==> [verify] apply 0001 + new 0002 (+0003) to a fresh pristine worktree"
git -C "$VENDOR" worktree add --detach "$WT_VFY" "$PRISTINE" >/dev/null
git -C "$WT_VFY" apply "$P1"
git -C "$WT_VFY" apply "$P2"
[ -f "$P3" ] && git -C "$WT_VFY" apply "$P3"   # 0003 restores MOSLateOptimization.cpp to the live (fixed) state
for p in "${STANDALONE_MOSDIR[@]}"; do
  [ -f "$p" ] && git -C "$WT_VFY" apply "$p"
done

echo "==> [verify] diff -rq reapplied MOS dir vs live vendor MOS dir"
if diff -rq "$WT_VFY/$MOSREL" "$VENDOR/$MOSREL"; then
  for rel in "${TESTRELS[@]}"; do
    diff -q "$WT_VFY/$rel" "$VENDOR/$rel"
  done
  echo "RESULT: PASS — 0002 round-trips (MOS dir + focused tests == live vendor)"
else
  echo "RESULT: FAIL — round-trip mismatch (see diff above)"; exit 1
fi
