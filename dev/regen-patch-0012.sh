#!/usr/bin/env bash
# dev/regen-patch-0012.sh — regenerate patches/llvm-mos/0012-mos-ldcimm-set-lowering.patch
# from the live (directly-edited) vendor/llvm-mos tree.
#
# What 0012 is: an UPSTREAM MC-lowering robustness fix (pristine llvm-mos, not #321 feature code).
# MOSMCInstLower lowered `LDCImm` (Cc, i1imm) only for immediate 0 (CLC) and -1 (SEC), asserting
# `llvm_unreachable("Unexpected LDCImm immediate.")` otherwise. But a *set* i1 carry can reach MC as
# 1 (a plain i1 'true') — e.g. the carry-in materialized for a 16-bit SBC — so a plain +mos-a16
# 16-bit subtract aborts an asserts build at that unreachable (and, under NDEBUG, silently mislowers
# the `default` arm — it happens to emit SEC, so the differential stayed green). Fix: lower the
# operand as the boolean it is — `imm == 0 ? CLC : SEC` (any nonzero -> SEC). One line, emits the
# same SEC, removes the NDEBUG-UB. Touches only MOSMCInstLower.cpp.
#
# Surfaced while fixing the register-scavenger crash (patch 0011): once the scavenger no longer
# crashed, examples/65816/a16scavnz.c compiled *past* it and reached this MC unreachable on the
# asserts build. Independent of the scavenger (a16sub16 reproduces); kept a separate patch.
#
# 0012 = (live) - (pristine + 0001..0011), restricted to the single file it touches. Runs on the
# HOST (needs git + diff; no container). See docs/plans/2026-06-26-321-scavenger-nz-live-p-save-fix.md.
set -euo pipefail

usage() { echo "Usage: dev/regen-patch-0012.sh   # regenerate + round-trip-verify patches/llvm-mos/0012-mos-ldcimm-set-lowering.patch"; exit 0; }
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
)
P12="$PATCHES/0012-mos-ldcimm-set-lowering.patch"

# The single file 0012 modifies. Diff'd individually so foreign WIP elsewhere never leaks in.
LOWER_FILES=(
  "llvm/lib/Target/MOS/MOSMCInstLower.cpp"
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

echo "==> [gen] baseline = pristine + 0001..0011; overlay live MOSMCInstLower.cpp; diff"
mkwt
apply_stack
git -C "$WT" add -A
git "${GIT_ID[@]}" -C "$WT" commit -q -m "stack baseline (0001-0011)"
for f in "${LOWER_FILES[@]}"; do cp "$VENDOR/$f" "$WT/$f"; done
git -C "$WT" diff > "$P12"
echo "    wrote $P12 ($(wc -l < "$P12") lines, $(grep -c '^diff --git' "$P12") files)"
rmwt

echo "==> [verify] pristine + 0001..0012 reproduces the live $LOWER_FILES exactly"
mkwt
apply_stack
git -C "$WT" apply "$P12"
rc=0
for f in "${LOWER_FILES[@]}"; do
  if ! diff -q "$WT/$f" "$VENDOR/$f" >/dev/null 2>&1; then
    echo "  MISMATCH $f"; rc=1
  fi
done
rmwt
if [ $rc -eq 0 ]; then
  echo "RESULT: PASS — 0012 round-trips (0001..0012 reproduces MOSMCInstLower.cpp)"
else
  echo "RESULT: FAIL — round-trip mismatch"; exit 1
fi
