#!/usr/bin/env bash
# dev/regen-patch-0007.sh — regenerate patches/llvm-mos/0007-65816-near-abs-bank-relax.patch
# from the live (directly-edited) vendor/llvm-mos tree.
#
# What 0007 is: a GENERAL 65816 assembler-relaxation fix, discovered while
# productionizing #320 packed-24. The MC bank relaxation
# (MOSAsmBackend::fixupNeedsRelaxationAdvanced) grew EVERY plain-symbol absolute
# access to a NEAR (bank-0) global into the 4-byte absolute-LONG form, because it
# only distinguished zero-page vs not — never near (16-bit abs) vs far (24-bit
# long). Only the A-register path bloated (STX/STY have no long form to relax to);
# lld has no MOS long->abs shrink, so the waste reached the final ROM (~1 B per
# A-register near-global access; ~284 sites across the a16 examples). The fix
# suppresses abs->long relaxation for near (non-.far) sections, keeping it for
# banked .far* sections. It touches only MOSAsmBackend.cpp, which NO other patch
# modifies, so it is a clean stacked patch (not folded into 0001/0006).
#
# 0007 = (live) - (pristine + 0001 + 0002 + 0003 + 0004 + 0005 + 0006), restricted
# to the single file it touches. Runs on the HOST (needs git + diff; no container).
# See docs/plans/2026-06-21-320-packed24-productionization-handoff.md (Task B).
set -euo pipefail

usage() { echo "Usage: dev/regen-patch-0007.sh   # regenerate + round-trip-verify patches/llvm-mos/0007-65816-near-abs-bank-relax.patch"; exit 0; }
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
P7="$PATCHES/0007-65816-near-abs-bank-relax.patch"

# The single file 0007 modifies. Diff'd individually so foreign WIP elsewhere
# never leaks in.
RELAX_FILES=(
  "llvm/lib/Target/MOS/MCTargetDesc/MOSAsmBackend.cpp"
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

echo "==> [gen] baseline = pristine + 0001 + 0002 (+0003) + 0004 + 0005 + 0006; overlay live RELAX_FILES; diff"
mkwt
git -C "$WT" apply "$P1"
git -C "$WT" apply "$P2"
[ -f "$P3" ] && git -C "$WT" apply "$P3"
git -C "$WT" apply "$P4"
git -C "$WT" apply "$P5"
git -C "$WT" apply "$P6"
git -C "$WT" add -A
git "${GIT_ID[@]}" -C "$WT" commit -q -m "stack baseline (0001-0006)"
for f in "${RELAX_FILES[@]}"; do cp "$VENDOR/$f" "$WT/$f"; done
git -C "$WT" diff > "$P7"
echo "    wrote $P7 ($(wc -l < "$P7") lines, $(grep -c '^diff --git' "$P7") files)"
rmwt

echo "==> [verify] pristine + 0001..0007 reproduces the live RELAX_FILES exactly"
mkwt
git -C "$WT" apply "$P1" "$P2"
[ -f "$P3" ] && git -C "$WT" apply "$P3"
git -C "$WT" apply "$P4" "$P5" "$P6" "$P7"
rc=0
for f in "${RELAX_FILES[@]}"; do
  if ! diff -q "$WT/$f" "$VENDOR/$f" >/dev/null 2>&1; then
    echo "  MISMATCH $f"; rc=1
  fi
done
rmwt
if [ $rc -eq 0 ]; then
  echo "RESULT: PASS — 0007 round-trips (0001..0007 reproduces MOSAsmBackend.cpp)"
else
  echo "RESULT: FAIL — round-trip mismatch"; exit 1
fi
