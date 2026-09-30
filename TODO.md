# TODO — current work

llvm-mos-65816 brings an optimizing C compiler to the WDC 65816 through [llvm-mos](https://github.com/llvm-mos/llvm-mos), with the SNES platform as a runtime test. See the [roadmap](docs/ROADMAP.md), [upstream submission tracker](docs/upstream-pending-work.md), and [plan index](docs/investigations/plan-index.md).

This file tracks actions that remain. The [September 28 history snapshot](TODO-history-2026-09-28.md) preserves the detailed completed entries and Inbox dispositions that previously lived here. Its statuses and measurements are dated evidence; use linked canonical defect records and current trackers for present status.

**Markers:** `[T0]`–`[T5]` are the delegation tiers defined in [CLAUDE.md](CLAUDE.md); `[wip Tn]` means in progress and `[verify Tn]` means implementation exists but the linked verification record is incomplete. Non-trivial work gets a plan in `docs/plans/`. A completed implementation and its upstream extraction are separate actions.

## Open

### M2 — Optimizing Payoff


- [T4] **Resolve the carry-scheduling pressure contract and profitability choice.** Compare a cheaper predictor and shared-frontend implementation with the measured 0064 policies on unseen inputs, then choose a default only with correctness and size evidence. The current compiler defaults to `always`; the separate XY16 `vlastack_sim` miscompile is [fixed locally](docs/defects/mos-xy16-stale-x-writer-reload.json). [Canonical pressure record](docs/defects/mos-carry-scheduling-pressure.json) · [profitability report](docs/investigations/2026-09-27-carry-profitability-model.md).

- [T4] **Prepare native-word speed policy 0070 for upstream review.** The policy is integrated and installed locally: `-O2`/`-O3` enable bounded M16/Y8 indexing while `-Os`/`-Oz` preserve baseline output. Complete Farblit `main` at `-O2` uses 7.12%/7.74% fewer master clocks and is 13/38 bytes smaller in A16/XY16; the `-O3` A16 tradeoff is +46 bytes for 7.29% fewer master clocks. The [working PR draft and evidence guide](docs/pr-preparations/2026-09-28/far-word-index/README.md) include proof/dependency diagrams and a source audit of upstream `26d7c2c1eebf`. [Independent downstream AI source review](docs/pr-preparations/2026-09-28/far-word-index/independent-review.md) found no valid-input compiler correctness defect. The P2 0069 assertion finding is resolved: explicit opcode boundaries reject all 156 wrong substitutions and four focused files pass. The [extracted candidate](docs/pr-preparations/2026-09-28/far-word-index/upstream-series.md) now has ordered patches, an assertions build, added focused coverage and separate backend replay evidence. The earlier Farblit full-LTO figures above are downstream measurements; replaying frozen post-LTO IR with the pinned candidate reduces clocks by 7.78%/7.81% at O2 (A16/XY16), with main sizes 3279→3168 and 3214→3185 bytes. This backend replay is not a new frontend/LTO comparison. The 58 emulator configurations pass. The [September 30 rebase](docs/pr-preparations/2026-09-30/far-word-rebase/README.md) onto `06bc967d2668` keeps every patch body and reproduces the suites, sensitivity checks and all 58 emulator configurations byte for byte. Its [independent review](docs/pr-preparations/2026-09-30/far-word-rebase/independent-review.md) upholds 0069 and 0070 but blocks filing on the far prerequisite: four downstream defects ([ABI exhaustion](docs/defects/mos-far-pointer-arg-exhaustion.json), [lengths above 65535](docs/defects/mos-far-memop-length-truncation.json), [non-65816 CPUs](docs/defects/mos-far-access-non-65816.json), [undef debug values](docs/defects/mos-far-index-fold-dangling-dbg.json)), two extraction gaps and a register collision with open #594. Repair them in the [#320/#321 split series](docs/plans/2026-09-30-split-320-321-series.md), then re-review. [Policy and evidence](docs/investigations/2026-09-28-far-word-policy.md).

- [T4] **Prepare the bounded Farblit range proof for upstream review.** Patch 0069 is integrated and installed locally: A16 `cp8` uses Y8, full LTO saves 101 bytes at `-Os`, and all 36 LTO ROM configurations pass MAME and bsnes. The 26-case MIR regression, original gate and 16 sensitivity tests pass. Broader `-Os` results have no growing object in the 16-fixture sample; retain the `-O2` XY16 tradeoff of +24 bytes and 2.72% fewer Farblit master clocks. [Independent AI source review](docs/pr-preparations/2026-09-28/far-word-index/independent-review.md) found no valid-input compiler correctness defect. The P2 opcode-boundary finding is resolved: all 78 assertions use explicit delimiters, all 156 deliberately wrong opcode substitutions are rejected, all three correct outputs pass, and four focused regression files pass. The [exact-base extraction](docs/pr-preparations/2026-09-28/far-word-index/upstream-series.md) supplies the patches, executed checks and frozen-IR backend replay. The full-LTO figures above remain downstream measurements and are separate from that backend replay. The [September 30 rebase](docs/pr-preparations/2026-09-30/far-word-rebase/README.md) onto `06bc967d2668` keeps every patch body and reproduces the suites, sensitivity checks and all 58 emulator configurations byte for byte. Its [independent review](docs/pr-preparations/2026-09-30/far-word-rebase/independent-review.md) upholds 0069 and 0070 but blocks filing on the far prerequisite: four downstream defects ([ABI exhaustion](docs/defects/mos-far-pointer-arg-exhaustion.json), [lengths above 65535](docs/defects/mos-far-memop-length-truncation.json), [non-65816 CPUs](docs/defects/mos-far-access-non-65816.json), [undef debug values](docs/defects/mos-far-index-fold-dangling-dbg.json)), two extraction gaps and a register collision with open #594. Repair them in the [#320/#321 split series](docs/plans/2026-09-30-split-320-321-series.md), then re-review. [Integrated proof, size/runtime evidence and suite qualifications](docs/investigations/2026-09-28-farblit-range-integration.md).

- [wip T2] **Fix far-pointer argument exhaustion (B1).** A fourth far-pointer argument takes a 16-bit RS pair and crashes the compiler; add the soft-stack fallback after the far-pointer CC rules. Ranked T2: the reviewer gave the rule and the tests. [Record](docs/defects/mos-far-pointer-arg-exhaustion.json) · [plan](docs/plans/2026-09-30-far-prerequisite-defects.md). <!-- agent:a66c88f07a12aa702 -->

- [wip T3] **Fix far memory lengths above 65535 (B2).** Far memset/memcpy/memmove silently truncate longer lengths; keep the 16-bit runtime entry for provable lengths and route the rest to new 32-bit-length entries, with a >64 KiB emulator check. Ranked T3: runtime and compiler change with a settled design. [Record](docs/defects/mos-far-memop-length-truncation.json) · [plan](docs/plans/2026-09-30-far-prerequisite-defects.md). <!-- agent:a66c88f07a12aa702 -->

- [wip T2] **Reject far memory accesses on non-65816 CPUs (B3).** Runtime far loads and stores on 6502-family CPUs silently emit `$A7`; report a clear diagnostic instead. Ranked T2: one guard plus negative tests. [Record](docs/defects/mos-far-access-non-65816.json) · [plan](docs/plans/2026-09-30-far-prerequisite-defects.md). <!-- agent:a66c88f07a12aa702 -->

- [wip T2] **Drop undef debug values after the far index fold (B4).** `-g` builds fail `-verify-machineinstrs` after the byte or word far index fold; set the orphaned `DBG_VALUE` to `$noreg`. Ranked T2: bounded, known repair. [Record](docs/defects/mos-far-index-fold-dangling-dbg.json) · [plan](docs/plans/2026-09-30-far-prerequisite-defects.md). <!-- agent:a66c88f07a12aa702 -->

- [wip T3] **Keep native-width registers out of default-mode register pressure.** The first #321 commit adds opt-in A16/X16/Y16 register classes that change the generated pressure sets, growing default mos6502 output by 1.2% (+3,478 bytes on the split's fixed set). Test `GeneratePressureSet = 0` in isolation, then apply it to #321 commit 1 and `0002`. Ranked T3: one-flag hypothesis with existing comparison tooling; escalates to T4 if not neutral. [Plan](docs/plans/2026-09-30-native-register-pressure-sets.md). <!-- agent:a215decb9d21d92de -->

- [T4] **Repair XY16 preserveX status-register saves.** `preserveX` saves `$p` as defined after a call clobbered its flags, which fails the machine verifier on the recovered-IR boids.c XY16 input; repair it in `0002` and the #321 prerequisite with a red/green on the retained IR. Ranked T4: liveness root cause spans preserveX and the scavenger P save. [Record](docs/defects/mos-xy16-preserve-x-p-save.json).

### Test Bench / CI


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

- **Live upstream dashboard outage check.** Retired 2026-09-28 at the user's request. A local Wrangler failure simulation showed the bundled snapshot and stale warning remain visible; the production worker's outage behavior remains unverified. [Release record](docs/plans/2026-09-26-live-upstream-dashboard.md#local-failure-simulation-and-retirement-2026-09-28).

- **Verify and publish the cross-platform toolchain packages.** Parked 2026-09-28 at the user's request. Linux arm64 and Windows x86-64 packages are built; the real-Windows functional compiler check and publication remain. [Plan and completed build evidence](docs/plans/2026-06-25-cross-platform-toolchain-builds.md).

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


## Inbox — auto-captured plan deferrals

_Auto-added from plan "Out of scope"/"Deferred" sections at commit time. Triage each into M1/M2/etc. and delete it here — it will not come back._

<!-- BEGIN auto-captured-deferrals (managed by audit-plan-deferrals.sh — triage these into the curated sections above; the fingerprint ledger means a deleted item is NOT re-added) -->
<!-- triaged 2026-09-30: split-series verification is the in-progress split work (live agent); covered by the 0069/0070 items, which route their repairs through that series. -->
<!-- triaged 2026-09-30: carrying the repairs into the extracted #320 series is covered by the 0069/0070 items, which route them through the split series. -->
<!-- triaged 2026-09-30: B5 and B7 are covered by the 0069/0070 items (extraction gaps and the #594 collision). -->
<!-- triaged 2026-09-30: dropped; no measured need to tune the 32-bit far runtime entries. Revisit only if one appears in a hot path. -->
<!-- triaged 2026-09-30: plan verification is covered by the B1-B4 items now in progress. -->
<!-- triaged 2026-09-30: plan verification is covered by the in-progress T3 pressure-set item. -->
<!-- END auto-captured-deferrals -->
