#!/usr/bin/env bash
# dev/regen-patch-0001.sh — regenerate patches/llvm-mos/0001-320-far-addrspace.patch
# (the #320 far patch) from the live (directly-edited) vendor/llvm-mos tree.
#
# Why a separate script from regen-patch.sh: 0001 is the BOTTOM of a stacked series
# (0001..0007) and shares files with patches above it (e.g. MOSInstrLogical.td with
# 0002, MOSCallLowering.cpp with 0004, MOSLegalizerInfo.cpp with 0002/0005/0006,
# clang Targets/MOS.cpp with 0006). regen-patch.sh has no 0001 path. To regenerate
# 0001 we must isolate the far hunks from the interleaved later-patch hunks. We do
# that by reconstructing the tree as it is WITH the WHOLE committed stack applied
# (pristine + 0001..0007) — i.e. "live minus any NEW, uncommitted far edits" — saving
# the touched files, diffing them against the live tree (= exactly the new far edits),
# then re-applying just 0001 + that delta onto a pristine baseline to re-derive 0001.
# The delta re-applies because far hunks anchor on PRISTINE near-call code (the
# JSR/RTS/RTI pseudos, lowerCall/lowerReturn) that the later patches don't add — so
# their context lines exist in the 0001-only tree.
#
# CRITICAL — the recon AND verify apply the FULL stack (0001..0007). A stale recon
# (the old 0001+0002+0003) would, for a file ALSO touched by 0004-0007, compute a
# delta = those later patches' hunks and bake them into 0001 — corrupting it (and the
# old MOS-dir-only verify, run on the 7-patch stack, would simply FAIL). Whenever a
# new patch (0008+) is added to the series, append it to STACK below.
#
# FAR_FILES lists EVERY file 0001 touches (clang + llvm), so a far edit to any of them
# is captured in the delta and round-trip-verified per-file. Extend it if a future far
# increment edits a new file. (This is the fix for the logged note: the old list was
# MOS-dir-only, so a future *clang* far edit would have been silently dropped.)
#
# Worktrees are created/used/removed ONE AT A TIME: a full llvm-mos checkout is
# ~174k files / ~2 GB, and three at once overflows a 7 GB /tmp (that was the original
# bug). Peak is one worktree.
#
# Runs on the HOST (needs git + diff; no container). See the #320 plans.
set -euo pipefail

usage() { echo "Usage: dev/regen-patch-0001.sh   # regenerate + round-trip-verify patches/llvm-mos/0001-320-far-addrspace.patch"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/llvm-mos"
PATCHES="$ROOT/patches/llvm-mos"
P1="$PATCHES/0001-320-far-addrspace.patch"
P3="$PATCHES/0003-late-opt-txy-dead-flag.patch"   # upstream-bound F4 fix; optional
MOSREL="llvm/lib/Target/MOS"

# The patches stacked ABOVE 0001, in apply order. The recon/verify apply 0001 + all of
# these so the reconstructed/round-tripped tree == the live full-stack vendor. P3 is
# applied conditionally (it's optional); the rest must exist.
STACK=(
  "$PATCHES/0002-321-accum16.patch"
  "$P3"
  "$PATCHES/0004-320-far-cc.patch"
  "$PATCHES/0005-320-far-ptr-value-legalize.patch"
  "$PATCHES/0006-320-packed24.patch"
  "$PATCHES/0007-65816-near-abs-bank-relax.patch"
)
apply_stack() {  # apply_stack <worktree>  — apply every patch above 0001, in order
  local wt="$1" p
  for p in "${STACK[@]}"; do
    [ "$p" = "$P3" ] && { [ -f "$P3" ] && git -C "$wt" apply "$P3"; continue; }
    git -C "$wt" apply "$p"
  done
}

# Every file 0001 adds/modifies (repo-relative). Diff'd individually so foreign WIP in
# OTHER files never leaks into 0001. Several are also touched by 0002-0007 — handled by
# the full-stack recon above.
FAR_FILES=(
  # clang front-end (the F2 far attribute + sizeof + ConvertType work)
  "clang/include/clang/AST/TypeBase.h"
  "clang/include/clang/AST/TypeProperties.td"
  "clang/include/clang/Basic/Attr.td"
  "clang/lib/AST/ASTContext.cpp"
  "clang/lib/AST/TypePrinter.cpp"
  "clang/lib/Basic/Targets/MOS.cpp"
  "clang/lib/CodeGen/CGExpr.cpp"
  "clang/lib/CodeGen/CGExprScalar.cpp"
  "clang/lib/CodeGen/CodeGenModule.h"
  "clang/lib/CodeGen/CodeGenTypes.cpp"
  "clang/lib/Sema/SemaDeclAttr.cpp"
  "clang/lib/Sema/SemaType.cpp"
  # llvm shared (datalayout)
  "llvm/lib/TargetParser/TargetDataLayout.cpp"
  # llvm MOS backend
  "$MOSREL/MOSCallLowering.cpp"
  "$MOSREL/MOSInstrGISel.td"
  "$MOSREL/MOSInstrInfo.cpp"
  "$MOSREL/MOSInstrInfo.h"
  "$MOSREL/MOSInstrLogical.td"
  "$MOSREL/MOSInstructionSelector.cpp"
  "$MOSREL/MOSLateOptimization.cpp"
  "$MOSREL/MOSLegalizerInfo.cpp"
  "$MOSREL/MOSLegalizerInfo.h"
  "$MOSREL/MOSMCInstLower.cpp"
  "$MOSREL/MOSRegisterInfo.cpp"
  "$MOSREL/MOSRegisterInfo.td"
  "$MOSREL/MOSTargetMachine.cpp"
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

echo "==> [recon] pristine + 0001..0007 = live minus the new far edits; save FAR_FILES"
mkwt
git -C "$WT" apply "$P1"
apply_stack "$WT"
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
# An empty delta is EXPECTED when simply regenerating 0001 with no new uncommitted far
# edits (the committed stack already == live); it is NOT an error.
[ -s "$FAR_DELTA" ] && echo "    (captured new uncommitted far edits)" || echo "    (no new far edits — regenerating committed 0001 as-is)"

echo "==> [gen] pristine + 0003 baseline, apply 0001 + far delta -> new 0001"
mkwt
[ -f "$P3" ] && { echo "    baking 0003 (F4) into baseline so it drops out of 0001"; git -C "$WT" apply "$P3"; }
git -C "$WT" add -A
git "${GIT_ID[@]}" -C "$WT" commit -q --allow-empty -m "0003 baseline"
git -C "$WT" apply "$P1"
[ -s "$FAR_DELTA" ] && git -C "$WT" apply "$FAR_DELTA"
git -C "$WT" add -A
git -C "$WT" diff --cached > "$P1"
echo "    wrote $P1 ($(wc -l < "$P1") lines, $(grep -c '^diff --git' "$P1") files)"
rmwt

echo "==> [verify] apply new 0001 + 0002..0007 to a fresh pristine worktree, diff vs live"
mkwt
git -C "$WT" apply "$P1"
apply_stack "$WT"
rc=0
# MOS backend: a recursive diff catches ANY MOS file difference (incl. ones not yet in
# FAR_FILES — a safety net).
diff -rq "$WT/$MOSREL" "$VENDOR/$MOSREL" || rc=1
# Non-MOS FAR_FILES (clang front-end, TargetDataLayout): per-file diff (the recursive
# MOS check above does not reach them).
for f in "${FAR_FILES[@]}"; do
  case "$f" in "$MOSREL"/*) continue ;; esac
  diff -q "$WT/$f" "$VENDOR/$f" || rc=1
done
rmwt
if [ $rc -eq 0 ]; then
  echo "RESULT: PASS — 0001 round-trips (reapplied 0001..0007 == live vendor, MOS + clang)"
else
  echo "RESULT: FAIL — round-trip mismatch (see diff above)"; exit 1
fi
