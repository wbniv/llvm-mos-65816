#!/usr/bin/env bash
# dev/regen-patch.sh — regenerate patches/llvm-mos/0002-321-accum16.patch from the
# live (directly-edited) vendor/llvm-mos tree, via the isolated-worktree method.
#
# vendor/llvm-mos is gitignored and edited in place; its HEAD is pristine upstream
# (dev/toolchain.sh clones pristine then `git apply`s the patches WITHOUT
# committing). So the tracked source of truth for our backend changes is the patch
# series, which must be regenerated whenever the live tree changes.
#
# The baseline is pristine vendor HEAD plus 0001. Mirror the live MOS sources
# and selected tests, then reverse the standalone patches before deriving 0002.
# A fresh application must reproduce the same sources and selected tests.
# Merged upstream fixes are supplied by the pin and excluded from the overlay.
#
# Runs on the HOST (needs git + rsync; no container). See the #321 plans.
set -euo pipefail

usage() { echo "Usage: dev/regen-patch.sh   # regenerate + round-trip-verify patches/llvm-mos/0002-321-accum16.patch"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="${LLVM_MOS_SOURCE:-$ROOT/vendor/llvm-mos}"
LLVM_MOS_PIN="${LLVM_MOS_PIN:-$(cat "$ROOT/dev/llvm-mos-pin")}"
if [ -z "${LLVM_MOS_SOURCE:-}" ] && [ -e "$VENDOR/.git" ] &&
   [ "$(git -C "$VENDOR" rev-parse HEAD)" != "$LLVM_MOS_PIN" ]; then
  VENDOR="$ROOT/vendor/llvm-mos-${LLVM_MOS_PIN:0:12}"
fi
PATCHES="$ROOT/patches/llvm-mos"
P1="$PATCHES/0001-320-far-addrspace.patch"
P2="$PATCHES/0002-321-accum16.patch"
MOSREL="llvm/lib/Target/MOS"

# Standalone upstream-bound patches that live INSIDE $MOSREL and are therefore
# absorbed into 0002 by the mirror+diff below unless they are in the baseline.
# Each is optional (dropped once it merges upstream and the vendor pin is bumped).
# Order = dev/toolchain.sh apply order (reverse-applied back to front below).
STANDALONE_MOSDIR=(
  "$PATCHES/0018-320-imag32-spill.patch"
  "$PATCHES/0020-mos-65816-block-move-bank-order.patch"
  "$PATCHES/0023-mos-trunc-selection-regclasses.patch"
  "$PATCHES/0030-mos-copy-phys-reg-liveness.patch"
  "$PATCHES/0031-mos-copy-phys-reg-reuse-dst.patch"
  "$PATCHES/0032-mos-quote-register-named-symbols-vendor.patch"
  "$PATCHES/0034-mos-legalize-prefetch.patch"
  "$PATCHES/0039-mos-asm-modifier-width.patch"
  "$PATCHES/0036-mos-zero-page-indexed-globals.patch"
  "$PATCHES/0038-mos-return-frame-address.patch"
  "$PATCHES/0042-mos-scavenger-p-undef-a16-test.patch"
  "$PATCHES/0043-mos-inline-asm-physreg-width.patch"
  "$PATCHES/0044-mos-asm-print-long-address.patch"
  "$PATCHES/0045-mos-asm-print-a16-immediate.patch"   # a16 immediate width; downstream-only
  "$PATCHES/0046-mos-fixupkinds-addrasciz-row.patch"  # AddrAsciz Infos[] row; pristine-upstream
  "$PATCHES/0047-mos-mc-addr-asciz-symbolic-crash.patch"  # -show-encoding crash; pristine-upstream
  "$PATCHES/0050-mos-float-vector-arithmetic.patch"
  "$PATCHES/0051-mos-zp-byte-index.patch"
  "$PATCHES/0052-mos-bank-relax-section-offset.patch"
  "$PATCHES/0055-mos-native-wide-anyext-vendor.patch"
  "$PATCHES/0061-mos-far-global-long-x.patch"
  "$PATCHES/0062-mos-native-far-word.patch"
  "$PATCHES/0063-mos-near-shared-store.patch"
  "$PATCHES/0064-mos-computed-carry-scheduling.patch"
  "$PATCHES/0065-mos-near-store-profitability.patch"
  "$PATCHES/0066-mos-far-extload-worklist.patch"
  "$PATCHES/0067-mos-competing-carry-gate.patch"
  "$PATCHES/0068-mos-null-output-streamer.patch"
  "$PATCHES/0069-mos-far-loop-range.patch"
  "$PATCHES/0070-mos-far-word-index-policy.patch"
  "$PATCHES/0071-mos-accumulator-pressure-set.patch"
)
TESTRELS=(
  "llvm/test/CodeGen/MOS/native-index-copy-cost.mir"
  "llvm/test/CodeGen/MOS/cmpzero-terminator-invalid.mir"
  "llvm/test/CodeGen/MOS/copy-opt-chain.mir"
  "llvm/test/CodeGen/MOS/copy-opt-loop.mir"
  "llvm/test/CodeGen/MOS/late-opt-cmpzero.mir"
  "llvm/test/CodeGen/MOS/late-opt-spc700.mir"
  "llvm/test/CodeGen/MOS/zp-alloc-deterministic.ll"
  "llvm/test/MC/MOS/branch-range-errors.s"
  "llvm/test/MC/MOS/brk-signature.s"
  "llvm/test/CodeGen/MOS/carry-pressure-schedule.mir"
  "llvm/test/CodeGen/MOS/carry-pressure-gate.mir"
  "llvm/test/CodeGen/MOS/anyext-wide.mir"
  "llvm/test/CodeGen/MOS/anyext-masked-byte.ll"
  "llvm/test/CodeGen/MOS/a16-indirect-byte-store.ll"
  "llvm/test/CodeGen/MOS/a16-near-store-profit.ll"
  "llvm/test/CodeGen/MOS/a16-byte-store.ll"
  "llvm/test/CodeGen/MOS/scavenger-p-undef.mir"   # +mos-a16 regression for the 0011 scavenger fix; downstream-only
  "llvm/test/CodeGen/MOS/insert-rep-sep-cloned-kills.mir"
  "llvm/test/CodeGen/MOS/insert-rep-sep-stack.mir"
  "llvm/test/CodeGen/MOS/interrupt-width-65816.ll"
  "llvm/test/CodeGen/MOS/legalizer-indexed-offset-observer.mir"
  "llvm/test/MC/MOS/all-65816-opcodes.s"
  "llvm/test/MC/MOS/motorola-integers-default.s"
  "llvm/test/CodeGen/MOS/inline-asm-physreg-width.ll"  # created by 0043; cp'd in so 0043 reverses cleanly
  "llvm/test/MC/MOS/modifier-width.s"                  # created by 0039; cp'd in so 0039 reverses cleanly
  "llvm/test/MC/MOS/modifier-width-65816.s"            # created by 0039
  "llvm/test/MC/MOS/modifier-width-errors.s"           # created by 0039
  "llvm/test/MC/MOS/long-address-roundtrip-65816.s"    # created by 0044
  "llvm/test/CodeGen/MOS/a16-immediate-width.ll"       # created by 0045
  "llvm/test/CodeGen/MOS/far-indir-indexed.ll"         # #321 Ph2 inc 1: [dp],y (b7/97) selection + its negative gate cases
  "llvm/test/CodeGen/MOS/xy16-near-indir-y.ll"
  "llvm/test/CodeGen/MOS/near-index-proofs.ll"
  "llvm/test/CodeGen/MOS/near-index-proofs-debug.ll"
  "llvm/test/CodeGen/MOS/far-global-long-x.ll"
  "llvm/test/CodeGen/MOS/far-absolute-extload.mir"
  "llvm/test/CodeGen/MOS/far-native-word.ll"
  "llvm/test/CodeGen/MOS/far-loop-range.mir"
  "llvm/test/CodeGen/MOS/far-word-policy.mir"
  "llvm/test/CodeGen/MOS/far-ptr-arg-exhaustion.ll"   # mos-far-pointer-arg-exhaustion (B1)
  "llvm/test/CodeGen/MOS/far-memop-length.ll"         # mos-far-memop-length-truncation (B2)
  "llvm/test/CodeGen/MOS/far-access-non-65816.ll"     # mos-far-access-non-65816 (B3)
  "llvm/test/CodeGen/MOS/far-index-fold-debug.ll"     # mos-far-index-fold-dangling-dbg (B4)
  "llvm/test/CodeGen/MOS/native-width-default-pressure.ll"     # native-width pressure sets; 0071 updates it
  "llvm/test/CodeGen/MOS/native-width-pressure-opt-level.ll"   # native-width pressure sets (-O3 gate)
)

[ -e "$VENDOR/.git" ] || { echo "FATAL: no vendor/llvm-mos checkout (run dev/run.sh toolchain)"; exit 1; }
[ "$(git -C "$VENDOR" rev-parse HEAD)" = "$LLVM_MOS_PIN" ] || {
  echo "FATAL: patch regeneration requires source at $LLVM_MOS_PIN" >&2
  exit 1
}

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

echo "==> [gen] worktree @ pristine + commit 0001 as baseline"
git -C "$VENDOR" worktree add --detach "$WT_GEN" "$PRISTINE" >/dev/null
git -C "$WT_GEN" apply "$P1"
git -C "$WT_GEN" add -A
git "${GIT_ID[@]}" -C "$WT_GEN" commit -q -m "0001 baseline"

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
  # 0038 is applied with -C1 by toolchain.sh (its registration hunks neighbour
  # 0002's REP/SEP lines), so it reverses with the same reduced context.
  ctx=(); case "$p" in *0038-*) ctx=(-C1);; esac
  git -C "$WT_GEN" apply --reverse "${ctx[@]}" "${includes[@]}" "$p"
done
git -C "$WT_GEN" add -A
git -C "$WT_GEN" diff --cached > "$P2"
# Empty context lines are conventionally emitted as a single space. Strip that
# marker so the patch artifact itself also passes the parent repo's whitespace
# check; git apply accepts the unmarked empty context lines.
sed -i 's/^ $//' "$P2"
echo "    wrote $P2 ($(wc -l < "$P2") lines, $(grep -c '^diff --git' "$P2") files)"

# Only one full checkout is needed at a time; release the generation tree
# before allocating the independent verification checkout.
git -C "$VENDOR" worktree remove --force "$WT_GEN"

echo "==> [verify] apply 0001 + new 0002 to a fresh pristine worktree"
git -C "$VENDOR" worktree add --detach "$WT_VFY" "$PRISTINE" >/dev/null
git -C "$WT_VFY" apply "$P1"
git -C "$WT_VFY" apply "$P2"
for p in "${STANDALONE_MOSDIR[@]}"; do
  ctx=(); case "$p" in *0038-*) ctx=(-C1);; esac   # see the reverse loop above
  [ -f "$p" ] && git -C "$WT_VFY" apply "${ctx[@]}" "$p"
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
