#!/usr/bin/env bash
# dev/regen-patch-0005.sh — regenerate patches/llvm-mos/0005-320-far-ptr-value-legalize.patch
# from the live (directly-edited) vendor/llvm-mos tree, via the isolated-worktree method.
#
# 0005 is the lone #320 far-function-pointer (a) backend hunk that is a16-CONTEXT-
# entangled: it adds the far pointer (PF / addrspace 2) as a legal VALUE type for
# G_LOAD/G_STORE (so a far pointer held in a variable can be loaded/stored), editing
# the `if (STI.hasAccum16()) ... customForCartesianProduct(...)` block that 0002
# introduces. It is behaviorally a16-INDEPENDENT (PF is added to BOTH the a16 and the
# non-a16 branch; only W65816 far code ever forms a PF), but its patch context lives in
# 0002's code, so it cannot fold into the a16-free 0001 (0002 would clobber it) — same
# reasoning as 0004 (see regen-patch-0004.sh). It touches ONLY MOSLegalizerInfo.cpp and
# is independent of 0004 (disjoint files), so it stacks last. dev/toolchain.sh applies
# patches/llvm-mos/*.patch in glob order, so 0005 is auto-applied after 0004.
#
# Method (baseline = pristine + 0001 + 0002 + 0003 + 0004, i.e. everything EXCEPT 0005):
#   1. fresh detached worktree at pristine HEAD;
#   2. apply 0001 + 0002 + 0003 + 0004 and commit -> baseline;
#   3. diff the live MOSLegalizerInfo.cpp against the baseline -> 0005 (its only file);
# Then round-trip verify: apply the full 0001..0005 series to another pristine worktree
# and `diff -rq` its MOS dir against the live vendor MOS dir — identical.
#
# Runs on the HOST (needs git; no container). See
# docs/plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md.
set -euo pipefail

usage() { echo "Usage: dev/regen-patch-0005.sh   # regenerate + round-trip-verify patches/llvm-mos/0005-320-far-ptr-value-legalize.patch"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/llvm-mos"
PATCHES="$ROOT/patches/llvm-mos"
P1="$PATCHES/0001-320-far-addrspace.patch"
P2="$PATCHES/0002-321-accum16.patch"
P3="$PATCHES/0003-late-opt-txy-dead-flag.patch"   # optional
P4="$PATCHES/0004-320-far-cc.patch"
P5="$PATCHES/0005-320-far-ptr-value-legalize.patch"
MOSREL="llvm/lib/Target/MOS"
LEG="$MOSREL/MOSLegalizerInfo.cpp"

[ -d "$VENDOR/.git" ] || { echo "FATAL: no vendor/llvm-mos checkout (run dev/run.sh toolchain)"; exit 1; }

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

echo "==> [gen] worktree @ pristine + commit 0001+0002(+0003)+0004 as baseline (all but 0005)"
git -C "$VENDOR" worktree add --detach "$WT_GEN" "$PRISTINE" >/dev/null
git -C "$WT_GEN" apply "$P1"
git -C "$WT_GEN" apply "$P2"
[ -f "$P3" ] && git -C "$WT_GEN" apply "$P3"
git -C "$WT_GEN" apply "$P4"
git -C "$WT_GEN" add -A
git "${GIT_ID[@]}" -C "$WT_GEN" commit -q -m "0001+0002(+0003)+0004 baseline"

echo "==> [gen] copy live MOSLegalizerInfo.cpp over the baseline, diff -> 0005"
cp "$VENDOR/$LEG" "$WT_GEN/$LEG"
git -C "$WT_GEN" add -A
git -C "$WT_GEN" diff --cached -- "$LEG" > "$P5"
echo "    wrote $P5 ($(wc -l < "$P5") lines, $(grep -c '^diff --git' "$P5") file)"
[ -s "$P5" ] || { echo "FATAL: empty 0005 — is the live MOSLegalizerInfo.cpp the far-ptr-value variant?"; exit 1; }

echo "==> [verify] apply full 0001..0005 series to a fresh pristine worktree"
git -C "$VENDOR" worktree add --detach "$WT_VFY" "$PRISTINE" >/dev/null
git -C "$WT_VFY" apply "$P1"
git -C "$WT_VFY" apply "$P2"
[ -f "$P3" ] && git -C "$WT_VFY" apply "$P3"
git -C "$WT_VFY" apply "$P4"
git -C "$WT_VFY" apply "$P5"

echo "==> [verify] diff -rq reapplied MOS dir vs live vendor MOS dir"
if diff -rq "$WT_VFY/$MOSREL" "$VENDOR/$MOSREL"; then
  echo "RESULT: PASS — 0005 round-trips (reapplied MOS dir == live vendor)"
else
  echo "RESULT: FAIL — round-trip mismatch (see diff above)"; exit 1
fi
