# Refresh the standalone 0029 compiler PR

Requested October 10, 2026: reconcile the existing register-exhaustion fix with the exact current llvm-mos revision, prepare a standalone branch, validate the reproducer and regressions, and show a PR preview before posting. No PR publication is authorized by this preparation request.

Attribution: OpenAI Codex CLI 0.162.0; model `gpt-6.1-sol`; medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`. Earlier diagnosis and independent-review credits remain in their original records.

## Prior work and destination

The original entry point is [the mixed-width-call report](../upstream-mixed-width-call-regalloc-issue.md). The [existing draft](../upstream-twoaddr-physreg-reschedule-pr.md), [September validation](../pr-preparations/2026-09-22/0029-validation.md), [independent review](../pr-preparations/2026-09-22/0029-claude-review.md), patch 0029, Git history and current source are the starting evidence. This is a refresh of an existing causal defect, not a new discovery. Historical compiler/binary identities and full cross-target results remain scoped to their recorded revisions.

GitHub `main` resolves to `0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63`, the new downstream pin. The destination helper retains the physical-copy hoist and lacks the class-availability guard. Its entry gate now requires LiveIntervals; upstream `8068182dd6fb1a8efae0291db1d2462d29025cd1` removed the LiveVariables path. Inspecting only the helper would miss that reachability change. Update the regression to exercise LiveIntervals and separately check the no-analysis contract.

## Work and verification

1. Retain the upstream revision/history snapshot, exact existing C/IR/MIR inputs, source inspection and prior-work reconciliation. Preserve all September evidence.
2. Use private source/build copies; restore the source to the exact unpatched destination and retain its backend identities and failing/passing MIR/IR outputs before adding the standalone change. Build the candidate frontend once; it is unchanged by 0029, and can emit identical inputs for both retained backends. Record the split frontend/backend baseline commands explicitly. Shared toolchains and the completed re-pin evidence stay unchanged.
3. Apply only the 0029 implementation and its two tests. Refresh analysis-specific RUN lines and checks without changing the implementation unless destination evidence requires it. Create a local standalone branch and retain the exact commit/diff.
4. Run the original C optimization/verifier matrix, matching-input MIR/IR red/green checks and complete MOS CodeGen/MC suites. Report any current non-reproduction accurately; do not extend the historical cross-target or runtime results to this build.
5. Refresh the proposed body, local preview and current tracking claims with exact new evidence and preserved authorship. Review document impacts, register dependencies, regenerate views and inventory, and record substantive reviews. Show the preview for posting approval.

## Status

Source/history reconciliation, local branch commit `367513ea6a79`, retained matching-input IR/MIR red/green, and complete MOS CodeGen/MC validation are complete (140 passed, one unsupported, zero failures). Verification: PASS. The candidate frontend build completed; all 24 full-driver and 24 candidate-backend C checks pass. The preserved unpatched backend fails all 20 optimized split-pipeline runs and passes four O0 runs. The draft preview is ready for user review; no PR has been posted.
