#!/usr/bin/env bash
# dev/regen-patch-0001.sh — regenerate patches/llvm-mos/0001-320-far-addrspace.patch
# (the #320 far patch) from the live (directly-edited) vendor/llvm-mos tree.
#
# Why a separate script from regen-patch.sh: 0001 and 0002 BOTH edit some files
# (MOSInstrLogical.td), stacked as 0001-then-0002. regen-patch.sh bakes 0001+0003
# into its baseline and mirrors the live MOS dir to capture *only* the 0002 delta —
# it has no 0001 path. To regenerate 0001 we must isolate the new far hunks from the
# interleaved 0002 (a16) hunks. We do that by reconstructing the tree as it was
# BEFORE the new far edits (pristine + 0001 + 0002 + 0003), saving the touched files,
# diffing them against the live tree (= exactly the new far edits), then re-applying
# that delta onto the 0001-only baseline. The delta re-applies because every far hunk
# anchors on PRISTINE near-call code (the JSR/RTS/RTI pseudos, lowerCall/lowerReturn)
# that neither 0001 nor 0002 adds — so its context lines exist in the 0001-only tree.
#
# Worktrees are created/used/removed ONE AT A TIME: a full llvm-mos checkout is
# ~174k files / ~2 GB, and three at once overflows a 7 GB /tmp (that was the original
# bug). Peak is one worktree.
#
# FAR_FILES lists the files a far change may touch inside llvm/lib/Target/MOS. Extend
# it if a future far increment edits a new file. (Files only 0001 touches reconstruct
# to their pristine content, so their delta is the whole far edit — handled the same.)
#
# Runs on the HOST (needs git + diff; no container). See the #320 plans.
set -euo pipefail

usage() { echo "Usage: dev/regen-patch-0001.sh   # regenerate + round-trip-verify patches/llvm-mos/0001-320-far-addrspace.patch"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/llvm-mos"
PATCHES="$ROOT/patches/llvm-mos"
P1="$PATCHES/0001-320-far-addrspace.patch"
P2="$PATCHES/0002-321-accum16.patch"
P3="$PATCHES/0003-late-opt-txy-dead-flag.patch"   # upstream-bound F4 fix; optional
MOSREL="llvm/lib/Target/MOS"

# Files inside MOSREL that a far (#320) change may add/modify. Diff'd individually so
# foreign WIP in OTHER files never leaks into 0001.
FAR_FILES=(
  "$MOSREL/MOSInstrLogical.td"
  "$MOSREL/MOSCallLowering.cpp"
)

[ -d "$VENDOR/.git" ] || { echo "FATAL: no vendor/llvm-mos checkout (run dev/run.sh toolchain)"; exit 1; }

PRISTINE="$(git -C "$VENDOR" rev-parse HEAD)"
echo "==> pristine vendor HEAD: $(git -C "$VENDOR" rev-parse --short HEAD)"

SAVE="$(mktemp -d)"; FAR_DELTA="$(mktemp)"; WT=""
cleanup() {
  [ -n "$WT" ] && git -C "$VENDOR" worktree remove --force "$WT" 2>/dev/null || true
  git -C "$VENDOR" worktree prune 2>/dev/null || true
  rm -rf "$SAVE" "$FAR_DELTA" "$WT"
}
trap cleanup EXIT
GIT_ID=(-c user.email=patchgen@local -c user.name=patchgen)

mkwt() { WT="$(mktemp -d)"; git -C "$VENDOR" worktree add --detach "$WT" "$PRISTINE" >/dev/null; }
rmwt() { git -C "$VENDOR" worktree remove --force "$WT" 2>/dev/null || true; rm -rf "$WT"; WT=""; }

echo "==> [recon] pristine + 0001 + 0002 (+0003) = live minus the new far edits; save FAR_FILES"
mkwt
git -C "$WT" apply "$P1"
git -C "$WT" apply "$P2"
[ -f "$P3" ] && git -C "$WT" apply "$P3"
for f in "${FAR_FILES[@]}"; do mkdir -p "$SAVE/$(dirname "$f")"; cp "$WT/$f" "$SAVE/$f"; done
rmwt

echo "==> [delta] far edits = diff(recon, live) over FAR_FILES"
: > "$FAR_DELTA"
for f in "${FAR_FILES[@]}"; do
  if ! diff -q "$SAVE/$f" "$VENDOR/$f" >/dev/null 2>&1; then
    diff -u --label "a/$f" --label "b/$f" "$SAVE/$f" "$VENDOR/$f" >> "$FAR_DELTA" || true
    echo "    + $f"
  fi
done
[ -s "$FAR_DELTA" ] || { echo "FATAL: no far delta found (did you edit a file not in FAR_FILES?)"; exit 1; }

echo "==> [gen] pristine + 0003 baseline, apply 0001 + far delta -> new 0001"
mkwt
[ -f "$P3" ] && { echo "    baking 0003 (F4) into baseline so it drops out of 0001"; git -C "$WT" apply "$P3"; }
git -C "$WT" add -A
git "${GIT_ID[@]}" -C "$WT" commit -q --allow-empty -m "0003 baseline"
git -C "$WT" apply "$P1"
git -C "$WT" apply "$FAR_DELTA"
git -C "$WT" add -A
git -C "$WT" diff --cached > "$P1"
echo "    wrote $P1 ($(wc -l < "$P1") lines, $(grep -c '^diff --git' "$P1") files)"
rmwt

echo "==> [verify] apply new 0001 + 0002 (+0003) to a fresh pristine worktree, diff vs live"
mkwt
git -C "$WT" apply "$P1"
git -C "$WT" apply "$P2"
[ -f "$P3" ] && git -C "$WT" apply "$P3"
if diff -rq "$WT/$MOSREL" "$VENDOR/$MOSREL"; then
  echo "RESULT: PASS — 0001 round-trips (reapplied MOS dir == live vendor)"
  rmwt
else
  echo "RESULT: FAIL — round-trip mismatch (see diff above)"; rmwt; exit 1
fi
