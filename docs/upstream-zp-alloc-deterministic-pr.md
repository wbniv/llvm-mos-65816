# [MOS] Make zero page allocation deterministic

<!-- RE-SYNCED 2026-09-14: H1 = published title, body below = the published description
     (docs/pr-revisions/2026-09-13/590-body.md) at branch head `532900273ba9` (heads.json). Also MERGED upstream as `742d554bf080`.
     Fork-patch follow-ups: docs/plans/2026-09-14-fork-patch-followups.md. Original banner follows. -->
<!-- MINTED + VERIFIED ON TIP 2026-08-04 — READY TO POST (posting is user-triggered).
     Branch: mos-zp-alloc-deterministic @ cc9f0d027813 (comment-only amend of 1c3deb0: test-comment tallies harmonized to the recorded 20-run data; code identical), local in ~/llvm-mos, cut from upstream tip
     1f334fef02b5 (patch 0021 applied clean; commit parent verified = tip). Verified in
     ~/llvm-mos/build-pr: RED = zp-alloc-deterministic.ll FAILS without the fix on the same tree;
     GREEN = passes, stable across 5 repeat runs; full CodeGen/MOS = 80 tests, 79 pass +
     getchar-regression.ll skipped by its own in-tree `UNSUPPORTED: target={{.*}}` (upstream
     FIXME, disabled for everyone), 0 failures; MC suite 39/39.
     CORRECTION 2026-08-04 (user caught it pre-publish): the earlier "5 failures, pre-existing
     on pristine tip" claim was FALSE — all 5 were exit-127 tool-missing artifacts of the
     minimal build-pr tool set (opt for the nonreentrant/indvar/indexiv/leaf tests;
     llvm-readelf for MC's addr-asciz). "Pre-existing on pristine tip" was vacuously true
     because pristine tip lacked the same binaries. Upstream was never failing. METHODOLOGY
     RULE for future preps: before quoting suite numbers, build the tools the suite RUNs
     (at minimum: llc llvm-mc llvm-objdump llvm-readelf opt FileCheck not count split-file),
     and treat any exit-127 / 'command not found' in a lit log as an environment defect, never
     as a test failure.
     Post commands (user-triggered):
       git -C ~/llvm-mos push origin mos-zp-alloc-deterministic
       gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-zp-alloc-deterministic --base main \
         --title "[MOS] Make zero page allocation deterministic (pointer-hash iteration order decided the winners)" \
         --body-file <(sed '2,/^-->$/d; 1d' docs/upstream-zp-alloc-deterministic-pr.md)
     (sed note: the range needs the terminator ALONE on its line — '^-->$' — which also keeps
     this command from matching itself; a bare /-->/ range stops at this very line and leaks
     the rest of the banner into the posted body. Verify the extraction is non-empty and
     starts at "## Summary" before posting.)
     After posting: flip status row 17 and refresh wald3n.com (task open-source:refresh +
     task publish) — note wald3n also still needs the #589 refresh.
     Original draft note follows.
     DRAFT 2026-08-01 (posting is user-triggered; branch not yet minted at that time).
     Provenance: the lzss-gallery non-reproducible-build investigation,
     the discarded throwaway investigation worktree (branch
     throwaway/gallery-repro-bisect, worktree, discarded per policy — the durable record is this body's Reproduction/Verification sections + status row 17).
     Fork patch: patches/llvm-mos/0021-mos-zp-alloc-deterministic.patch.
     Verified 2026-07-31 on a rebuilt toolchain — see the Verification section below; the
     earlier "do not post until verified" block is cleared.
-->

Zero-page allocation can choose different globals for identical inputs when candidate scores tie. Pointer-ordered iteration also affects entry-point ordering and floating-point accumulation of candidate benefits.

Use insertion-ordered containers at the three relevant iteration sites. Document the determinism requirement without promising a particular iteration order.

The regression gives eight equally beneficial globals four bytes of zero page and checks a consistent allocation. Independent downstream testing in this thread also confirms reproducible full-LTO binaries with the change.

Validation: MOS CodeGen suite 79 pass, 1 unsupported; 20 separate llc runs produce byte-identical assembly.
