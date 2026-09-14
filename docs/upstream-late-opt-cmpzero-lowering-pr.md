# [MOS] Mark CmpZero as a terminator

<!-- RE-SYNCED 2026-09-14: H1 = published title, body below = the published description
     (docs/pr-revisions/2026-09-13/589-body.md) at branch head `9aead7afaa4a` (heads.json).
     Fork-patch follow-ups: docs/plans/2026-09-14-fork-patch-followups.md. Original banner follows. -->
<!-- ✅ POSTED 2026-08-04 as https://github.com/llvm-mos/llvm-mos/pull/589.
     Body below minus the H1 and this comment is the as-posted text.
     Branch: mos-late-opt-cmpzero-lowering @ 8c8d28b0c35a (cherry-pick repair of f8cfe68b after a
     shared-clone branch-switch race; pushed), cut from upstream
     tip 1f334fef02b5 (patch 0022 applied clean). Verified in ~/llvm-mos/build-pr:
     RED = late-opt-cmpzero-after-fold.mir FAILS without the fix on the same tree;
     GREEN = passes with it; full CodeGen/MOS suite: 79 pass, 0 failures
     (getchar-regression.ll is upstream-disabled via its own UNSUPPORTED directive). [CORRECTED 2026-08-04: the earlier '5 pre-existing failures on pristine tip' / '39/40 lone failure' claims were exit-127 tool-missing artifacts of the minimal build-pr tool set (opt, llvm-readelf absent); with the tools built the suites are fully green — CodeGen 79 pass + getchar-regression.ll upstream-disabled (UNSUPPORTED: target), 0 failures; MC 39/39 (+ the branch's own new tests). Rule: build the tools the suite RUNs before quoting numbers; exit-127 in a lit log is an environment defect.]
     Post commands (user-triggered):
       git -C ~/llvm-mos push origin mos-late-opt-cmpzero-lowering
       gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-late-opt-cmpzero-lowering --base main \
         --title "[MOS] mos-late-opt: don't skip CmpZero lowering after the block's first fold" \
         --body-file <(sed '2,/^-->$/d; 1d' docs/upstream-late-opt-cmpzero-lowering-pr.md)
     After posting: flip the status-doc row and refresh wald3n.com's contributions snapshot
     (task open-source:refresh + task publish in ~/wald3n.com).
-->

Mark CmpZero as a terminator so the machine verifier rejects ordinary instructions placed after it. Restrict `lowerCmpZeros` to the block's terminator range.

Keep each pseudo's fold decision separate from the pass's change accumulator, and report a change when deleting a dead comparison. Tests cover the rejected non-terminator placement, adjacent comparisons that require independent folding/lowering, and removal of a dead comparison. Existing late-optimization tests cover the ordinary single-comparison paths.

The original PR's reproducer placed a normal instruction after CmpZero. That placement violates the intended invariant; this revision encodes and tests the invariant explicitly.

Validation: MOS CodeGen suite 80 pass, 1 unsupported (Linux, assertions enabled).
