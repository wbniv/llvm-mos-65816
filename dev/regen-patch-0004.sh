#!/usr/bin/env bash
# dev/regen-patch-0004.sh — regenerate patches/llvm-mos/0004-320-far-cc.patch from the
# live (directly-edited) vendor/llvm-mos tree, via the isolated-worktree method.
#
# ⚠️ KNOWN-BROKEN as of 2026-06-25 — needs a redesign before it can regenerate 0004.
# This script isolates 0004 by building a baseline of "every patch EXCEPT 0004" and
# diffing the live MOS dir against it. That assumed nothing stacked ABOVE 0004 touches
# 0004's files. 0008 (mos-dp-arg-cc) broke it: its CC rule is authored on top of 0004's
# far-CC table in MOSCallingConv.td, so 0008 will not `git apply` onto a baseline that
# lacks 0004 — the [gen] step now hard-FAILS at MOSCallingConv.td (fail-safe: it errors
# instead of silently baking 0006-0009's hunks into 0004, the old failure mode). To
# regen 0004 properly, redesign on the delta method regen-patch-0001.sh uses (capture the
# NEW uncommitted far-CC edits, re-derive 0004 from a minimal baseline) — or temporarily
# revert 0008 first. The committed 0004 is correct + round-trip-verified at land time, and
# the far-CC codegen is re-verified by dev/run.sh farcc_{imag32,split,axy,stack} (all 0xF3,
# both emulators). See docs/plans/2026-06-21-320-far-cc-variants-bcd-and-measure.md §Verification.
#
# 0004 is the #320 Inc 4 Phase 2 far-pointer CALLING CONVENTION (the off-by-default
# +mos-farcc-* variants + farPtrCC() + the gated far-ptr CC rule + the Imag32
# register-bank coverage). It is its OWN patch — stacked on 0001+0002+0003 — rather
# than folded into 0001, because the far-ptr-COPY-through fix adds Imag32 to the
# AnyRegBank line that 0002 (a16, Increment 1b) ALSO edits (Ac16); a single shared
# line can't be split between 0001 and 0002 by the diff-reapply method that
# regen-patch-0001.sh / regen-patch.sh use. Stacking after 0002 sidesteps that:
# 0004's hunks may freely reference a16/xy16 context (Ac16, FeatureIndex16). It is
# behaviorally a16-INDEPENDENT (every far-CC rule is gated on a +mos-farcc-* feature
# that is off by default — proven byte-identical), only its PATCH CONTEXT touches
# a16 lines. dev/toolchain.sh applies patches/llvm-mos/*.patch in glob order, so 0004
# is auto-applied after 0003.
#
# Method (baseline = pristine vendor HEAD + 0001 + 0002 + 0003 committed):
#   1. fresh detached worktree at pristine HEAD;
#   2. apply 0001 + 0002 + 0003 and commit -> baseline (so 0004 captures ONLY the
#      far-CC delta, with the a16 work already in the baseline);
#   3. mirror the live llvm/lib/Target/MOS dir over the worktree with rsync --delete;
#   4. `git diff --cached` against the baseline -> 0004.
# Then round-trip verify: apply 0001+0002+0003+the new 0004 to another pristine
# worktree and `diff -rq` its MOS dir against the live vendor MOS dir — identical.
#
# Runs on the HOST (needs git + rsync; no container). See
# docs/plans/2026-06-20-320-far-pointer-cc-build-all-variants.md.
set -euo pipefail

usage() { echo "Usage: dev/regen-patch-0004.sh   # regenerate + round-trip-verify patches/llvm-mos/0004-320-far-cc.patch"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/llvm-mos"
PATCHES="$ROOT/patches/llvm-mos"
P1="$PATCHES/0001-320-far-addrspace.patch"
P2="$PATCHES/0002-321-accum16.patch"
P3="$PATCHES/0003-late-opt-txy-dead-flag.patch"   # upstream-bound F4 fix; optional
P4="$PATCHES/0004-320-far-cc.patch"
# 0005 (#320 far-ptr-as-value legalization, MOSLegalizerInfo only) ALSO stacks after
# 0002 but is independent of 0004 (disjoint files; 0005 touches only MOSLegalizerInfo,
# 0004 touches none of it). Bake it into the baseline so its MOSLegalizerInfo change
# does NOT leak into the regenerated 0004 (the whole-MOS-dir mirror would otherwise
# absorb it). Optional, like 0003.
P5="$PATCHES/0005-320-far-ptr-value-legalize.patch"
# Patches stacked ABOVE 0004 that ALSO touch the MOS dir 0004 mirrors — they must be in
# the exclude-0004 baseline too, else the whole-MOS-dir mirror absorbs their hunks into the
# regenerated 0004 (the stale-stack bug). Append new ones here as the series grows.
P6="$PATCHES/0006-320-packed24.patch"
P7="$PATCHES/0007-65816-near-abs-bank-relax.patch"
P8="$PATCHES/0008-mos-dp-arg-cc.patch"
P9="$PATCHES/0009-321-a16-pressure-incdec.patch"
MOSREL="llvm/lib/Target/MOS"

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

echo "==> [gen] worktree @ pristine + commit 0001 + 0002 (+0003)(+0005) as baseline"
git -C "$VENDOR" worktree add --detach "$WT_GEN" "$PRISTINE" >/dev/null
git -C "$WT_GEN" apply "$P1"
git -C "$WT_GEN" apply "$P2"
[ -f "$P3" ] && git -C "$WT_GEN" apply "$P3"
[ -f "$P5" ] && git -C "$WT_GEN" apply "$P5"   # keep 0005's MOSLegalizerInfo out of 0004
git -C "$WT_GEN" apply "$P6"   # packed24 (MOSLegalizerInfo + others) — exclude from 0004
git -C "$WT_GEN" apply "$P7"   # near-abs (MOSAsmBackend) — exclude from 0004
git -C "$WT_GEN" apply "$P8"   # dp-arg-cc (MOSCallingConv/CallLowering) — exclude from 0004
git -C "$WT_GEN" apply "$P9"   # a16-pressure (MOSInstructionSelector) — exclude from 0004
git -C "$WT_GEN" add -A
git "${GIT_ID[@]}" -C "$WT_GEN" commit -q -m "0001+0002(+0003)(+0005) baseline"

echo "==> [gen] mirror live $MOSREL over the baseline, diff -> 0004"
rsync -a --delete "$VENDOR/$MOSREL/" "$WT_GEN/$MOSREL/"
git -C "$WT_GEN" add -A
git -C "$WT_GEN" diff --cached > "$P4"
echo "    wrote $P4 ($(wc -l < "$P4") lines, $(grep -c '^diff --git' "$P4") files)"

echo "==> [verify] apply 0001 + 0002 (+0003) + new 0004 (+0005) to a fresh pristine worktree"
git -C "$VENDOR" worktree add --detach "$WT_VFY" "$PRISTINE" >/dev/null
git -C "$WT_VFY" apply "$P1"
git -C "$WT_VFY" apply "$P2"
[ -f "$P3" ] && git -C "$WT_VFY" apply "$P3"
git -C "$WT_VFY" apply "$P4"
[ -f "$P5" ] && git -C "$WT_VFY" apply "$P5"   # full series so the MOS dir matches live
git -C "$WT_VFY" apply "$P6"
git -C "$WT_VFY" apply "$P7"
git -C "$WT_VFY" apply "$P8"
git -C "$WT_VFY" apply "$P9"

echo "==> [verify] diff -rq reapplied MOS dir vs live vendor MOS dir"
if diff -rq "$WT_VFY/$MOSREL" "$VENDOR/$MOSREL"; then
  echo "RESULT: PASS — 0004 round-trips (reapplied MOS dir == live vendor)"
else
  echo "RESULT: FAIL — round-trip mismatch (see diff above)"; exit 1
fi
