#!/usr/bin/env bash
# dev/regen-patch-0006.sh — regenerate patches/llvm-mos/0006-320-packed24.patch
# (the #320 packed-24 / addrspace-3 patch) from the live (directly-edited)
# vendor/llvm-mos tree.
#
# Why a SEPARATE, STACKED patch (not folded into 0001): packed-24 (Increment B) edits
# files that 0004 (far-cc) and 0005 (far-ptr-value-legalize) also touch
# (MOSISelLowering.cpp; the PF-as-value G_LOAD/G_STORE list in MOSLegalizerInfo.cpp).
# Folding into 0001 would risk absorbing those foreign hunks — the exact thing the
# project commit discipline forbids. So packed-24 is stacked LAST (0006), the same
# pattern 0004/0005 used. 0006 = (live) - (pristine + 0001 + 0002 + 0003 + 0004 + 0005),
# restricted to the files packed-24 touches.
#
# Runs on the HOST (needs git + diff; no container). See
# docs/plans/2026-06-21-320-packed24-incrementB-handoff.md.
set -euo pipefail

usage() { echo "Usage: dev/regen-patch-0006.sh   # regenerate + round-trip-verify patches/llvm-mos/0006-320-packed24.patch"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/llvm-mos"
PATCHES="$ROOT/patches/llvm-mos"
P1="$PATCHES/0001-320-far-addrspace.patch"
P2="$PATCHES/0002-321-accum16.patch"
P3="$PATCHES/0003-late-opt-txy-dead-flag.patch"   # upstream-bound F4 fix; optional
P4="$PATCHES/0004-320-far-cc.patch"
P5="$PATCHES/0005-320-far-ptr-value-legalize.patch"
P6="$PATCHES/0006-320-packed24.patch"

# Files packed-24 (Increment A + B) adds/modifies. Diff'd individually so foreign WIP
# in other files never leaks into 0006.
PACKED_FILES=(
  "clang/lib/Basic/Targets/MOS.cpp"
  "llvm/lib/Target/MOS/MOSInstrInfo.h"
  "llvm/lib/Target/MOS/MOSTargetMachine.cpp"
  "llvm/lib/Target/MOS/MOSISelLowering.cpp"
  "llvm/lib/Target/MOS/MOSISelLowering.h"
  "llvm/lib/Target/MOS/MOSLegalizerInfo.cpp"
  "llvm/lib/Target/MOS/MOSLegalizerInfo.h"
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

echo "==> [gen] baseline = pristine + 0001 + 0002 (+0003) + 0004 + 0005; overlay live PACKED_FILES; diff"
mkwt
git -C "$WT" apply "$P1"
git -C "$WT" apply "$P2"
[ -f "$P3" ] && git -C "$WT" apply "$P3"
git -C "$WT" apply "$P4"
git -C "$WT" apply "$P5"
git -C "$WT" add -A
git "${GIT_ID[@]}" -C "$WT" commit -q -m "stack baseline (0001-0005)"
for f in "${PACKED_FILES[@]}"; do cp "$VENDOR/$f" "$WT/$f"; done
git -C "$WT" diff > "$P6"
echo "    wrote $P6 ($(wc -l < "$P6") lines, $(grep -c '^diff --git' "$P6") files)"
rmwt

echo "==> [verify] pristine + 0001..0006 reproduces the live PACKED_FILES exactly"
mkwt
git -C "$WT" apply "$P1" "$P2"
[ -f "$P3" ] && git -C "$WT" apply "$P3"
git -C "$WT" apply "$P4" "$P5" "$P6"
rc=0
for f in "${PACKED_FILES[@]}"; do
  if ! diff -q "$WT/$f" "$VENDOR/$f" >/dev/null 2>&1; then
    echo "  MISMATCH $f"; rc=1
  fi
done
rmwt
if [ $rc -eq 0 ]; then
  echo "RESULT: PASS — 0006 round-trips (0001..0006 reproduces every packed-24 file)"
else
  echo "RESULT: FAIL — round-trip mismatch"; exit 1
fi
