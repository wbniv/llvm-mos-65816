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
#   2. apply 0001 (the #320 far-pointer patch) AND 0003 (the upstream-bound F4
#      mos-late-opt fix, if present) and commit them — this becomes the baseline so
#      the regenerated 0002 captures ONLY the accum16 delta. 0003 lives inside
#      llvm/lib/Target/MOS (MOSLateOptimization.cpp), so without it in the baseline
#      the mirror+diff below would wrongly absorb the F4 edit into 0002;
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
P3="$PATCHES/0003-late-opt-txy-dead-flag.patch"   # upstream-bound F4 fix; optional (dropped once merged)
MOSREL="llvm/lib/Target/MOS"

# Standalone upstream-bound patches that live INSIDE $MOSREL and are therefore
# absorbed into 0002 by the mirror+diff below unless they are in the baseline.
# Each is optional (dropped once it merges upstream and the vendor pin is bumped).
# NOTE: 0018/0019/0020 are deliberately absent — they are other workers' in-flight
# patches; add them here when their owners fold them in. Until then, do not run
# this script while they are un-landed (see the stale-baseline hazard note in
# docs/plans/2026-08-01-gallery-nonreproducible-build.md).
BASELINE_MOSDIR=(
  "$PATCHES/0021-mos-zp-alloc-deterministic.patch"
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
[ -f "$P3" ] && { echo "    baking 0003 (F4) into baseline so it drops out of 0002"; git -C "$WT_GEN" apply "$P3"; }
for p in "${BASELINE_MOSDIR[@]}"; do
  [ -f "$p" ] || continue
  echo "    baking $(basename "$p") into baseline so it drops out of 0002"
  git -C "$WT_GEN" apply "$p"
done
git -C "$WT_GEN" add -A
git "${GIT_ID[@]}" -C "$WT_GEN" commit -q -m "0001(+0003) baseline"

echo "==> [gen] mirror live $MOSREL over the baseline, diff -> 0002"
rsync -a --delete "$VENDOR/$MOSREL/" "$WT_GEN/$MOSREL/"
git -C "$WT_GEN" add -A
git -C "$WT_GEN" diff --cached > "$P2"
echo "    wrote $P2 ($(wc -l < "$P2") lines, $(grep -c '^diff --git' "$P2") files)"

echo "==> [verify] apply 0001 + new 0002 (+0003) to a fresh pristine worktree"
git -C "$VENDOR" worktree add --detach "$WT_VFY" "$PRISTINE" >/dev/null
git -C "$WT_VFY" apply "$P1"
git -C "$WT_VFY" apply "$P2"
[ -f "$P3" ] && git -C "$WT_VFY" apply "$P3"   # 0003 restores MOSLateOptimization.cpp to the live (F4) state
for p in "${BASELINE_MOSDIR[@]}"; do          # ditto for the other in-baseline MOS-dir patches
  [ -f "$p" ] && git -C "$WT_VFY" apply "$p"
done

echo "==> [verify] diff -rq reapplied MOS dir vs live vendor MOS dir"
if diff -rq "$WT_VFY/$MOSREL" "$VENDOR/$MOSREL"; then
  echo "RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)"
else
  echo "RESULT: FAIL — round-trip mismatch (see diff above)"; exit 1
fi
