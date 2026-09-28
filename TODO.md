# TODO — current work

llvm-mos-65816 brings an optimizing C compiler to the WDC 65816 through [llvm-mos](https://github.com/llvm-mos/llvm-mos), with the SNES platform as a runtime test. See the [roadmap](docs/ROADMAP.md), [upstream submission tracker](docs/upstream-pending-work.md), and [plan index](docs/investigations/plan-index.md).

This file tracks actions that remain. The [September 28 history snapshot](TODO-history-2026-09-28.md) preserves the detailed completed entries and Inbox dispositions that previously lived here. Its statuses and measurements are dated evidence; use linked canonical defect records and current trackers for present status.

**Markers:** `[T0]`–`[T5]` are the delegation tiers defined in [CLAUDE.md](CLAUDE.md); `[wip Tn]` means in progress and `[verify Tn]` means implementation exists but the linked verification record is incomplete. Non-trivial work gets a plan in `docs/plans/`. A completed implementation and its upstream extraction are separate actions.

## Open

### M2 — Optimizing Payoff

- [T4] **Prepare 0065 near-store profitability for upstream review.** Extract the completed optimization with its #321 prerequisites, reconcile the exact destination revision, validate the extracted patch and obtain independent review. Preserve the local completion evidence and loaded-pointer fallback; the earlier 0063 review does not cover 0065. [Remaining upstream work](docs/plans/2026-09-27-broader-near-store-profitability.md#repository-delivery-and-remaining-upstream-work) · [Submission prerequisites](docs/pr-preparations/2026-09-26/feature-held-packages.md).

- [T4] **Resolve the carry-scheduling pressure contract and profitability choice.** Compare a cheaper predictor and shared-frontend implementation with the measured 0064 policies on unseen inputs, then choose a default only with correctness and size evidence. The current compiler defaults to `always`; the separate XY16 `vlastack_sim` miscompile is [fixed locally](docs/defects/mos-xy16-stale-x-writer-reload.json). [Canonical pressure record](docs/defects/mos-carry-scheduling-pressure.json) · [profitability report](docs/investigations/2026-09-27-carry-profitability-model.md).

- [T4] **Prepare near-index overflow-proof recovery for upstream review.** Extract the completed pass from `0002` with its #321 and bank-wrap prerequisites, reconcile the exact destination revision, validate the extracted source/tests and obtain independent review. Preserve the measured size regressions and runtime evidence when describing profitability. [Investigation](docs/investigations/2026-09-27-near-index-overflow-proofs.md) · [Submission prerequisites](docs/pr-preparations/2026-09-26/feature-held-packages.md).

- [T4] **Investigate runtime-indexed native-word far loads for Farblit `rdw`.** Not started. The current probe uses a native 16-bit `lda [dp]` after explicit scaled-pointer computation; the runtime-index fold accepts only byte accesses. Reconcile 0062 and the live lowering, then measure a native-word `[dp],Y` candidate, including scaled-index bounds, bank crossing and M/X transitions. Require size/runtime evidence before adopting it. [Reconciled instruction shapes](docs/investigations/2026-09-27-farblit-byte-load.md#instruction-shape-reconciliation-2026-09-28).

- [T4] **Investigate the A16 Farblit `cp8` range proof.** Not started. The compiler bounds `j + 8` at 263 although this loop visits `j = 0..47`, so the source load computes its pointer explicitly in A16. Investigate a sound loop-range proof or address canonicalization that permits Y8 indexing while preserving integer wrapping and bank crossing. Measure code size and runtime; retain the existing fallback until the candidate is proved correct and worthwhile. [Range limitation and evidence](docs/investigations/2026-09-27-farblit-byte-load.md#controlled-byte-split-experiment).

### Test Bench / CI

- [T3] **Run the 138-demo build-determinism gate sweep.** Run and record the full sweep on the rebuilt fixed toolchain. The corpus, `corpus-a16`, and four demos whose `main` changed beyond the `sec` permutation passed; the complete 138-demo sweep remains open. [Plan and results](docs/plans/2026-09-14-eliminate-build-nondeterminism.md).

- [verify T2] **Complete the live upstream dashboard outage check.** Keyboard-only navigation and JavaScript-disabled rendering passed on the published page on 2026-09-28. Still force the server-side GitHub fetch to fail and verify the stale-data fallback, then update the [release plan](docs/plans/2026-09-26-live-upstream-dashboard.md#published-page-checks-recorded-2026-09-28).

### Upstream / Contribution

The [submission tracker](docs/upstream-contribution-status.md) owns PR state and posting order. A local fix marked complete elsewhere in this repository does not mean its upstream extraction, review, or publication is complete.

- [wip T2] **Follow SDK PR #450 for `longjmp(env, 0)`.** Respond to maintainer review and CI, then record the outcome in the [tracker](docs/upstream-pending-work.md#research-notes-and-evidence). The 20/20 simulator validation is retained there.
- [wip T2] **Follow compiler PR #604 for MVN/MVP bank order.** Handle review and CI for the posted encoding fix; keep simulator setup in its [separate discussion draft](docs/pr-preparations/2026-09-20/65816-simulator-discussion-body.md). [Review bundle](docs/pr-preparations/2026-09-20/README.md).
- [T5] **Post the 65816 simulator discussion.** Review the prepared [draft](docs/pr-preparations/2026-09-20/65816-simulator-discussion-body.md) against current upstream context, then post when authorized. It has no merge dependency on PR #604.
- [T4] **Reconcile SNES platform work with llvm-mos-sdk#415.** Build an isolated baseline and file inventory, settle CPU/stack ABI and runtime prerequisites with the maintainer, then validate a reconciled branch. [Plan](docs/415-snes-target-reconciliation.md) · [submission prerequisites](docs/upstream-pending-work.md#snes--separate-platform-track).
- [T4] **Resolve the reentrant contract.** Obtain a semantics decision before choosing a code or documentation change; preserve the separate [defect record](docs/defects/reentrant-attribute-contract.json) and [readiness note](docs/upstream-pending-work.md#what-issue-means-here).
- [T5] **Prepare and post register-exhaustion fix 0029.** Recheck the exact upstream base, create its standalone branch, and publish when authorized. [Reviewed packet](docs/pr-preparations/2026-09-22/0029-claude-review.md) · [PR body](docs/upstream-twoaddr-physreg-reschedule-pr.md).
- [T5] **Prepare and post physical-copy liveness fix 0030.** Recheck current upstream, create the standalone branch, and publish when authorized. [Review](docs/pr-preparations/2026-09-22/0030-claude-review.md) · [PR body](docs/upstream-copy-phys-reg-liveness-pr.md).
- [T5] **Post copy-destination reuse 0031 after 0030 lands.** Revalidate the stacked extraction and publish when authorized. [Validation](docs/pr-preparations/2026-09-22/0031-validation.md) · [PR body](docs/upstream-copy-phys-reg-reuse-dst-pr.md).
- [T5] **Prepare and post register-named assembly symbols 0032.** Check the current upstream revision, then publish the reviewed standalone change when authorized. [Review](docs/pr-preparations/2026-09-23/0032-review-audit.md) · [PR body](docs/upstream-register-named-symbols-pr.md).
- [T4] **Present undef-lane fix 0028 with the #320/#321 series.** The generic refactor is reviewed and validated; the remaining hold is the series presentation. [Pending-work chart](docs/upstream-pending-work.md) · [review](docs/pr-preparations/2026-09-26/0028-review.md).
- [T5] **Post prefetch fixes 0034 and 0035.** Recheck the exact destinations and publish the MOS and Clang changes separately when authorized. [Validation](docs/pr-preparations/2026-09-23/0034-0035-validation.md) · [MOS body](docs/upstream-prefetch-legalize-pr.md) · [Clang body](docs/upstream-clang-prefetch-int16-pr.md).
- [T5] **Post GlobalISel indirect-output fix 0037.** Revalidate the current LLVM packet and publish when authorized. [Validation](docs/pr-preparations/2026-09-26/llvm-validation.md) · [PR body](docs/upstream-gisel-inline-asm-indirect-output-pr.md).
- [T5] **Post return/frame-address fix 0038.** Revalidate the current MOS packet and its stack-depth test, then publish when authorized. [Posting packet](docs/pr-preparations/2026-09-26/README.md) · [PR body](docs/upstream-return-frame-address-pr.md).
- [T5] **Post InlineSpiller coalescing fix 0040.** Confirm the standalone test still reproduces on the exact destination revision, then publish when authorized. [Validation](docs/pr-preparations/2026-09-24/0040-validation.md) · [PR body](docs/upstream-inline-spiller-coalesce-scratch-vregs-pr.md).
- [T5] **Report the upstream Windows AMDGPU CI mismatch if needed.** The [main-run evidence](https://github.com/llvm-mos/llvm-mos/actions/runs/34793262107) predates PR #604; use it when responding to a maintainer or opening a separate issue. [Tracker](docs/upstream-contribution-status.md).
- [T5] **Post GlobalISel multi-register inline asm fix 0041.** Revalidate the current LLVM packet, including AArch64 cases, then publish when authorized. [Posting packet](docs/pr-preparations/2026-09-26/README.md) · [PR body](docs/upstream-gisel-inline-asm-multi-register-pr.md).
- [T5] **Post spill-hoist scratch-register fix 0033.** Recheck current upstream and publish the revised, reviewed extraction when authorized. [Audit](docs/pr-preparations/2026-09-23/0033-review-audit.md) · [PR body](docs/upstream-spill-hoist-scratch-vregs-pr.md).
- [T5] **Post zero-page indexed-global fix 0036.** Recheck the current upstream artifact, then publish the reviewed packet when authorized. [Review](docs/pr-preparations/2026-09-23/0036-review-audit.md) · [PR body](docs/upstream-zero-page-indexed-globals-pr.md).
- [T5] **Post live-`$p` scavenger fix 0011.** Use the stock-6502 witness and current destination revision to prepare the PR; do not include retired 0012. [Reachability evidence](docs/pr-preparations/2026-09-22/0011-stock-6502-reachability.md) · [PR body](docs/upstream-scavenger-live-p-pr.md).
- [T5] **Post the #321 frame-ABI design note.** Recheck the implementation-backed measurements and publish the [note](docs/321-upstream-cc-frame-abi-note.md) when authorized. [Study](docs/plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md).
- [T4] **Prepare #320 far-pointer codegen after ABI agreement.** The downstream implementation is feature-complete; obtain the design decision and extract an upstream-reviewable series. [Tracker](docs/upstream-contribution-status.md) · [reconciliation plan](docs/415-snes-target-reconciliation.md).
- [T1] **Decide whether to enable automatic CI triggers.** Check the repository's current visibility and runner cost, then add `push`/`pull_request` triggers to [.github/workflows/smoke.yml](.github/workflows/smoke.yml) if appropriate. The workflow remains manual-only.
- [T4] **Prepare null-output streamer fix 0068 for upstream review.** The standalone extraction has exact-revision validation; obtain independent review and publish when authorized. [Validation](docs/pr-preparations/2026-09-27/0068-validation.md) · [defect record](docs/defects/mos-null-output-streamer-crash.json).
- [T5] **Advance the ready MOS and LLVM posting packets.** Use the [September 26 packet](docs/pr-preparations/2026-09-26/README.md) for exact artifacts, destination checks, review state, and dependency order; post individual fixes only when authorized and update the [tracker](docs/upstream-contribution-status.md) for each result.

### Distribution / Packaging


## Watch

Review these when their stated trigger occurs; they are not ready-to-run tasks.

- **Upstream #585 (`G_ASHRE` legalization):** on the next vendor rebase, reconcile its legalizer/combiner changes with `0002` and the native ASHR lowering. [Submission tracker](docs/upstream-contribution-status.md).
- **A16/ZP pressure:** reopen the rejected `Ac16` residency idea only if a realistic new overflow reproduces; the measured spike gave no pressure relief and grew code. Investigate a different remedy first. [Verdict](docs/investigations/2026-06-26-a16-phase3-prera-residency-spike.md).

## Parked

- **Verify and publish the cross-platform toolchain packages.** Parked 2026-09-28 at the user’s request. Linux arm64 and Windows x86-64 packages are built; the real-Windows functional compiler check and publication remain. [Plan and completed build evidence](docs/plans/2026-06-25-cross-platform-toolchain-builds.md).

- **Recheck the factorial stall only if certainty is needed.** Run the pre-`3ab028e` gate under LTO and record the outcome; the retained analysis favors a timing explanation and does not establish a compiler defect. [Evidence](docs/plans/2026-06-28-321-verify-lto-a16-bitmask-early-exit-diagnosis.md).

- **Implement exhaustive 65816 opcode roundtrip coverage when resumed.** The user deferred the [plan](docs/plans/2026-09-25-65816-all-opcode-roundtrip.md); its acceptance gate covers 256 opcodes in four M/X contexts, independent expected bytes, instruction boundaries, and reassembly.

- **Automate the live upstream dashboard** — parked 2026‑09‑27 until next week’s token reset; was ranked T2. Its [plan](docs/plans/2026-09-26-live-upstream-dashboard.md) leaves automated candidate review and cache invalidation from GitHub events as remaining work; the released dashboard does not depend on them. Reason for T2: bounded tooling with a written spec.
- **Add real lowercase glyphs (extend both fonts to `0x20..0x7F`).** `_title_glyph` currently
  folds `a-z`→`A-Z` at render time, so titles render as caps; five demo titles are written in mixed
  case (`NaN / POLES`, `div_t / lldiv_t`, `MEDIAN 3x3`, `i & -i`, `s8/16/32/64`). Extending the range
  costs +512 B font8, +2048 B font16 in the near-code window (`mandel-double` already needs
  `TITLE_FONT16_FAR` at 4 KB), and widens the title's VRAM CHR footprint by 5 KB — check no demo's
  VRAM lands in the newly clobbered window. `` ` ``, `{`, `|`, `}`, `~` come free with the same
  extension (none is used by any title today; `dev/title-charset.sh` gates them). Deleting the two
  folding lines is the whole render-side change.
- **#320 post design note upstream** (user-triggered). Post the drafted note
  ([docs/320-upstream-far-pointer-note.md](docs/320-upstream-far-pointer-note.md)) to #320 / the
  llvm-mos Discord (@asiekierka/@mysterymath) — bring a running implementation, not a question.
  Note is drafted & ready; posting is the manual step. **Now also carries a "Code model: near vs far"
  section** (2026-06-22): near=`small`/default, far=`medium/large`/per-symbol → no `-mcmodel` mode; the
  SNES near-code budget is a link-time contract enforced in the SDK platform (see the [history snapshot](TODO-history-2026-09-28.md)).
- **Coherent a16 16-bit lane-model widening (option A from the G_ADD/G_SUB lanes verdict)** — the
  1.48% prize (20 corpus slices improve, best −929 B) is real but unreachable by changing `G_ADD`
  alone: with `G_LOAD`/`G_STORE`/`G_PHI`/shifts/`G_SELECT` still byte-lane, a 16-bit add is a
  marshalling island and nets **+281 B corpus-wide**. Requires widening the whole lane model
  together — roadmap-sized. First diagnostic on reopen: the undefined-physreg verifier failures at
  the s16 carry seam (`pcooker_sim`, `rdiff_sim`).
  [investigation](docs/investigations/2026-08-04-g-add-sub-s16-lanes.md).
- **HDMA backdrop gradient for the trimerge page** — visual-polish idea deferred from the
  [99b trimerge visual fix](docs/plans/2026-07-27-99b-trimerge-visual-fix.md) because snesgfx has
  no HDMA-gradient support yet; revisit if/when the library grows one (the blossom HUD's HDMA
  mode-split is the closest existing machinery).
- **Mesen2 as a third emulator** — abandoned for now: the prebuilt crashes on 26.04
  (glibc-2.43) and headless `--testrunner` won't run Lua; would need a source build against 26.04.
  MAME + bsnes-jg already give a two-emulator cross-check, so this is shelved unless a third opinion
  is needed. [second-emulator plan](docs/plans/2026-06-14-second-emulator-cross-check-bsnes-jg.md).
- **Formal #320/#321 psABI document** — deferred as premature: llvm-mos is implementation-first
  (@mysterymath won't bless an ABI ahead of a high-quality implementation). Promote once a credible
  implementation exists or the maintainers ask. Overlaps the WDC816CC/ORCA-C prior-art item above.
  [upstream design-note plan](docs/plans/2026-06-14-320-upstream-design-note.md).
