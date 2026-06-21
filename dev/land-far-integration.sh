#!/usr/bin/env bash
# dev/land-far-integration.sh — one-shot round-trip patch surgery that LANDED the #320
# far-pointer line (folded the far-fn-ptr (a) recipes into 0001; landed 0004 + new 0005).
# Durable record of the landing; re-runnable while wt/320-far-followups (FF) is retained.
# Writes candidate patches to /tmp/far-land/out and PROVES the round-trip; it does NOT
# touch patches/ — the copy-into-place + commit was done by hand after PASS.
#
# Architecture (after measuring the (a)-delta — see findings):
#   new-0001 = main-0001 + (a) Group-A (a16-free, 0001-anchored far-fnptr work)
#   0004     = canonical far-cc (frozen)
#   0005     = the lone a16-context-entangled (a) piece: MOSLegalizerInfo PF-as-value
#   EXCLUDED from every new patch (owned by no patch; documented):
#     - clang/cmake/caches/MOS.cmake          (build-config drift, in no patch)
#     - llvm/lib/Target/MOS/MOSInsertREPSEP.cpp (FF working tree stale vs main's 0002)
#
# Proves: pristine + new-0001 + 0002 + 0003 + 0004 + 0005 reproduces FF EXACTLY over
# clang/ + llvm/lib/Target/MOS/, except the two excluded drift/stale files.
set -euo pipefail

ROOT=/home/will/SRC/llvm-mos-65816
VENDOR="$ROOT/vendor/llvm-mos"
FF=/home/will/SRC/llvm-mos-65816-far-followups/vendor/llvm-mos
P="$ROOT/patches/llvm-mos"
P1="$P/0001-320-far-addrspace.patch"
P2="$P/0002-321-accum16.patch"
P3="$P/0003-late-opt-txy-dead-flag.patch"
P4=/home/will/SRC/llvm-mos-65816-far-cc/patches/llvm-mos/0004-320-far-cc.patch
WT=/tmp/far-land/wt
OUT=/tmp/far-land/out
NEW1="$OUT/0001-320-far-addrspace.patch"
P5="$OUT/0005-320-far-ptr-value-legalize.patch"
DELTA_FULL=/tmp/far-land/a-delta-full.patch
DELTA_A=/tmp/far-land/a-delta-groupA.patch
GIT_ID=(-c user.email=patchgen@local -c user.name=patchgen)
MOSREL=llvm/lib/Target/MOS
# files owned by no new patch (drift + FF-stale):
EXC_CMAKE='clang/cmake/caches/MOS.cmake'
EXC_REPSEP="$MOSREL/MOSInsertREPSEP.cpp"
MOSLEG="$MOSREL/MOSLegalizerInfo.cpp"

mkdir -p "$OUT"
PRISTINE="$(git -C "$VENDOR" rev-parse HEAD)"
echo "==> pristine vendor HEAD: $(git -C "$VENDOR" rev-parse --short HEAD)"

cleanup() { git -C "$VENDOR" worktree remove --force "$WT" 2>/dev/null || true
            git -C "$VENDOR" worktree prune 2>/dev/null || true; rm -rf "$WT"; }
trap cleanup EXIT
cleanup
reset_wt() { git -C "$WT" reset -q --hard "$PRISTINE"; git -C "$WT" clean -qfdx; }
seqapply() { for p in "$@"; do git -C "$WT" apply --check "$p" && git -C "$WT" apply "$p"; done; }

############################################################################
echo; echo "######## PHASE 1: Reference R + extract (a)-delta (full + Group-A) ########"
git -C "$VENDOR" worktree add -q --detach "$WT" "$PRISTINE"
seqapply "$P1" "$P2" "$P3" "$P4"; echo "   R = 0001+0002+0003+0004 applied in sequence (sequence-apply check PASS)"
git -C "$WT" add -A; git "${GIT_ID[@]}" -C "$WT" commit -q -m "R"
rsync -a --delete "$FF/clang/"   "$WT/clang/"
rsync -a --delete "$FF/$MOSREL/" "$WT/$MOSREL/"
git -C "$WT" add -A
git -C "$WT" diff --cached -- clang/ "$MOSREL/" > "$DELTA_FULL"
git -C "$WT" diff --cached -- clang/ "$MOSREL/" \
     ":!$EXC_CMAKE" ":!$EXC_REPSEP" ":!$MOSLEG" > "$DELTA_A"
echo "   full (a)-delta : $(grep -c '^diff --git' "$DELTA_FULL") files"
echo "   Group-A delta  : $(grep -c '^diff --git' "$DELTA_A") files (excludes MOS.cmake, MOSInsertREPSEP, MOSLegalizerInfo)"

############################################################################
echo; echo "######## PHASE 2: new-0001 = main-0001 + Group-A (must apply on 0001-alone) ########"
reset_wt
seqapply "$P1"
git -C "$WT" apply --check "$DELTA_A" && git -C "$WT" apply "$DELTA_A"
echo "   Group-A delta applied CLEAN on 0001-alone"
git -C "$WT" add -A
git -C "$WT" diff --cached > "$NEW1"
echo "   new-0001: $(wc -l < "$NEW1") lines, $(grep -c '^diff --git' "$NEW1") files"
echo "   a16-free check (added/removed lines referencing a16, expect 0 each):"
echo "      +mos-a16=$(grep -E '^[+-]' "$NEW1"|grep -v '^[+-][+-]'|grep -c 'mos-a16')  Ac16=$(grep -E '^[+-]' "$NEW1"|grep -v '^[+-][+-]'|grep -c 'Ac16')  hasAccum16=$(grep -E '^[+-]' "$NEW1"|grep -v '^[+-][+-]'|grep -c 'hasAccum16')  mos-farcc=$(grep -E '^[+-]' "$NEW1"|grep -v '^[+-][+-]'|grep -c 'mos-farcc')"

############################################################################
echo; echo "######## PHASE 3: T4 = new-0001+0002+0003+0004; isolate 0005; prove Group-A completeness ########"
reset_wt
seqapply "$NEW1" "$P2" "$P3" "$P4"; echo "   new-0001+0002+0003+0004 applied in sequence (PASS)"
git -C "$WT" add -A; git "${GIT_ID[@]}" -C "$WT" commit -q -m "T4"
rsync -a --delete "$FF/clang/"   "$WT/clang/"
rsync -a --delete "$FF/$MOSREL/" "$WT/$MOSREL/"
git -C "$WT" add -A
echo "   files where T4 differs from FF (expect EXACTLY: MOS.cmake, MOSInsertREPSEP.cpp, MOSLegalizerInfo.cpp):"
git -C "$WT" diff --cached --name-only -- clang/ "$MOSREL/" | sed 's/^/      /'
# 0005 = the MOSLegalizerInfo PF-value change (T4 -> FF)
git -C "$WT" diff --cached -- "$MOSLEG" > "$P5"
echo "   wrote 0005 ($(grep -c '^diff --git' "$P5") file): $P5"
# Assertion A: nothing else (outside the 3 known files) differs -> Group-A reproduced all the rest
LEFT="$(git -C "$WT" diff --cached --name-only -- clang/ "$MOSREL/" ":!$EXC_CMAKE" ":!$EXC_REPSEP" ":!$MOSLEG")"
if [ -z "$LEFT" ]; then echo "   ASSERT-A PASS: Group-A reproduces everything except the 3 documented files"
else echo "   ASSERT-A FAIL: unexpected residual diffs:"; echo "$LEFT"; exit 1; fi

############################################################################
echo; echo "######## PHASE 4: FINAL ROUND-TRIP — new-0001+0002+0003+0004+0005 == FF ########"
reset_wt
seqapply "$NEW1" "$P2" "$P3" "$P4" "$P5"; echo "   full stack applied in sequence (PASS)"
git -C "$WT" add -A; git "${GIT_ID[@]}" -C "$WT" commit -q -m "T5"
rsync -a --delete "$FF/clang/"   "$WT/clang/"
rsync -a --delete "$FF/$MOSREL/" "$WT/$MOSREL/"
git -C "$WT" add -A
RES="$(git -C "$WT" diff --cached --name-only -- clang/ "$MOSREL/" ":!$EXC_CMAKE" ":!$EXC_REPSEP")"
if [ -z "$RES" ]; then
  echo; echo "RESULT: PASS — new-0001+0002+0003+0004+0005 reproduces FF EXACTLY over clang/ + $MOSREL/"
  echo "        (excluding the 2 documented drift/stale files: $EXC_CMAKE, $EXC_REPSEP)"
else
  echo; echo "RESULT: FAIL — residual diffs vs FF:"; echo "$RES"; exit 1
fi