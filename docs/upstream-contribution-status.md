# Upstream contribution status — PR progress and submission queue

**Keep the public tracker current:** after updating this document, `upstream-pending-work.md`, `TODO.md`, or other documentation feeding the compiler-work view, commit and push the compiler docs, then run `task open-source:publish` in `/home/will/wald3n.com` and verify https://wald3n.com/open-source. This publication has standing user authorization and belongs to the same update. Follow the [publication workflow](open-source-dashboard-publication.md); do not leave it as a suggested follow-up.

**Compiler re-pin, October 10:** `task upstream:repin` published `0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63` after an isolated Release distribution build and MOS suites (204 passed, four unsupported, zero failures). All 51 active applications remain; none became wholly empty. Hashed historical artifacts 0013/0057/0058/0059 are preserved; bootstrap uses their rebased `-vendor` copies. Independent patch application reproduced the candidate tree. [Full validation](test-results/repin/2026-10-10/full-validation.json) and [publication receipt](upstream-status/repin-20261010T033430Z-ardhs7qy.json). Earlier pin, runtime measurements and submission packets remain dated evidence for their recorded builds; this does not advance SDK pins, validate runtime/performance, or change upstream review prerequisites.

Update: OpenAI Codex 0.162.1; model `gpt-6.1-sol`; medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`.

**SDK #450 and test-suite #20 merged October 10:** mysterymath merged the [runtime fix](https://github.com/llvm-mos/llvm-mos-sdk/pull/450) at `02:09:41 UTC` (`b2b09b72dfca`) and the [restored tests](https://github.com/llvm-mos/llvm-test-suite/pull/20) at `02:10:09 UTC` (`5f38e99463eb`). Their review/landing follow-up is complete. The existing SDK reply’s two cross-repository #20 references were corrected to explicit test-suite links. [Verified merge and link-correction receipt](upstream-status/2026-10-10-sjlj-merges.json). Earlier October 10 publication notices below describe the pre-merge state; retained validation and posted copies remain dated evidence.

**Dated suite-restoration publication notice, before the October 10 merges:** existing [test-suite #20](https://github.com/llvm-mos/llvm-test-suite/pull/20) now includes the repaired and re-enabled battery at `28bfe7e74d8e`. The [follow-up packet](pr-preparations/2026-10-10/sjlj-restoration/README.md) records valid C fixtures, output oracles and a repaired C++ case gated on exception support. With #450’s runtime fix, 24 MOS and 28 host llvm-lit checks pass; the unfixed SDK still fails WhileLoop and longjmp-zero. The existing SDK #450 reply was edited to explain the disable history and the published repair. [Verified publication receipt](pr-preparations/2026-10-10/sjlj-restoration/publication.json). Review/CI remain pending; land the tests once CI uses a fixed SDK. No historical compiler defect is marked fixed.

**Initial SDK review response published October 10 (dated evidence; suite-restoration update above supersedes the original test-suite head and reply):** existing [#450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450) is narrowed to the one-file `setjmp.S` fix at `3cf8d11d71f6`. The regression is posted as [llvm-test-suite #20](https://github.com/llvm-mos/llvm-test-suite/pull/20), head `4ac8bccdeb43`. The [review reply](https://github.com/llvm-mos/llvm-mos-sdk/pull/450#issuecomment-6091769549) proposes landing the test once its CI uses an SDK containing the fix. Initial new CI/review remain pending; the prior changes-requested review is not automatically cleared. [Verified publication receipt](pr-preparations/2026-10-10/sdk450-publication/publication.json).

**Windows test repair appended to #604, October 10:** [commit `bece1fc9`](https://github.com/wbniv/llvm-mos/commit/bece1fc91204e8a2a89903a96183e62a90f18f44) accepts MSVC template-argument spacing in both AMDGPU analysis-preservation checks. Seven focused checks pass; new full Windows CI and review remain pending. [Update comment](https://github.com/llvm-mos/llvm-mos/pull/604#issuecomment-6091475796). The standalone #617 submission was closed at the user's request; its posted body remains dated evidence. Downstream carry 0072 also removes the newer pin's Windows skip. [Receipt](pr-preparations/2026-10-10/windows-amdgpu-rci/publication.json). Our compiler PR total is 15: 12 merged, #604 open, #609 withdrawn, #617 closed unmerged.

**Dated GitHub snapshot, October 9:** compiler #578 merged September 25, #586 September 29, and #584/#588/#589 October 5. Of our 14 compiler PRs, 12 are merged, #604 is open and #609 is withdrawn. SDK #450 remains open with changes requested October 5: mysterymath accepts the code in principle but asks for the regression in `llvm-test-suite`, checking for an existing disabled test first. #320/#321/#594 have no new replies; #594 and SDK #415 remain open. [GitHub receipt](upstream-status/2026-10-09.json).

**Dated pin rebase and patch retirement, October 9:** the bootstrap pin is now `f24948c7d1a4b9f162d4d0192ccceecab1e441ff`, immediately after #589 merged. Merged fixes and their upstream tests come from this revision; they are removed from `0001`/`0002`. Standalone 0003, 0010, 0016, 0019, 0021, 0022, 0024 and 0025 are retired, and upstream vector scalarization makes backport 0049 redundant. Clang 0035 is superseded by LLVM [#221477](https://github.com/llvm/llvm-project/pull/221477), merged September 16; both local artifacts are retired. The remaining stack is rebased; [validation and retained prior aggregates](pr-preparations/2026-10-09/pin-rebase/README.md) distinguish bootstrap checks from compiler testing. Historical standalone artifacts remain available in Git at `dfeb5c9b`. #584's merge prerequisite is satisfied; its parked follow-up is superseded. The #594 coordination hold remains. Earlier patch-retention statements below are dated evidence for their recorded revisions.

OpenAI Codex 0.162.0, model `gpt-6.1-sol`, `medium` reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`.

**#594 coordination comment, October 1 (drafted; posting PARKED by the user until every pending item on the compiler-work page clears, with the #584 follow-up now superseded by its October 5 merge):** the far-word packet's #320‑1 collides with [llvm-mos#594](https://github.com/llvm-mos/llvm-mos/pull/594) (mlund's `Imag32` foundation). The user chose to build on #594 rather than compete with it. The [drafted comment](pr-preparations/2026-10-01/594-comment.md) proposes landing #594 as-is and adopting its numbering, gating RL allocation on mlund's planned SDK contiguity contract with the SNES platform declaring it (a 65816-only gate as fallback), and agreeing on one far address space with mlund's MEGA65 plans. Post with `gh pr comment 594 --repo llvm-mos/llvm-mos --body-file docs/pr-preparations/2026-10-01/594-comment-body.md` after re-reading #594 live. The carried #320 commits are under their second independent review.

**#320/#321 split, third round (October 1; publication status updated October 9):** the [third independent review](pr-preparations/2026-09-30/far-word-rebase/independent-review-3.md)'s N17–N22 and the older N1–N9 items are addressed ([plan](plans/2026-10-01-far-prerequisite-split-carry.md#third-round-n17n22-and-the-older-open-items)). The SPC700 fix hidden in #320‑2 is our #584, merged October 5; after round four the series does not carry it; #584 merged October 5, satisfying that prerequisite. Default-mode checks now cover all 14 MOS CPUs and found two more upstream defects, both unposted: a [HuC6280 block-move miscompile](defects/mos-huc-blockmove-frameindex-offset.json) that #321‑11 fixes as a side effect (not separable: it is the rule #321‑11 needs for its own compares), and an [SPC700 allocator assertion](defects/mos-spc700-hint-outside-order.json). Filing still waits on mlund's #594 answers.

**Far-word rebase, September 30:** the 0069/0070 series is [rebased onto `06bc967d2668`](pr-preparations/2026-09-30/far-word-rebase/README.md) with unchanged patch bodies. The suites, the 228-case sensitivity check and all 58 MAME/bsnes configurations reproduce the September 28 bytes and clocks. The [independent review](pr-preparations/2026-09-30/far-word-rebase/independent-review.md) upholds 0069, 0070 and patches 9–11 but blocks filing. The far prerequisite has four defects that also reproduce downstream: [far-pointer argument exhaustion](defects/mos-far-pointer-arg-exhaustion.json), [far memory lengths above 65535](defects/mos-far-memop-length-truncation.json), [far accesses on non-65816 CPUs](defects/mos-far-access-non-65816.json) and [undef debug values after the far index fold](defects/mos-far-index-fold-dangling-dbg.json). It also has two extraction gaps (a trunc pattern and far-quad DWARF) and an `Imag32` collision with open #594 that needs a maintainer decision. All four are now fixed downstream in `0002`, with same-input red/green closures and a >64 KiB runtime gate ([plan](plans/2026-09-30-far-prerequisite-defects.md)). On October 1 the repairs, the trunc-pattern gap and the #320 formatting and comment cleanups were [carried into the #320 split commits](plans/2026-10-01-far-prerequisite-split-carry.md). The [second independent review](pr-preparations/2026-09-30/far-word-rebase/independent-review-2.md) upheld that carry and found two more blockers (B8, B9). A second round rebuilt #320 on #594, as the user decided on October 1: #594 is carried unchanged, with a fix for a #594 defect that aborts calls with stack arguments; RL is allocated on the 65816 only; quad spills are moved into #320; and every far fold drops dead debug locations. The packet awaits a focused third independent review. The RL DWARF numbering is escalated, and the SDK companion below is queued; nothing is posted.

**Native-word policy, September 28:** [0070 is installed locally](investigations/2026-09-28-far-word-policy.md) and enables bounded word indexing at `-O2`/`-O3`. The `-Os` Farblit gate retains its word fallback. The [working PR draft and evidence guide](pr-preparations/2026-09-28/far-word-index/README.md) now explain the policy, proof, measured tradeoffs, and limitations with diagrams. Upstream source is inspected at `26d7c2c1eebf`; the native/far prerequisites are absent there. [Three separate AI source reviews](pr-preparations/2026-09-28/far-word-index/independent-review.md) found no valid-input compiler correctness defect. The P2 weakness in 0069's opcode assertions is resolved: all 78 checks have explicit boundaries, all 156 wrong substitutions are rejected, and four focused regression files pass. The preserved checks accepted 104 of those substitutions. The [extracted candidate](pr-preparations/2026-09-28/far-word-index/upstream-series.md) now provides ordered patches on that exact base, an assertions build, expanded checks and separate frozen-IR replay evidence. Independent review of the complete compiler/ABI series and its listed contract limits remains pending. Update attribution: OpenAI Codex CLI 0.157.1 (session source: `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.

**Computed-carry scheduling (0064):** the [standalone PR packet](pr-preparations/2026-09-26/0064-pr-body.md)
is author-reviewed and validated on llvm-mos `7bd67c0ae4e8`. Compiler commit
`155e209c4cee` is [pushed to the fork branch](https://github.com/wbniv/llvm-mos/tree/mos-computed-carry-scheduling);
[PR #609](https://github.com/llvm-mos/llvm-mos/pull/609) was withdrawn at the user's request on September 27; the branch is retained. Ten focused commands, 132 MOS tests (one unsupported),
and 512 Python-oracle runtime vectors per build pass. The targeted MIR kernel
shrinks 133 → 59 bytes. The September 27 rebuilt-upstream-Clang run passes
117 C-to-object pairs across 6502, 65C02 and stock 65816, with identical
disassembly and objects excluding compiler-version metadata. The earlier
fixed-IR census repeats 39 distinct 6502 configurations; see the
[coverage correction and new evidence](pr-preparations/2026-09-26/0064-validation.md).

The [preserved-build timing](investigations/2026-09-27-mos-carry-timing.md) records sum/rotate gains of 30.45%/17.61% and a 2.80% XY16 Oz interpreter regression for that build pair. The later [LLVM-facing carry investigation](investigations/2026-09-27-competing-carry-gate.md) compares 213,866 B versus 199,309 B of aggregate savings and 39 versus six growing objects. It presents the trade-off without selecting an upstream default, and links a [follow-up with three pressure-model trials and a measured complete-object selector](investigations/2026-09-27-carry-profitability-model.md). The selector adds 220 B of aggregate savings by including `gated` among the alternatives; it does not supply a per-function or universal speed guarantee. A16 and ordinary-6502 subsets show no function growth in this census. Patch 0067 currently defaults to `always`; the local 5% threshold remains dated planning context. Bounded compile-time samples overlap. Independent review, the [generic pressure contract](defects/mos-carry-scheduling-pressure.json), and profitability remain open. The separate [XY16 `vlastack_sim` correctness defect](defects/mos-xy16-stale-x-writer-reload.json) is fixed locally in `0002`: `MOSInsertREPSEP` preserves X across narrowing, and the unchanged original input returns `0xD77B` on MAME and bsnes-jg. Upstream preparation remains part of #321.

**Separate diagnostic-only validation issue:** MOS had no null target streamer for `-filetype=null`; patch 0068 supplies it, and the retained IR now passes the diagnostic and normal-object checks on the patched downstream build. A [standalone extraction](pr-preparations/2026-09-27/0068-validation.md) is now validated on upstream `26d7c2c1eebf` (21 matching-input null-output repairs, 24 byte-identical ordinary outputs, 133 MOS passes and one unsupported). Independent review and upstream submission remain pending; the historical 0064 extraction remains unchanged. See the [investigation](investigations/2026-09-27-mos-null-output-streamer.md).
[Farblit legalization is repaired locally by 0066](investigations/2026-09-27-farblit-byte-load.md):
the original input and direct MIR pass, as do eight emulator assertions. The
preserved gate results retain their original instruction contracts. The [installed range proof in 0069](investigations/2026-09-28-farblit-range-integration.md) now uses Y8 for `cp8` in both modes, with the native `rdw` fallback retained at `-Os`; the current gate passes eight emulator assertions and 16 sensitivity tests. Publication
of this branch does not submit native-width or SNES platform code.
The submission recheck found two newer upstream commits at `26d7c2c1eebf`;
scheduler entry points and carry-class membership are unchanged. Test results
remain tied to `7bd67c0ae4e8`; no rebuild at the newer revision is claimed.

Range-proof integration update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e61c-c24c-7053-aa56-a4a4e43f12ab`.

Farblit repair, carry timing and competing-gate evaluation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`.

Current near-decoder and withdrawal update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e061-3427-74a1-90ad-c0ee84b01b85`.

Publication: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.

The [XY16 gallery / near-Y failure](defects/mos-xy16-near-indirect-y-clobber.json) is fixed locally in `0002`. Fused byte/word Y accesses preserve the index across allocation; a [separate address-wrap guard](defects/mos-near-index-bank-wrap.json) prevents negative near offsets from carrying into DBR+1. The unchanged 62-work benchmark now returns `0x5CF0`. [Causal comparison and regression evidence](investigations/2026-09-27-near-y-decoder.md) retain the baseline and fusion-only failures. Both repairs belong to the native-width feature series. [Near-index proof recovery](investigations/2026-09-27-near-index-overflow-proofs.md) is also implemented locally in `0002`, with 33,159 B of aggregate corpus savings. Its [September 29 upstream packet](pr-preparations/2026-09-29/near-index-proofs/README.md) extracts it onto `06bc967d2668` with independent review; the PR is unposted and follows the same feature-series submission gates. Extraction found an [`opt` option collision](defects/mos-near-nowrap-option-clash.json), since repaired in `0002` as well, and a [prerequisite X-preservation defect](defects/mos-xy16-preserve-x-p-save.json), now fixed in `0002` and folded into #321-4 by round seven of the split series.

**Local verification (2026-09-26):** [`[dp],Y` increment 2](plans/2026-09-25-dpy-indexed-phase2-increment2.md)
is complete on `8c19c703`; its three full-lit failures match the exact baseline,
and focused tests, runtime gates, corpus and round trips pass. It belongs in the
complete #321 native-width ABI feature series; prepare the series bundle before
opening its upstream PR.

The [live upstream dashboard](https://wald3n.com/open-source#compiler-upstream)
shows current GitHub PR state alongside a separately dated, reviewed local-work
manifest. The GitHub counts below are an October 9 live check; use the dashboard
for newer remote state and this tracker for submission evidence and history.

**Current local posting preparation:** the
[September 26 packet](pr-preparations/2026-09-26/README.md) owns the exact-current
patches, copy-ready drafts, independent reviews, and validation gates. Ten MOS
compiler packets and six LLVM packets (0037, 0041, 0056–0059) are ready locally
after exact-current isolated checks. LLVM coverage is the recorded filtered
AArch64/X86 suite, not the complete target suites. 0028's selected packet also
passes its current X86 checks; the user-presentation hold for #320/#321 remains.
0039's standalone emulator gate passes, 0044 is stacked on 0039, and 0045 uses
stock machine opcodes without #321. The separate 0060 existing-upstream MOS
reducer-guard backport is independently reviewed and ready as well. The
[feature-held ledger](pr-preparations/2026-09-26/feature-held-packages.md)
preserves real ABI/extraction and user-presentation holds. These seventeen
packets remain unposted; the separate 0064 packet is posted as
[PR #609](https://github.com/llvm-mos/llvm-mos/pull/609).

September 26 status reconciliation: OpenAI Codex CLI 0.157.1 (`codex-tui`),
model `gpt-6-astra`, `xhigh` reasoning effort. Earlier review and build credits
remain in their linked records.

**September 26 local revalidation:** the [original far-memset report](defects/mos-far-memset-wrong-bank.json)
is fixed by existing `a81874d` / 0013. Identical IR fails without its backend
routing and passes with it, including all 4096 physical WRAM bytes. This updates
stale discovery status and adds regression coverage; the compiler/ABI and far
runtime remain feature-series work, with no new independent PR claimed.

**GitHub status last verified:** 2026-10-09, live GitHub queries. **14 authored compiler PRs: 12 merged, one open (#604), one withdrawn (#609).** Both authored compiler issues (#561 and #576) remain closed in the retained September 25 evidence; they were not rechecked in this PR refresh. **SDK: #450 open, changes requested October 5.** Current PR details and the five newly recorded merges are below; earlier dated snapshots remain historical evidence.

**Prepared submissions (posting is user-triggered; review evidence is linked below):**
[0029](upstream-twoaddr-physreg-reschedule-pr.md) register exhaustion ·
[0030](upstream-copy-phys-reg-liveness-pr.md) copy liveness, then
[0031](upstream-copy-phys-reg-reuse-dst-pr.md) copy-destination reuse on top of it ·
[0011](upstream-scavenger-live-p-pr.md) scavenger live-`$p` (stock-6502 producer found 2026-09-22) ·
[0032](upstream-register-named-symbols-pr.md) register-named symbols ·
[0033](upstream-spill-hoist-scratch-vregs-pr.md) spill hoisting (generic LLVM + driver flag removal) ·
[0034](upstream-prefetch-legalize-pr.md) drop `G_PREFETCH` ·
[0037](pr-preparations/2026-09-26/0037-pr-body.md) GlobalISel indirect inline-asm outputs, the `+g` idiom (for llvm/llvm-project) ·
[0038](pr-preparations/2026-09-26/0038-pr-body.md) `llvm.returnaddress` / `llvm.frameaddress` legalized ·
[0040](pr-preparations/2026-09-26/0040-pr-body.md) `coalesceStackAccess` must not erase a
stack access carrying scratch vregs — the coalescing counterpart to 0033's hoisting guard, found as
the `ashrdi-1` greedy-RA segfault
([current validation](pr-preparations/2026-09-26/mos-validation.md)) ·
[0041](pr-preparations/2026-09-26/0041-pr-body.md) GlobalISel inline-asm register operands that
need more than one register (for llvm/llvm-project)
([current validation](pr-preparations/2026-09-26/llvm-validation.md)); no 0037 prerequisite.

**Prepared, independent review audited:** [0036](upstream-zero-page-indexed-globals-pr.md)
zero-page indexed globals. Direct and reassembled objects now agree; standalone
MOS suites pass (132 / one unsupported), and the local compiler is rebuilt and
installed. [Validation](pr-preparations/2026-09-23/0036-validation.md).

**Reviewed; current isolated and emulator checks complete:** [0039](upstream-asm-modifier-width-pr.md) — an explicit
width modifier on a constant operand (`mos16(240)`, `mos24($123456)`) no longer selects a
narrower addressing mode with the address truncated to fit, which had made
`MOSMCInstLower::wrapAbsoluteIdxBase` a no-op and made the `-S`-then-assemble path emit
`zero page,X` where direct emission emits `absolute,X`. Strictly a narrowing, measured over
12,045 probes; three new `MC/MOS` tests; MOS suites 151 pass / 2 unsupported / the 4
pre-existing failures. [Validation](pr-preparations/2026-09-24/0039-validation.md).
September 26 revalidation uses current MOS main `7bd67c0`, with assertions:
134 suite passes / one unsupported, plus a matching-input wrong-address
emulator differential. The older 151/2/4 suite result above remains dated
evidence, not the new build's count.
**Post command** (after `gh auth`, from a branch off pristine upstream carrying
the exact `docs/pr-preparations/2026-09-26/0039-llvm-mos.patch` on MOS main
`7bd67c0ae4e8bb65a3f980912bf201df22131e34`; execute only when posting is requested):

```
gh pr create --repo llvm-mos/llvm-mos \
  --title "[MOS] Honour an explicit width modifier on a constant operand" \
  --body-file docs/pr-preparations/2026-09-26/0039-pr-body.md
```

**Pending work, SNES dependencies and issue readiness:**
[chart and flowchart](upstream-pending-work.md). This view supersedes historical
queue labels when judging what can be posted next.

**September 25 local correctness follow-up:** `0050`–`0052` repair floating-vector
arithmetic, byte-index truncation, and section-offset bank relaxation; `0049`
supplies the vector prerequisites at this pin, and `0053` updates test expectations.
`0054` repairs status-save range validation. [Evidence](plans/2026-09-25-mos-correctness-queue.md).
`0055` repairs native-width narrow-count shift legalization, while `0056` and
`0057` repair the separate GlobalISel and SelectionDAG inline-asm register bounds.
These are locally validated fixes, not posted PRs. Installed Clang and LLD are
refreshed. [Shift/GlobalISel evidence](investigations/2026-09-25-shift-inlineasm-fixes.md)
and [SelectionDAG evidence and subsequent type-handling findings](investigations/2026-09-25-selectiondag-inlineasm.md)
retain the qualified upstream-baseline comparisons.
The [AArch64 unknown-type abort](investigations/2026-09-25-aarch64-inlineasm-unknown-type.md)
is fixed by `0058`: 32 diagnostic cases and 277 cross-target tests pass, with four
existing expected failures. Its full regression requires `0057`'s `callbr` recovery.
The tested AArch64 compiler is retained separately; the installed MOS-only compiler
does not include that backend.
The [vector conversion assertions](investigations/2026-09-25-selectiondag-vector-parts.md)
are fixed by `0059`: 30 crashing configurations now diagnose, supported vector
conversions remain accepted, and the suites report 278 cross-target and 173 MOS
passes. The original input requires 0057's virtual-allocation repair. MOS Clang
and LLD are rebuilt and installed with the generic change. Patches 0058 and 0059
have completed independent review. The September 26 exact-current LLVM packets
for 0056–0059 now pass matching-input red/green and their recorded filtered
AArch64/X86 suites: 168 passes / three existing XFAILs for 0056 and 0057,
169 passes / three existing XFAILs for 0058 and 0059. The latter two retain
0057 on both comparison builds for their full regression inputs. All four
are ready locally; the counts above remain dated September 25 evidence.
See the [current receipts](pr-preparations/2026-09-26/llvm-validation.md).

The [65816 exhaustive opcode roundtrip plan](plans/2026-09-25-65816-all-opcode-roundtrip.md)
is written; implementation is deferred at the user's request. It specifies
1,024 opcode/context cases, independent expected bytes, and instruction-boundary
checks. Its BRK signature-policy question is an investigation item, not a newly
validated compiler defect or a submitted contribution.

The [0015 revalidation](investigations/2026-09-25-coalescing-0015-revalidation.md) connects the
recovered coalescing witness to existing fix 0028. Its separate allocator diagnosis
is superseded for that witness. The [parallel MIR reducer crash](defects/llvm-reduce-parallel-mir-crash.json)
captured during the investigation is [fixed locally](investigations/2026-09-25-llvm-reduce-parallel-mir-fix.md)
by the original local patch 0060 with matching-input evidence. Subsequent
reconciliation found existing LLVM commit `b1ba3d515a02` (September 24), which
predates the report and already rejects MIR `-j > 1`. Current LLVM contains
that guard; current MOS does not. The September 26
[MOS backport packet](pr-preparations/2026-09-26/0060-pr-body.md) preserves
the upstream guard and adds a valid-MIR companion test. Independent review,
all nine focused RUNs, and 180 reducer suite passes / 27 unsupported establish
local posting readiness. There is no duplicate LLVM repair to submit and no
silent serial fallback. The original parallel candidate and superseded
serial-fallback proposal remain dated evidence; general parallel-MIR context
isolation is not approved.

The [0023 contract audit](investigations/2026-09-26-trunc-imag8-i1-contract.md)
disproves the independent Imag8-only rejection diagnosis: the matcher accepts
the shared register bank and inserts an Ac copy. All 72 compiler runs and 48
selection checks pass, including saved unpatched upstream. No compiler fix or
red baseline is claimed. Retain the patch and tests with the feature series;
the original far-pointer observation still lacks its failing input and compiler.

Three compiler optimizations now have separate local patches and tests:
[0061 far-global `long,X`](../patches/llvm-mos/0061-mos-far-global-long-x.patch),
[0062 native 16-bit far loads/stores](../patches/llvm-mos/0062-mos-native-far-word.patch),
and [0063 near stores shared with unit increment](../patches/llvm-mos/0063-mos-near-shared-store.patch).
They apply in that order and reproduce the tested vendor source. The MOS lit suite
reported 175 passes and two unsupported tests; far-index, far-bank, and A16-store
gates passed on MAME and bsnes-jg. Each is implemented locally and unposted.
The [pending-work chart](upstream-pending-work.md#chart--other-pending-work)
tracks its separate submission and compiler prerequisites. The September 26
review confirms that exact 0061 requires #321 index-width machinery as well as
#320. It qualifies 0063 to increment-only; decrement uses the verified native
fallback. Historical opportunity measurements are not fresh compiler savings.

The September 27 [0065 completion record](plans/2026-09-27-broader-near-store-profitability.md) extends near-store profitability beyond 0063 and is committed and pushed to downstream `main` as [4d7136cb](https://github.com/wbniv/llvm-mos-65816/commit/4d7136cb15cf85a676b624a5892e5e8ce7ae0217). All 486 reduced comparisons and the 412-input corpus have no size increases or new failures; the new runtime fixture agrees with the host on both emulator cores. Loaded destination pointers retain their measured native preference. The [September 28 review packet](pr-preparations/2026-09-28/0065/README.md) extracts native-only prerequisites on upstream `26d7c2c1eebf`, validates the 0065 series, and records its own independent review. Preparation is complete; publication is unposted and the #321 posting hold and compiler merge dependencies remain. The September 26 review above remains evidence for the original 0063 artifact.

View this tracker with `task md -- docs/upstream-contribution-status.md` and the [dependency diagram](upstream-pending-work.md#flowchart) with `task md -- docs/upstream-pending-work.md`. The viewer reads the dated GitHub snapshot in the source; rendering does not perform a remote-status check. The [document inventory](document-dependencies.md) tracks maintained summaries and data exports.

The September 26 synchronization work was credited to OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort. Viewing update (2026-09-28): OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; session `01a0e529-62c6-7fc2-a0c6-357800272c63`.

**Local preparation updated September 23:** independent reviews and audits are recorded
for 0011 and 0029–0037, including the 0033/0035 revision follow-ups. The [0033 audit](pr-preparations/2026-09-23/0033-review-audit.md)
found a rollback-statistic defect, corrected and revalidated the same day
([response](pr-preparations/2026-09-23/0033-validation.md)); its provenance
finding was a container mount alias. The [0034 audit](pr-preparations/2026-09-23/0034-review-audit.md)
finds no implementation defect. The [0035 audit](pr-preparations/2026-09-23/0035-review-audit.md)
established that wider options also break x86-64; the test now covers `long`,
`long long` and the two-argument form. Patch 0037 (indirect register outputs in
GlobalISel inline asm) has a [completed audit](pr-preparations/2026-09-23/0037-review-audit.md):
915 standalone suite passes, one unsupported. That September 23 assessment's
remaining current-LLVM gate is now complete: the September 26 standalone
generic/AArch64 packet passes all four focused RUNs and 168 filtered
AArch64/X86 tests, with three existing XFAILs. It is ready locally and unposted.
Patch 0036 is validated against the pinned upstream base, with 45 upstream and
36 local C round trips passing; [Claude's review is audited](pr-preparations/2026-09-23/0036-review-audit.md). Its numeric
controls exposed a separate `mos16(constant)` truncation defect; that parser
fix is now prepared as [0039](upstream-asm-modifier-width-pr.md). Review, corpus, and emulator coverage are specific to each
patch's record. See the [pending-work tracker](upstream-pending-work.md) for
submission steps and the remaining defects.

**September 25 local review update:** [0043](upstream-inline-asm-physreg-width-pr.md),
[0046](upstream-fixupkinds-addrasciz-row-pr.md), and
[0047](upstream-mc-addr-asciz-symbolic-crash-pr.md) have PR drafts and initial
pinned-base validation records. The [independent review](pr-preparations/2026-09-25/claude-batch-review.md)
extends 0043 to explicit register names reachable from C, adds a compile-time
fixup-table count check to 0046, and removes the unintended `addrasciz()` language
extension from 0047. The revised artifacts apply to the pin and pass their
integrated tests. That dated isolated-validation action is superseded by the
September 26 packet: all three exact revised artifacts pass their fresh isolated
checks. Earlier binary hashes apply only to earlier revisions. Branch publication
remains user-triggered and has not been performed by this preparation pass.

[0044](plans/2026-09-24-asmprinter-long-address.md), the 24-bit address printer,
now has a reviewed, validated posting packet and stock-symbol regression,
stacked on 0039. 0045's printer repair has a reviewed, validated stock-opcode
extraction; its older native-IR
test is not a necessary submission dependency. 0048's far-codegen tests remain
feature-specific. See the current packet for exact-artifact validation.
Independent compiler submissions do not wait for SNES platform merge; the
platform/runtime prerequisites remain in the [separate tracker](upstream-pending-work.md#snes--separate-platform-track).

The revised packets and standalone checks are ready. Posting commands remain
user-triggered and have not been run in this preparation pass:

```sh
gh pr create --repo llvm-mos/llvm-mos --title "[MOS] Reject inline-asm operands wider than a named data register" --body-file docs/pr-preparations/2026-09-26/0043-pr-body.md
gh pr create --repo llvm-mos/llvm-mos --title "[MOS] Complete and check the fixup information table" --body-file docs/pr-preparations/2026-09-26/0046-pr-body.md
gh pr create --repo llvm-mos/llvm-mos --title "[MOS] Preserve symbolic .mos_addr_asciz directives in text output" --body-file docs/pr-preparations/2026-09-26/0047-pr-body.md
gh pr create --repo llvm-mos/llvm-mos --title "[MOS] Print an explicit width on 24-bit address operands" --body-file docs/pr-preparations/2026-09-26/0044-pr-body.md
```

Pin-level (`LLVM_MOS_PIN`) isolated evidence for 0044 — apply-check standalone and
stacked with 0039, fail-before/pass-after on the new test, and the byte-level
confirmation that 0044 alone still mis-narrows (down to zero page, worse than the
original bug) without 0039 — is in
[docs/pr-preparations/2026-09-26/0044-validation.md](pr-preparations/2026-09-26/0044-validation.md),
a separate, older-base companion record to this packet's own exact-base 0044 receipt
in `mos-validation.md`.

## Current PR progress

| Open PR | Current head | Review / next step | Latest GitHub CI (Ubuntu / Windows / macOS) |
|---|---|---|---|
| [#604 — Correct MVN/MVP bank order and symbolic fixups](https://github.com/llvm-mos/llvm-mos/pull/604) | `bece1fc91204` | Windows AMDGPU test matcher repaired October 10; await new CI and initial maintainer review. | Pending |

| SDK / test-suite PR | Head / merge | Review / next step | GitHub CI |
|---|---|---|---|
| [#450 — Make longjmp(env, 0) return one from setjmp](https://github.com/llvm-mos/llvm-mos-sdk/pull/450) | Merged as `b2b09b72dfca` | **Merged October 10, 02:09:41 UTC.** Companion [test-suite #20](https://github.com/llvm-mos/llvm-test-suite/pull/20) merged at 02:10:09 UTC as `5f38e99463eb`; no remaining review/landing action. [Receipt](upstream-status/2026-10-10-sjlj-merges.json). | Merge verified; no new CI run claimed |
| [test-suite #20 — Restore setjmp/longjmp tests and check zero return values](https://github.com/llvm-mos/llvm-test-suite/pull/20) | Merged as `5f38e99463eb` | **Merged October 10, 02:10:09 UTC.** Review/landing complete. [Receipt](upstream-status/2026-10-10-sjlj-merges.json). | Merge verified; no new CI run claimed |

CI is the latest check rollup returned for each PR on the verification date, not a new local test run.
**Windows CI infrastructure blocker (Will, 2026-09-20):** upstream has not updated its
Actions configuration for the Node 20 → Node 24 migration. Track the Windows failures as an
upstream configuration issue. GitHub's [migration announcement](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/)
directs workflow users to update their actions to versions supporting Node 24. The diagnosis is
provided by Will; individual job logs were not re-audited in this refresh. Raw failure/cancellation
statuses remain in the table.

**#588 Ubuntu log checked 2026-09-20:** the [job](https://github.com/llvm-mos/llvm-mos/actions/runs/35023871222/job/104566560778)
was cancelled during compilation, before the test suite ran (`context canceled`, then
`The operation was canceled.` at 23:06:31 UTC). Its Node migration messages are warnings;
setup actions succeeded and compilation continued for roughly 112 minutes. The log does not
identify who or what initiated cancellation. Record this as an incomplete build, with no test
result; the Node warning alone does not establish the cancellation cause.
Local revision validation is recorded separately in the
[September 13 bundle](pr-revisions/2026-09-13/validation.md).

**#604 Windows CI checked 2026-09-25:** the failing job is
`CodeGen/AMDGPU/si-pre-allocate-wwm-regs-preserve-rci.mir` (an MSVC comma-space `CHECK` mismatch),
confirmed pre-existing and unrelated to the MVN/MVP change — the same test fails on a plain
`llvm-mos/main` run ([`34793262107`](https://github.com/llvm-mos/llvm-mos/actions/runs/34793262107),
2026-09-14) that predates #604. `TODO.md` carries the prepared reply for if a maintainer queries the
red check; posting it is user-triggered. `gh pr view 604` shows zero comments and zero reviews as of
this refresh — no review activity yet.

| Merged PR | Contribution | Merged (UTC) |
|---|---|---|
| [#562](https://github.com/llvm-mos/llvm-mos/pull/562) | TYX/TXY dead/kill flags | 2026-07-05 |
| [#563](https://github.com/llvm-mos/llvm-mos/pull/563) | Direct-page pointer calling convention; closes #561 | 2026-07-13 |
| [#579](https://github.com/llvm-mos/llvm-mos/pull/579) | Flat-output `.elf` companion documentation | 2026-08-22 |
| [#577](https://github.com/llvm-mos/llvm-mos/pull/577) | G_SCMP/G_UCMP legalization; closes #576 | 2026-08-29 |
| [#587](https://github.com/llvm-mos/llvm-mos/pull/587) | Preserve Motorola integer defaults | 2026-08-30 |
| [#591](https://github.com/llvm-mos/llvm-mos/pull/591) | Out-of-range branch fixup diagnostics | 2026-08-30 |
| [#590](https://github.com/llvm-mos/llvm-mos/pull/590) | Deterministic zero-page allocation | 2026-09-14 |
| [#578](https://github.com/llvm-mos/llvm-mos/pull/578) | [MOS] Recompute loop liveness after copy forwarding | 2026-09-25 |
| [#584](https://github.com/llvm-mos/llvm-mos/pull/584) | [MOS] Fix non-GPR immediate loads in mos-late-opt | 2026-10-05 |
| [#586](https://github.com/llvm-mos/llvm-mos/pull/586) | [MOS] Accept an optional BRK signature operand | 2026-09-29 |
| [#588](https://github.com/llvm-mos/llvm-mos/pull/588) | [MOS] Add the COP mnemonic with a mandatory signature operand | 2026-10-05 |
| [#589](https://github.com/llvm-mos/llvm-mos/pull/589) | [MOS] Mark CmpZero as a terminator | 2026-10-05 |

The #320/#321 feature series remains separate from these PRs; #321 is an issue, not an existing
native-width PR. The submission queue below records drafts and dependencies. The October 9 pin supplies these merged repairs directly; their duplicate aggregate hunks and standalone carries are retired.

## To be posted

This is the current unposted submission queue, reviewed October 10, 2026. Prepared patches still require checking applicability against the destination revision and preparing the submission branch. Posting remains user-triggered. SDK #450 and test-suite #20 are merged; compiler #604 is posted. Their status belongs in [current PR progress](#current-pr-progress).

| Destination | Prepared work | Remaining action or hold |
|---|---|---|
| llvm-mos compiler | `0011` scavenger live-P; `0029` register exhaustion; `0030` copy liveness; `0031` copy-destination reuse; `0032` register-named symbols; `0033` spill-hoisting scratch vregs; `0034` prefetch legalization; `0036` zero-page indexed globals | `0029` has a refreshed local branch and passing current-base backend/MOS checks; review its refreshed preview before posting. Prepare the other branches from the linked reviewed packets; `0031` follows `0030`. The generic portion of `0033` also needs its LLVM destination checked. |
| llvm-mos compiler | `0038` return/frame address; `0039` explicit address width; `0040` spill coalescing; `0043`–`0047` MOS constraints, printers, metadata and directives; `0050` floating vectors; `0054` scavenger status-save range; `0060` parallel MIR reducer guard | Use the [MOS submission packet](pr-preparations/2026-09-26/mos-validation.md); `0044` depends on `0039`. `0060` is a backport of an existing LLVM fix, not a new LLVM report. |
| llvm/llvm-project | `0037` indirect inline-asm outputs; `0041` multi-register inline asm; `0056` GlobalISel register bounds; `0057` SelectionDAG register bounds; `0058` AArch64 unknown inline-asm types; `0059` SelectionDAG vector parts | Use the [LLVM submission packet](pr-preparations/2026-09-26/llvm-validation.md); full regression coverage for `0058` and `0059` requires `0057`. |
| llvm-mos compiler | `0028` undef register-lane verifier repair | Reviewed packet held until the #320/#321 presentation is ready. |
| llvm-mos compiler | #320 far-address-space and #321 native-width series; dependent far/near access and Farblit policies | Await #594 coordination and complete remaining series reviewability work. Feature-dependent patches travel with their recorded prerequisites. |
| llvm-mos discussion / SDK platform | 65816 simulator discussion; SNES platform reconciliation with SDK #415 | Simulator discussion draft is prepared. SNES implementation submission waits for the compiler, ABI and runtime prerequisites; follow the [separate platform track](upstream-pending-work.md#snes--separate-platform-track). |

The [detailed readiness table](upstream-pending-work.md#research-notes-and-evidence) owns validation qualifications and prerequisites. The prepared-submission links above and the contribution queue below retain individual drafts. Reentrant-attribute semantics and unresolved compiler investigations remain future work rather than ready submissions. Merged and superseded repairs are excluded from this queue.

Tracking update: OpenAI Codex 0.162.1, model `gpt-6.1-sol`, medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`. Earlier implementation and validation credits remain in their linked records.

## Historical updates

The entries below preserve earlier publication and patch identities. Their review/open labels and standalone paths are dated evidence; use the October 9 status and aggregate-patch disposition above for current work.

**Historical update:** 2026-08-28 (**PR #577 maintainer review addressed:** rebased onto current upstream
`main` at `e1686c59f0bd`, removed the redundant `.lower()` commentary, reduced the lit-test preamble
to input provenance and test intent, and force-pushed the verified single commit `62dd8731dccb`.
The focused `llc -verify-machineinstrs | FileCheck` pipeline passes; response posted in
[the upstream thread](https://github.com/llvm-mos/llvm-mos/pull/577#issuecomment-5457537890).**
Previously 2026-08-04 (**BRK signature operand PR #586 and `llvm-mc` Motorola-default PR
#587 posted.** **#321 upstream disposition clarified: `0002` remains local.** There is no existing
#321 pull request; #321 is the upstream issue. The other open PRs (#577, #578, #579, #584, #586,
#587) are narrower independent changes and must not absorb the holistic native-width patch. A future
submission should describe the complete opt-in native-width implementation—not a "first stage"—and
rework `0002` into a reviewable commit series under one draft PR. Posting remains user-triggered;
wald3n.com remains pending until that PR has a real URL. **Implementation update:** the
#321 native-width series gained its asynchronous-boundary contract.
Round 7 #123 `nmitally` exposed that a 65816 C ISR inherited an unknown M/X state yet its prologue
assumed M8/X8. The fix is now folded into holistic patch `0002`: `MOSFrameLowering` saves full A/X/Y
under `rep #$30`, establishes M8/X8 for the generated body, restores under M16/X16, and lets `RTI`
restore stacked P. LLVM test + runtime host/default/a16/xy16 `0xDA3B` green; runnable explanation:
[https://biohack.net/snes/nmitally/](https://biohack.net/snes/nmitally/). This is **local #321-series content, not a standalone PR**; posting
notes: [PR blueprint](321-upstream-native-width-pr.md) ·
[interrupt addition](321-upstream-interrupt-width.md). Previously 2026-07-31
(**critique-improvements pass — the four then-open PRs improved and
updated in place** (plan:
[2026-07-31-upstream-pr-critique-improvements](plans/2026-07-31-upstream-pr-critique-improvements.md);
validation: a one-off MOS-only upstream build `~/llvm-mos/build-pr`, lit green per branch before
each push; none of the PRs had review activity, so 577/578 were amended in place).
[#577](https://github.com/llvm-mos/llvm-mos/pull/577) @ `62dd8731dccb` — rebased and maintainer
review addressed 2026-08-28; test strengthened
(per-function `CHECK-NOT: jsr` pins inline expansion at every width + new s32-result case).
[#578](https://github.com/llvm-mos/llvm-mos/pull/578) @ `edc9bbd23b71` — new
`coalesce-rotate-ac-no-pessimize.ll` (shift chains keep tight form, byte-identical to unguarded
output) + body v2 (scope/root-cause section: guard removes the *trigger*, downstream RA behavior
tracked separately; exact Csmith accounting incl. 142/160; drifted embedded patch dropped);
**companion RA issue DRAFTED, NOT posted** →
`upstream-coalesce-rotate-ac-ra-issue.md` (joined Wave 2; **withdrawn + deleted 2026‑09‑14**, row 16).
[#584](https://github.com/llvm-mos/llvm-mos/pull/584) @ `3ce98fed82de` — **first record here:
POSTED 2026-07-31** (mos-late-opt non-GPR LDImm crash, from the 138 LZSS investigation) + new
commit hardening the sibling `TA` handler; body re-synced to the shipped defensive guard, mirror at
[upstream-late-opt-nongpr-ldimm-pr.md](upstream-late-opt-nongpr-ldimm-pr.md).
[#579](https://github.com/llvm-mos/llvm-mos/pull/579) @ `be45bd41c300` (branch had moved
`0ae9415`→`be45bd4` when the a16-dependent test was dropped; recorded now) — body-only edit:
confusing removed-test paragraph dropped, venue-flexibility line added.)
Previously 2026-07-26 #5 (**🏁 CAMPAIGN WAVE 1 COMPLETE — all three items posted.** Item 2:
`0010` coalesce-rotate-Ac = [PR #578](https://github.com/llvm-mos/llvm-mos/pull/578)
(`wbniv:mos-coalesce-rotate-ac` @ `18244924b3d3`, red/green-proven fix + `coalesce-rotate-ac.mir`,
four live-demo links). Item 3: DWARF step-6 = [PR #579](https://github.com/llvm-mos/llvm-mos/pull/579)
(`wbniv:mos-dwarf-65816-test-docs` @ `0ae9415`, lit test + `Writer.cpp` `<output>.elf` doc comment;
body assembled from the drafted note, test-half lead added). Upstream now shows **3 OPEN PRs
(#577/#578/#579) + 1 OPEN issue (#576)** from this campaign, all on 2026-07-26. Next: Wave 2 issues
(reentrant, rc-undef-ra, sdk setjmp) — user-triggered.) Previously 2026-07-26 #4 (**🚀 CAMPAIGN WAVE 1 ITEM 1 POSTED — `0016` G_SCMP/G_UCMP is live
upstream as issue [#576](https://github.com/llvm-mos/llvm-mos/issues/576) + PR
[#577](https://github.com/llvm-mos/llvm-mos/pull/577)** (head `wbniv:mos-scmp-ucmp-legalize` @
`e54ef471d546`, fix + `scmp-ucmp.ll` lit test, body carries `Fixes #576` + the five live-demo links).
Posted 2026-07-26 after the user ran `gh auth login` (account `wbniv`, keyring) — the auth blocker is
gone for the rest of the campaign. Next up: Wave 1 item 2 (`0010` coalesce-rotate-Ac, branch to mint)
and item 3 (DWARF, postable as-is) — both user-triggered.) Previously 2026-07-26 #3 (**tip moved `8be054612` → `8b616af94` (one commit: lld/ELF
`.debug_frame` GC, PR #567 — no MOS-backend files); all five Wave-1/3 patch artifacts
(`0010`/`0011`/`0012`/`0015`/`0016`) re-verified `git apply --check` CLEAN against the new tip in a
shared-object scratch clone. The new commit touches `lld/ELF/Writer.cpp`, one of the two files on the
DWARF branch (`0ae9415`) — re-checked live: **the cherry-pick auto-merges CLEAN onto `8b616af94`**
(no conflict; DWARF PR postable as-is). All five
`0016` demo links re-verified HTTP 200. `gh` still unauthenticated on this box — posting Wave 1 item 1
is blocked on `gh auth login` only.**) Previously 2026-07-26 #2 (**SUBMISSION CAMPAIGN PLANNED — see
[`docs/plans/2026-07-26-upstream-submission-campaign.md`](plans/2026-07-26-upstream-submission-campaign.md)**,
the wave-ordered posting sequence with per-item mechanics; posting stays user-triggered and NOTHING is
posted yet. Live state re-verified via `git ls-remote` (gh unauthenticated): `llvm-mos/main` tip is
**still `8be054612`** — identical to our rebase base, so the whole stack is verified against the
*current* tip; the two merged-PR fork branches (`mos-late-opt-txy-dead-flag`, `mos-dp-arg-cc`) are
deleted post-merge (normal cleanup — the retain-until-merged condition was satisfied), leaving `main`
(stale `c798c3141`) + `mos-dwarf-65816-test-docs` (`0ae9415`). **Per-artifact `git apply --check`
against pristine `8be054612`:** `0010`/`0011`/`0012`/`0015`/`0016` ALL apply clean — the stale-base
concern from earlier today is moot for every Wave-1/Wave-3 artifact; only `0017` needs the fork's
`0002` context (rides with #321, as recorded).) Previously 2026-07-26
(**standalone patch files `0004`–`0017` are now FROZEN posting artifacts.**
The `dev/regen-patch.sh` run for the zp-alloc Imag32 fix folded the MOS-dir-only `0016`/`0017` into the
comprehensive `0002` (build stack now `0001 → 0002 → 0006`-generic-hunks; see the
[rebase plan §Update 2026-07-26](plans/2026-07-25-llvm-mos-fork-patch-stack-upstream-rebase.md)). The
standalone files still on disk — `0004`–`0007`, `0009`–`0017` — are the individually-reviewable
upstream-PR artifacts referenced by the rows below, but they are no longer regenerable from the live
tree: the 10 per-patch `dev/regen-patch-000N.sh` scripts are **retired** (loud `exit 2` + explanatory
header) because their additive baselines no longer exist. To refresh an artifact at posting time,
rebase the patch file itself against the then-current upstream base by hand. Note their recorded
"applies cleanly against pristine `c798c3141`" claims are stale — the base has moved past `8be054612`.)
Previously 2026-07-25 (**PR #562 and PR #563 both MERGED upstream** — discovered while doing a
from-scratch `dev/run.sh toolchain` build (publishing SNES demo `#102 cpu6502`), which surfaced that
`0003-late-opt-txy-dead-flag.patch` and `0008-mos-dp-arg-cc.patch` no longer `git apply` because their
fixes are already present in `llvm-mos/main`: **PR #562** ("F4" TYX/TXY dead-flag fix) merged as commit
`9142aebae`; **PR #563** (DP-arg CC fix, `Fixes #561`) merged as commit `8be054612` (which also
auto-closed **issue #561**). Both patches **retired** from `patches/llvm-mos/` (deleted) per the
"drop once merged + the vendor pin bumps" plan noted below. Fork branches `mos-late-opt-txy-dead-flag`
and `mos-dp-arg-cc` can be deleted now they're merged (standing policy: only on explicit user request —
not done here). See [rebase plan](plans/2026-07-25-llvm-mos-fork-patch-stack-upstream-rebase.md).)
Previously 2026-07-01 (**`+mos-a16`/`+mos-xy16` s64↔s16 (un)merge + odd-width `G_ANYEXT`
legalization fix — READY-TO-POST, `#321`-scoped**. SNES demo #61 (Diffie-Hellman 64-bit modular
exponentiation) caught a backend crash: 64-bit arithmetic under `+mos-a16`/`+mos-xy16` emits
`G_UNMERGE_VALUES` splitting an `s64` into 16-bit lanes (`{S16,S64}`) and, for a mask-narrowed value, a
`G_ANYEXT` from an odd `s24` — neither had a legalizer rule, so the backend aborted with `unable to
legalize instruction: … = G_UNMERGE_VALUES %N:_(s64)` / `… = G_ANYEXT %N:_(s24)`. **Default 8-bit
compiles fine — the gap is only in the 16-bit-register modes** (the #321 fork's own s16-lane legalization,
which had s32↔s16/s8 glue but not the s64↔s16 level). Fix (all `hasAccum16()`-gated) = add the s64↔s16
(un)merge glue mirroring the existing s32 handlers (`legalizeMergeS64FromWords` /
`legalizeUnmergeS64ToWords`, the 2-level `s64 ↔ 2×s32 ↔ 4×s16` rewrite) + route odd-width `G_ANYEXT`
sources through `G_ZEXT` (high bits are don't-care). Carried as fork patch
**`0017-321-a16-s64-unmerge-anyext-legalize`** (round-trip-verified against pristine `c798c3141`);
regression-gated by `dev/run.sh dhmix` (`0x69AA`, 5-way + `-verify`), the minimal repro
[`docs/investigations/repro/a16-s64-unmerge.c`](investigations/repro/a16-s64-unmerge.c), and the full
corpus (62 slices, 0 regressions). Full write-up:
[`docs/investigations/2026-06-30-a16-s64-unmerge-anyext-legalize-crash.md`](investigations/2026-06-30-a16-s64-unmerge-anyext-legalize-crash.md).
**Posting is user-triggered** (this one is `#321`-scoped, not standalone like `0016` — it only reproduces
under `+mos-a16`/`+mos-xy16`, so it rides with the #321 upstreaming). No GitHub state change yet.)
Previously 2026-06-30 (**`G_SCMP`/`G_UCMP` legalization fix — READY-TO-POST, upstream-standalone**.
SNES demo #46 (`qsortviz`, a libc-`qsort` sort visualizer) caught a general backend crash: the standard C
three-way-compare comparator idiom `return (x>y)-(x<y);` is canonicalized by clang to the generic opcode
`G_SCMP`, and `MOSLegalizerInfo` had **no rule** for `G_SCMP`/`G_UCMP`, so the backend aborted with
`unable to legalize instruction: %N:_(s16) = G_SCMP`. Fires in **default 8-bit, +mos-a16, and +mos-xy16
alike**, at **every** integer width, in **both** `-fno-lto` and the LTO-link path — i.e. any program that
`qsort`s with a spaceship comparator fails to build. **Unlike the #320/#321 far-pointer fixes below, this
is NOT gated behind AS2/accum16 — it reproduces on plain vanilla `-mcpu=mosw65816` C, so it is directly
upstream-standalone-testable** and belongs as its own ready-to-post issue+PR against `llvm-mos/llvm-mos`.
Fix = one line in `llvm/lib/Target/MOS/MOSLegalizerInfo.cpp` next to the analogous min/max lowering:
`getActionDefinitionsBuilder({G_SCMP, G_UCMP}).lower();` — routing to LLVM's existing
`LegalizerHelper::lowerThreewayCompare` (icmp+select expansion the backend already legalizes). No
generic-LLVM change. Carried as fork patch **`0016-mos-scmp-ucmp-legalize`**; regression-gated by
`dev/run.sh qsortviz` (`corpus_result==0x8EA5`, 5-way differential + `-verify`) and the minimal repro in
[`docs/plans/2026-06-30-46-snes-qsortviz.md`](plans/2026-06-30-46-snes-qsortviz.md). **Posting is
user-triggered.** Suggested: an issue with the minimal repro + a PR with the one-line fix. `gh` commands to
draft when posting:
`gh issue create -R llvm-mos/llvm-mos -t "Backend abort: unable to legalize G_SCMP/G_UCMP (three-way compare) on MOS" -b "<minimal repro + backtrace>"`
then a PR from a fork branch with the `0016` hunk. No GitHub state change yet — nothing posted.)
Previously 2026-06-26 (**far-pointer-PHI legalization fix** — a far (addrspace 2) pointer used as a loop
induction variable (`for(;n;p++) *p=…`) forms a `G_PHI` of a far (p2) pointer; the MOS legalizer made `G_PHI`
legal only for `{s1,s8,p0,p1}`, NOT the 32-bit p2, so the backend ABORTED (`unable to legalize ... G_PHI (p2)`)
on valid C. This **resolves the follow-up gap the far-memops entry below noted** (the reason `mem-far.c` is written
index-style). Fix = `MOSLegalizerInfo::legalizePhi` (`.customFor({PF})` on the `G_PHI` rule + a `legalizeCustom`
arm): custom-legalize a far-pointer phi to an **s32 phi** — ptrtoint each incoming value in its predecessor,
inttoptr the result back to p2 after the phi — the same ptrtoint/inttoptr bridge `legalizePtrAdd`/far load+store
use; the s32 phi reuses the standard `narrowScalar`→bytes path. Purely additive (other phi types untouched), no
generic-LLVM change. Carried as fork patch **`0014-321-far-ptr-phi-legalize`** + `dev/regen-patch-0014.sh`, gated
by `dev/run.sh far_loop` (`corpus_result==0xC9`, MAME `-Os`/`-O2` + bsnes-jg via `xcheck`; the compile gate IS the
crash regression-guard). A self-contained **MOS-backend correctness fix, upstream-worthy** once #320's AS2 is
blessed — folds into the Future/blocked #320/#321 body, **not** a new ready-to-post row (AS2 isn't
upstream-standalone-testable). No GitHub state change (no posting) — #561/#562/#563 still OPEN.) Previously
2026-06-26 (**far addrspace-2 memset/memcpy/memmove silent wrong-bank fix** — a far memop the
backend can't inline-expand (variable size, or constant size over `MOSLegalizerInfo`'s `SizeLimit`) fell through
`legalizeMemOp` into the generic `createMemLibcall`, which called the **near** runtime (`__memset`/`memcpy`,
16-bit `char*`) while passing the 32-bit far pointer → the bank byte was silently dropped → wrong-bank store/load,
no diagnostic. Sources are NOT just the loop-idiom recognizer: clang `EmitAggregateCopy` (any far struct copy, no
size threshold), null/const init, `__builtin_mem*`, and MemCpyOpt all converge on the same path. Fix = route far
memops at the `legalizeMemOp` chokepoint to a far-aware runtime (`__memset_far`/`__memcpy_far`/`__memmove_far`,
`platforms/snes/mem-far.c`) via two static helpers (`anyFarPointerOperand` + `createFarMemLibcall`) in
`MOSLegalizerInfo.cpp`; near pointers widen to far bank `$00`. No generic-LLVM change. Carried as fork patch
**`0013-320-far-memops`**, gated by `dev/run.sh far_memops` (`corpus_result==0x74`, MAME+bsnes-jg, `-Os`/`-O2`) +
the standing far suite (`dev/run.sh xcheck`). A self-contained **MOS-backend correctness fix, upstream-worthy**
once #320's AS2 is blessed — folds into the Future/blocked #320 body, **not** a new ready-to-post row (AS2 isn't
upstream-standalone-testable). Surfaced a related backend gap noted for follow-up: a far-pointer loop induction
variable forms an unsupported `G_PHI (p2)`; the runtime is written index-style (invariant far base) to avoid it.
Upstream state unchanged — #561/#562/#563 still OPEN.) Previously 2026-06-26 (the **far array-subscript index-width fix** now has a **dedicated committed regression
gate** — `dev/run.sh farindex`: `examples/65816/farindex.c` promoted from an open repro → passing gate, a
`const FAR uint16_t tbl[]` read across banks $C1/$C2/$C3 folds `corpus_result==0x0001D8A1` on MAME + bsnes-jg.
Strengthens the test story for that fix in the Future/blocked #320 body; still **not** a new ready-to-post row
(AS2 isn't upstream-standalone-testable). Upstream state unchanged — #561/#562/#563 still OPEN.) Previously
2026-06-25 (added the **far array-subscript index-width correctness fix** to the #320 far-pointer
body — clang `CGExpr.cpp` promoted the GEP index to the default 16-bit `IntPtrTy` for every AS, truncating a far/AS2
index ≥ 32768; fix = the base pointer's per-AS index width. In `0001`; drafted
[`docs/320-upstream-far-subscript-index-fix.md`](320-upstream-far-subscript-index-fix.md); folds into the
Future/blocked #320 item below — not a new ready-to-post row (AS2 isn't upstream, so it's not standalone-testable).
Also re-verified upstream state — #561/#562/#563 all still **OPEN**, none merged; 3 fork branches intact; the
project-`main` pointer was generalized.) Previously 2026-06-24 (added the review-guide reviewer slice — [Appendix D](65816-patch-series-review-guide.md#appendix-d--upstream-bug-fixes--status)
+ `dev/upstream-status.sh` — and re-verified #561/#562/#563 still open. 2026-06-23: first upstream contributions now live — PR #562 (F4) + issue #561 + the #561
fix PR #563; *Verified state* snapshot refreshed; project repo `wbniv/llvm-mos-65816` `main` pushed to
`e39d0ed`. Also landed on `main`: **#320 far tail calls** in `0001` (`4adda8b`) — far→far `JSL;RTL` folds
to a `TailJML`/`$5C` long jump, −1 B/site — and **32-bit `long`/`int32_t` value-verified** (`a16s32`
micro-test + a gated `--s32` builtin-fuzzer track, test/tooling only); both fold into the ABI-gated fork
bodies below, not new ready-to-post rows. **Hygiene:** the leftover `revert-540-…` fork branch (stale
revert of merged #540) was deleted by the user on explicit request → 0 leftover fork branches. Previously 2026-06-22: the **#321 stage-1 native-s16 surface** is now **measured-complete** — consolidated
host-side via `dev/measure-native-s16-surface.sh`; the drafted "stage-1 native-s16 is measured-complete" evidence
paragraph lives in the [surface consolidation plan](plans/2026-06-22-321-native-s16-surface-consolidation-and-close.md)
and is folded into the *Native 65816 16-bit codegen* Future/blocked item below — still ABI-alignment-gated, not a
new ready-to-post row. Previously 2026-06-21: the **#320 far-pointer fork-side implementation body** grew to feature-complete
— clang `far`/`long_call` attribute (F2), typed `far_fn_t` variable, `sizeof(far*)==4`, far_indir crash fix;
pushed `origin/wt/320-far-followups`. Still ABI-blessing-gated, so it stays *Future/blocked*, not a new
ready-to-post item. Previously 2026-06-20: added the #321 CC frame-ABI design note (Ready-to-post #6); DWARF
branch `wbniv:mos-dwarf-65816-test-docs` pushed `0ae9415`; GitHub open-count last verified 2026-06-17, see
*Verified state* + *Refresh* below).

A standing snapshot of every upstream-facing contribution from this fork: what is **drafted and ready to
post**, what is **future/blocked**, and what GitHub actually shows right now. All posting is **user-triggered**
(the toolchain build + review burden lives with a human); this doc is the queue, one command per row. The
reviewer-facing slice — just the **bug-fix PRs** that touch the patch stack — is
[review guide Appendix D](65816-patch-series-review-guide.md#appendix-d--upstream-bug-fixes--status)
(refreshable via [`dev/upstream-status.sh`](../dev/upstream-status.sh)).

## Submission priorities

- Review follow-up: the six open compiler PRs above have published revisions; #589 needs its outstanding
  change request cleared by a reviewer. Windows CI awaits upstream's Actions configuration update;
  #588's Ubuntu build was cancelled before tests ran and needs a completed run.
- Reentrant needs a semantics decision; undef-lane fix 0028 is independently reviewed
  and validated on current LLVM, but retains the #320/#321 user-presentation hold;
  native SDK setjmp already has a downstream fix requiring a platform home. See the
  [issue-readiness chart](upstream-pending-work.md#what-issue-means-here).
- New independent candidate: common SDK `longjmp(env, 0)` normalization, reproduced on
  the 6502 simulator; integrated SDK CTest regression now passes 20/20 with freshly built
  current-SDK libraries and simulator. Posted as [SDK PR #450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450); open for review,
  head `0f8ad11589f5`, published description/head verified. Also listed on the
  [live compiler product page](https://indri.studio/apps/llvm-mos-65816/#upstream-contributions);
  website deployment and live entry verified September 20.
- The rotate-Ac RA companion was withdrawn September 14 after #578's root cause was identified.
- `0011` now has a stock-`mos6502` `-O0` upstream producer (gcc torture `strlen-4.c`; [record](pr-preparations/2026-09-22/0011-stock-6502-reachability.md)) and an upstream-runnable test; ready to post. `0015` has been [revalidated](investigations/2026-09-25-coalescing-0015-revalidation.md): the recovered witness is repaired by existing 0028; stock MIR reproduces, while stock C reachability remains unproven.
  `0012` is retired and must not be posted.
- Design notes and the #320/#321 feature series retain their existing ABI/review prerequisites.
  Posting new items remains user-triggered; retain fork branches under the standing policy.

## Contribution queue (posted, drafted, and retired)

| # | Item | Type | What it does | Drafted at | Branch |
|---|------|------|--------------|-----------|--------|
| 1 | ✅ **MERGED 2026-07-25 (discovered)** — **F4** — `mos-late-opt` TYX/TXY dead-flag fix | **PR** | Clears dead/kill flags when rewriting `LDImm`→TYX/TXY (verifier reject on reentrant `+mos-a16`). Merged upstream as commit `9142aebae`; fork patch `0003-late-opt-txy-dead-flag.patch` **retired** (deleted) — see [rebase plan](plans/2026-07-25-llvm-mos-fork-patch-stack-upstream-rebase.md). | [`docs/321-upstream-late-opt-txy-pr.md`](321-upstream-late-opt-txy-pr.md) | [**PR #562**](https://github.com/llvm-mos/llvm-mos/pull/562) (opened 2026-06-22, **merged**) |
| 2 | **Reentrant attribute semantics** | decision + possible fix/docs | Current clang suppresses the global nonreentrant default but emits no positive marker; backend inference can re-add nonreentrant. No ordinary-C miscompile established. Agree the intended contract before selecting a fix. | [Focused report](upstream-reentrant-soft-stack-issue.md) | unposted semantics report; no validated fix; [local reproduction refreshed 2026-09-25](investigations/2026-09-25-older-defect-recheck.md) |
| 3 | **#320** — far-pointer design note | **note** | Opens the five-address-space ABI-blessing discussion (a Discord/#320 post, not a code change). **Updated 2026-06-21** with the Phase 0/3 corrections: retracts the pow2-pointer-size premise (real reason = MVT has no i24), the C1 single-datalayout finding (`0=far-default` foreclosed → a clang flag), and the packed-24 representable-but-deferred position. Posting-ready (user-triggered). | [`docs/320-upstream-far-pointer-note.md`](320-upstream-far-pointer-note.md) | n/a (note) |
| 4 | ✅ **FIXED** — **scavenger live-`$p`** — `saveScavengerRegister` can't preserve a live `$p` across an unbalanced stack range | **fix PR** | Upstream crash (was an issue-with-no-fix): a `+mos-a16`/`+mos-xy16` compare keeps N/Z live across a frame-carry spill, forcing the whole `$p` preserved across an *unbalanced* range, but `$p` has no GPR home → illegal `STImag8 $p` + undefined-`$p` `PH $p`. **Fix** = route `$p` hard-stack-neutrally through a dead index reg into `RC17` + drop the stale `assertNZDeadAt`; carried as fork patch `0011` (`a16scavnz.c` now a `0x22A6` positive gate, both emulators, asserts-clean). | [PR body](upstream-scavenger-live-p-pr.md) · patch `patches/llvm-mos/0011-mos-scavenger-live-p-save.patch` | not yet pushed (`wbniv:mos-scavenger-live-p-save` to mint) |
| 5 | ✅ **POSTED 2026-07-26** — **DWARF step 6** — 65816 DWARF lit test + `<output>.elf` doc note | **PR** | ROADMAP step 6: pins verified DWARF shapes + documents the undocumented debug-companion `.elf` | [lit](../dev/lit/DebugInfo/MOS/dwarf-65816.ll) · [note](321-upstream-dwarf-output-elf-companion.md) | [**PR #579**](https://github.com/llvm-mos/llvm-mos/pull/579) (`wbniv:mos-dwarf-65816-test-docs` @ `be45bd41c300` — a16-dependent test dropped in review prep; body cleaned 2026-07-31, venue-flex line added) |
| 6 | **#321 CC frame-ABI** — measured frame-model evaluation | **note** | Implementation-backed CC evidence: DP-window/stack-relative are feasible but NULL on real code (locals are `__rc`-resident → frames ≈unused); keep the soft static stack, by measurement | [`docs/321-upstream-cc-frame-abi-note.md`](321-upstream-cc-frame-abi-note.md) | n/a (note) |
| 7 | **#320 far-CC** — measured ABI evaluation (far ptr across a call) | **note** | Implementation-backed CC evidence: all 4 ABIs built behind `+mos-farcc-*` + measured (bytes + round-trips/frame) on MAME+bsnes-jg → **Imag32 wins decisively** (70 B/50441; smallest *and* fastest). Far ptr should pass/return whole in one 4-byte imaginary-register unit, by measurement. **Follow-up to #3** — post after the design note opens the conversation. Shipped as `0004` in-fork. | [`docs/320-upstream-far-cc-measurement-note.md`](320-upstream-far-cc-measurement-note.md) | n/a (note) |
| 8 | ✅ **MERGED 2026-07-25 (discovered)** — **DP-arg CC** — `addrspace(1)` 8-bit pointer argument in a 16-bit register | **issue + fix PR** | Upstream crash: `CCIfPtr` (MOSCallingConv.td:65) assigns *every* pointer arg to a 16-bit `RS` pair, so an 8-bit `addrspace(1)` (direct-page) pointer arg → illegal `(p1)=COPY $rs`. **Fix** = a `CCIfPtrAddrSpace<1, CCAssignToReg<[A, X, RC2..RC15]>>` rule (8-bit slot) + a `-verify` CodeGen test; spike-validated (5 shapes, corpus 7/7). Merged upstream as commit `8be054612` (auto-closed #561); fork patch `0008-mos-dp-arg-cc.patch` **retired** (deleted) — its content also lived duplicated inside `0002`, which needs the same hunk hand-resolved — see [rebase plan](plans/2026-07-25-llvm-mos-fork-patch-stack-upstream-rebase.md). | [issue body](320-upstream-dp-arg-cc-issue.md) · [PR body](320-upstream-dp-arg-cc-pr.md) | [**#561**](https://github.com/llvm-mos/llvm-mos/issues/561) (2026-06-22, **closed**) → fixed by [**PR #563**](https://github.com/llvm-mos/llvm-mos/pull/563) (`wbniv:mos-dp-arg-cc`, 2026-06-23, **merged**) |
| 9 | **coalesce-rotate-Ac** — silent miscompile: rotate value coalesced into A-only `Ac` | **issue + fix PR** | Default-8bit miscompile (no `+mos-a16`): the register coalescer merges two shift/rotate-referenced values into the A-only `Ac` class, stranding a loop-carried CRC byte in `Y` while the back-edge `ROL` reads a stale `A` (inlined CRC16 bit loop under pressure). Both `-verify-machineinstrs`/`-verify-coalescing` clean. **Fix** = `MOSRegisterInfo::shouldCoalesce` refuses the join (`NewRC==Ac` ∧ both operands rotate-referenced) + a `-run-pass=register-coalescer` lit test; carried as fork patch `0010`, validated (repro `0xE60E`→`0xF56C`, corpus 7/7, torture 30/30, csmith 54/60 0-mismatch). ✅ **POSTED 2026-07-26** (PR only — the miscompile narrative lives in the PR body); **v2 2026-07-31** (critique pass): + `coalesce-rotate-ac-no-pessimize.ll`, body scope/root-cause section, companion RA issue drafted (row 16). **mysterymath 2026‑08‑22: "papering over a bug elsewhere… we really should get to the bottom of why."** **REDIAGNOSED + REVISION PUBLISHED 2026‑09‑14** with Will's approval (the [2026‑09‑13 bundle](pr-revisions/2026-09-13/README.md)): the coalescer and greedy RA were correct; the defect is `MOSCopyOpt`'s single post-order live-in recompute after copy forwarding leaves A off the latch live-ins, so `mos-late-opt` treats A as scratch. Fix = `fullyRecomputeLiveIns` before dead-copy cleanup; the `shouldCoalesce` guard and both its tests are **removed**. Branch fast-forwarded `edc9bbd23b71` → `b4749221bf37`; title now "Recompute loop liveness after copy forwarding"; body replaced (includes the measured compile-time cost: +0.8 % instructions corpus-wide, worst +2.4 %). Pre-publish review + red/green + runtime CRC in [validation.md](pr-revisions/2026-09-13/validation.md). [Reply posted](https://github.com/llvm-mos/llvm-mos/pull/578#issuecomment-5660390141) conceding his point and giving the mechanism in one paragraph. **Fork: landed 2026‑09‑14** ([plan](plans/2026-09-14-fork-patch-followups.md)) — `0010` now carries the published `MOSCopyOpt` fix + `copy-opt-loop.mir`/`copy-opt-chain.mir` and is applied by `dev/toolchain.sh` after `0002` (the `0003`/`0022` lifecycle); the `shouldCoalesce` guard is gone from `0002`; row 16 is obsolete (below). | [PR body](upstream-coalesce-rotate-ac-pr.md) (mirror of the published `578-body.md`) · patch `patches/llvm-mos/0010-coalesce-rotate-ac.patch` | [**PR #578**](https://github.com/llvm-mos/llvm-mos/pull/578) (`wbniv:mos-coalesce-rotate-ac` @ `b4749221bf37`) |
| 10 | ⛔ **RETIRED — DO NOT POST (user decision 2026-08-05)** — **`LDCImm` set lowering** | ~~fix PR~~ | `MOSMCInstLower` accepts the canonical carry-set encoding `-1`; no current upstream producer emits `LDCImm 1`. The former downstream a16 producer was corrected by `0027` (`357fe37`) to emit canonical `-1`, leaving the proposed baseline MIR test to manufacture an otherwise unreachable state. Accepting every nonzero immediate would also weaken the existing producer invariant. Assertions red/green evidence remains useful as investigation history, but it does not justify an upstream change without a real producer. | [retired investigation/PR draft](upstream-ldcimm-set-lowering-pr.md) · historical fork patch `patches/llvm-mos/0012-mos-ldcimm-set-lowering.patch` | **never pushed or posted; removed from submission queue** |
| 11 | ⛔ **RETRACTED — MISDIAGNOSIS (do NOT post)** — "LTO + `+mos-a16` bitmask-loop early exit" | ~~issue~~ | **Disproven 2026-06-28** by a controlled rebuild experiment ([plan](plans/2026-06-28-321-verify-lto-a16-bitmask-early-exit-diagnosis.md)). The `cmp #$10` is the loop's `q->n < UPQ_MAX_JOBS` guard (`UPQ_MAX_JOBS=16=0x10`), **not** the shift counter `r`: overriding `-DUPQ_MAX_JOBS=20` moves the constant to `cmp #$14` (tracks the macro). The `jmp rts` is the correct per-vblank DMA-budget exit (≤16 jobs/frame; 28 rows over 2 frames); the real `r<28` bound `cpy #$1c` is present. No row-skip miscompile exists. The original demo stall is a *separate, unverified* question (possible 32-bit `==0` LTO miscompile or frame ordering) → would need a **fresh, correctly-characterized** issue, not this one. | [issue body (banner-retracted)](321-upstream-lto-a16-bitmask-loop-early-exit-issue.md) | n/a — not to be posted |
| 12 | **0015 coalescing guard — revalidated 2026-09-25** | **Historical workaround; route recovered witness through 0028** | A reconstructed 2×2 comparison reproduces the retained C witness only without both 0015 and 0028. Adding 0028 retains three required KILL pseudos with unchanged allocations. The original separate allocator/regmask diagnosis is superseded for this witness. Stock MIR reproduces on saved unpatched upstream; naturally generated stock C reachability remains unproven. Guard and historical evidence retained. | [Evidence and attribution](investigations/2026-09-25-coalescing-0015-revalidation.md) · [record](defects/mos-coalescing-rc-undef.json) | **Do not post the old standalone diagnosis; follow 0028's prerequisites** |
| 14 | ⚠️ **RECLASSIFIED 2026-07-26 — NOT a postable artifact; dissolves into the #321 series** — a16 s64↔s16 (un)merge + odd-width `G_ANYEXT` | ~~fix PR~~ **series content** | `+mos-a16`/`+mos-xy16` abort (default 8-bit OK): 64-bit arithmetic emits `G_UNMERGE_VALUES {S16,S64}` (split s64 into 16-bit lanes) and, for a mask-narrowed value, `G_ANYEXT {S32,S24}` — neither had a legalizer rule (the #321 fork added s32↔s16/s8 glue but not the s64 level). **Fix** = add the s64↔s16 (un)merge glue mirroring the s32 handlers (`legalizeMergeS64FromWords`/`legalizeUnmergeS64ToWords`, 2-level `s64↔2×s32↔4×s16`) + route odd-width `G_ANYEXT` through `G_ZEXT` (don't-care high bits); all `hasAccum16()`-gated. Found by SNES demo #61 (DH 64-bit modexp). Validated: repro + demo compile, **62 corpus slices 0 regressions**, 64-bit demos differential-green, `-verify` clean. Carried as fork patch `0017` (round-trip vs pristine `c798c3141`). | [investigation + repro](investigations/2026-06-30-a16-s64-unmerge-anyext-legalize-crash.md) · patch file kept as **provenance only** (content folded into `0002` 2026-07-26) | n/a — completes OUR OWN a16 legalizer glue ("the #321 fork added s32↔s16/s8 glue but not the s64 level"), so upstream must only ever see the finished feature; same class as `0009`/`0014`/the zp-alloc Imag32 fix |
| 13 | **Undefined Imag16 lane after RA — superseded diagnosis** | Route through validated fix 0028 (item 20) | Dated September 20 evidence: fork `rcundef2.c` failed at `-Os +mos-a16`, including a witness with a live store. The earlier LiveIntervals/subrange suspicion is not the current diagnosis: the retained report establishes identity-copy undef-lane loss in `VirtRegRewriter`, with stock-upstream MIR and matching-input repair evidence. Ordinary stock C reachability remains unproven. | [Focused report and history](upstream-rc-undef-ra-pure-virtual-issue.md) | No duplicate report; follow 0028's #320/#321 publication hold |
| 15 | ✅ **POSTED 2026-07-31** — **late-opt non-GPR LDImm** — `mos-late-opt` null-pointer crash on an SPC700 `LDImm` to an imaginary register | **fix PR** | Upstream hard crash from 7 lines of plain C at `-O1`+: `combineLdImm` switches its `ImmLoad*` over `{A,X,Y}` then stores through it unconditionally, but on SPC700 `MOSInstrInfo::getRegClass` widens `LDImm`'s destination to `Anyi8`, so `$rcN = LDImm imm` is legal, verifier-clean MIR → null store. **Fix** = GPR-class guard + defensive invalidation of any modified tracked GPR (`7eedb14`), + sibling `TA`-handler hardening from the 2026-07-31 critique pass (`3ce98fe`); `late-opt-spc700.mir` red/green (SIGSEGV before, lit green after). Found via the 138 LZSS-gallery far-decode investigation (32-bit imaginary register hit the same store). | [PR body mirror](upstream-late-opt-nongpr-ldimm-pr.md) · provenance: [138 plan](plans/2026-07-27-138-lzss-far-decode-mos-late-optimization-crash.md) | [**PR #584**](https://github.com/llvm-mos/llvm-mos/pull/584) (`wbniv:mos-late-opt-nongpr-ldimm` @ `3ce98fed82de`); PR body's live-byte claim corrected to the measured matrix (3 live bytes crash at O1+, 2 at `-Oz`); fork carry `patches/llvm-mos/0003-late-opt-nongpr-ldimm-dest.patch` (`0999cfa`, merged to main 2026-08-01; **re-synced 2026‑09‑14 to the published `7f4c37de6219` form** — filter folded into the existing `LDImm` condition, [plan](plans/2026-09-14-fork-patch-followups.md)) |
| 17 | ✅ **POSTED 2026-08-04** as [**PR #590**](https://github.com/llvm-mos/llvm-mos/pull/590) — **zp-alloc determinism** — `MOSZeroPageAlloc` picks zero-page winners in heap-address order | **fix PR** | Upstream **reproducible-build** defect (any target using `-mlto-zp`; no `+mos-a16` needed): `collectCandidates` accumulates benefits in a `DenseMap<GlobalVariable *, float>` and iterates it to build the candidate list, so candidates arrive in pointer-hash (heap-address) order; the later `stable_sort` on benefit leaves ties in exactly that order, and whichever tied global is visited first takes the last free zero-page byte. **Fix** = three order-preserving container swaps, no heuristic change: `GlobalBenefit` and `CalleeFreqs` `DenseMap`→`MapVector` (the latter also fixes non-associative `float +=` accumulation into `EntryFreqs`, which perturbs *near*-ties), `SCCCallees` `SmallSet`→`SmallSetVector` (`SmallSet` degrades to pointer-ordered `std::set` past its inline capacity, and `SCC::Callees` seeds the round-robin `EntryGraph` list). Repro: 8 tied 1-byte globals + `-zp-avail=4` → **6 distinct winner sets in 20 single-threaded `llc` runs**; the gallery ROM gave **2 distinct 1 MiB images in 30 links** from byte-identical LTO IR (1476/2291 symbols shifted +2 B). **VERIFIED on a rebuilt toolchain 2026-07-31:** minimal case 6 distinct winner sets → **1** (`g0 g1 g2 g3`, 20/20 — the declaration order `MapVector` predicts); gallery ROM 2 images → **1** (`a4e00f3b…`, 20/20); lit test `zp-alloc-deterministic.ll` **0 pass/20 fail → PASS**; `llvm/test/CodeGen/MOS/` 81 tests / 7 failures = exactly the pre-existing fork-divergence set, **no new failures**. ⚠️ **Rebuild gotcha:** `dev/run.sh toolchain` does **not** rebuild `build/llvm-mos/bin/llc` (not in the distribution component list) — a stale `llc` reproduced the old 6-way split and failed the new lit test after a green build; rebuild it explicitly (`cmake --build /work/build/llvm-mos --target llc`). | [PR body](upstream-zp-alloc-deterministic-pr.md) · patch `patches/llvm-mos/0021-mos-zp-alloc-deterministic.patch` (**#590 MERGED upstream `742d554bf080`** — patch stays until the vendor pin `8be0546128a5` is bumped past it; comments re-synced 2026‑09‑14 to the merged `532900273ba9` form, [plan + bump procedure](plans/2026-09-14-fork-patch-followups.md)) · provenance: the discarded throwaway `gallery-repro-bisect` worktree; durable record = the [PR body](upstream-zp-alloc-deterministic-pr.md) Reproduction/Verification | **MINTED 2026-08-04, ready to post** — `mos-zp-alloc-deterministic` @ `1c3deb021a53` local in `~/llvm-mos` (cut from tip `1f334fef`, parent verified; red/green re-proven there, determinism test stable 5/5, suite fully green: CodeGen 79 pass/0 fail + upstream-disabled getchar-regression, MC 39/39 [CORRECTED 2026-08-04: the earlier '5 pre-existing failures on pristine tip' / '39/40 lone failure' claims were exit-127 tool-missing artifacts of the minimal build-pr tool set (opt, llvm-readelf absent); with the tools built the suites are fully green — CodeGen 79 pass + getchar-regression.ll upstream-disabled (UNSUPPORTED: target), 0 failures; MC 39/39 (+ the branch's own new tests). Rule: build the tools the suite RUNs before quoting numbers; exit-127 in a lit log is an environment defect.]). Posted from `cc9f0d027813` (the harmonized amend) after two pre-publish review catches: the retracted tool-missing "suite failures" claim and the unrecorded "3 in 40" tally. **Thread 2026‑08‑18:** andymccall independently confirmed the defect and the fix on three `-mlto-zp` targets (5 distinct binaries in 12 links → 16/16 identical; a renamed input object flipped the unpatched output and not the patched one) and offered A/B logs. **Replied 2026‑09‑14** accepting the logs and flagging the queued revision ([comment](https://github.com/llvm-mos/llvm-mos/pull/590#issuecomment-5655952323)); cite the logs from the PR body when they arrive. The comment-wording revision (mysterymath's three inline asks) from the [2026‑09‑13 bundle](pr-revisions/2026-09-13/README.md) was **PUBLISHED 2026‑09‑14** with Will's approval: branch fast-forwarded `cc9f0d027813` → `5e83a0784918`, title unchanged, body replaced with the bundle's (verified byte-identical to `590-body.md` on the live PR). The other five bundle branches remain unpublished. **🎉 MERGED upstream 2026‑09‑14 00:37 UTC by mysterymath as `742d554bf080`** — the first of the six bundle PRs to land, and the fork's third merged upstream PR (#562, #563, #590). CI note: the PR's Windows leg failed on `CodeGen/AMDGPU/si-pre-allocate-wwm-regs-preserve-rci.mir` (MSVC prints template args as `,class llvm::…`, the test's CHECK expects `, …`); the same test fails on upstream `main`'s own post-merge Windows run (`742d554bf080`, plus a `lit :: time-tests.py` flake), so it is pre-existing upstream Windows breakage unrelated to MOS; macOS and Ubuntu were green. **Fork follow-up now actionable:** retire `patches/llvm-mos/0021-mos-zp-alloc-deterministic.patch` when the vendor pin advances past `742d554bf080` (tracked in the TODO fork-patch follow-ups item). |
| 18 | ✅ **READY TO POST (2026-08-02)** — **late-opt `CmpZero` lowering skipped after the first fold** | **fix PR** | `MOSLateOptimization::lowerCmpZeros` used the function's loop-carried `Changed` accumulator as its per-instruction "did this fold?" flag, so after the first fold in a block every later-processed `CmpZero` took the early `continue` and was never lowered. Nothing downstream lowers the pseudo: it is legal MIR (so `-verify-machineinstrs` is silent) and the asm printer emits **nothing** for it — the promised flag test vanishes with no diagnostic. **Reproduces on pristine upstream** (`build/upstream-llc`, 4-line MIR, no fork feature). **Fix** = per-`CmpZero` `Folded` flag; also set `Changed` on the `allDefsAreDead()` erase path (it mutated while reporting no change). Regression `late-opt-cmpzero-after-fold.mir` (survivor before / lowered after + `CHECK-NOT: CmpZero`). Suite: 83 tests, exactly the 7 pre-existing fork-divergence failures. **Measured incidence in-tree: ZERO** — 140 files × 4 configs, 17,403 blocks, max 1 `CmpZero` per block — so the fix is inert here and the finding is a latent-hazard fix for upstream, stated as such in the PR body. | [PR body](upstream-late-opt-cmpzero-lowering-pr.md) · patch `patches/llvm-mos/0022-mos-late-opt-cmpzero-lowering.patch` (**re-synced 2026‑09‑14 to the published `9aead7afaa4a` terminator form** — `isTerminator` on `CmpZero`, `terminators()` scan, `late-opt-cmpzero.mir` + `cmpzero-terminator-invalid.mir`; [plan](plans/2026-09-14-fork-patch-followups.md)) · provenance: [plan](plans/2026-08-02-lowercmpzeros-sticky-changed.md) | ✅ **POSTED 2026-08-04** as [**PR #589**](https://github.com/llvm-mos/llvm-mos/pull/589) (`wbniv:mos-late-opt-cmpzero-lowering` @ `8c8d28b0c35a`, cut from tip `1f334fef`). Publish note: the originally-minted commit (`f8cfe68b`) had landed on the cop branch after a concurrent branch switch in the shared clone — repaired by cherry-pick onto bare tip + cop-branch reset to `3ac1097` (PR #588 unaffected); red/green + late-opt suite re-proven on the repaired branch before the push. Body cites #584 + the public incidence-scan write-up. **mysterymath requested CHANGES 2026‑08‑30**: make `CmpZero` an actual terminator instead of special-casing the scan. **Revision from the [2026‑09‑13 bundle](pr-revisions/2026-09-13/README.md) PUBLISHED 2026‑09‑14** with Will's approval: branch fast-forwarded `8c8d28b0c35a` → `9aead7afaa4a` (`isTerminator = true` + `terminators()` scan, replacing the invalid positive reproducer with a negative verifier test), title changed to "[MOS] Mark CmpZero as a terminator", body replaced with the bundle's. [Reply posted](https://github.com/llvm-mos/llvm-mos/pull/589#issuecomment-5656579826) mapping the revision directly to the review's ask and disclosing the sticky-`Changed` bug found while making the change. |
| 16 | **coalesce-rotate-Ac RA companion** — greedy RA mishandles an `Ac`-pinned loop-carried live range (the *underlying* defect behind #578) | **issue** | #578's guard removes the *trigger* (the join that pins the range); the downstream behavior — RA parks the value in `Y` on the skip path and never restores `A` before the back-edge `ROL`, from verifier-clean MIR — is unfixed and in principle reachable by a shape whose two rotate uses arrive at RA already on one vreg (no COPY to keep). No standalone repro extractable (four-way pressure simultaneity, see the reduction); filed as latent-hazard documentation with analysis + candidate directions (restore-before-use contract, forbid `Ac` for loop-carried ranges, post-RA single-reg-class verifier). Referenced from #578's original body ("happy to file a companion issue"). **OBSOLETE 2026‑09‑14 — do not post.** #578's rediagnosis showed greedy RA handled the `Ac`-pinned range correctly; the stale-A read came from `MOSCopyOpt`'s liveness update, now fixed in the published #578 revision. The draft's premise is wrong; the file is retired (deleted) by the fork-patch follow-ups pass. | _(draft `upstream-coalesce-rotate-ac-ra-issue.md` **deleted 2026‑09‑14** in the [fork-patch follow-ups](plans/2026-09-14-fork-patch-followups.md); recoverable from git history before that commit)_ | **withdrawn** — premise disproved by #578's rediagnosis |
| 20 | **branch-range diagnostics (`0019`)** — out-of-range `PCRel8`/`PCRel16` branch fixups assemble silently, offset truncated | **fix PR** | `MOSAsmBackend::applyFixup` applies the PC-relative correction and writes the value without a range check — an out-of-range branch silently lands elsewhere. **Fix** = post-correction range check + source-located `... branch target out of range` errors, with `branch-range-errors.s` pinning both messages. Carried as `patches/llvm-mos/0019-mos-branch-range-diagnostic.patch` (tracked standalone stack, `e8ccda8`). ⚠ **Coordination: touches the SAME hunk as open [PR #549](https://github.com/llvm-mos/llvm-mos/pull/549)** (mlund's 65CE02 PC-correction fix, still **OPEN** as of 2026-08-04) — complementary changes; post WITH or AFTER #549, rebasing over it if it lands first. **Minted + verified 2026-08-04:** `0019` applied cleanly to tip `1f334fef02b5` (no hand-resolution); red/green proven by `git stash` + tool-complete rebuild (llvm-mc, llc, opt, llvm-readelf, llvm-objdump all rebuilt and confirmed newer than the changed source); `llvm/test/MC/MOS/` 40/40, `llvm/test/CodeGen/MOS/` 78/79 + 1 UNSUPPORTED (`getchar-regression.ll`, pre-existing), both 0 failed / exit 0. | [PR body draft](upstream-branch-range-diagnostic-pr.md) · patch `patches/llvm-mos/0019-mos-branch-range-diagnostic.patch` | ✅ **POSTED 2026-08-05** as [**PR #591**](https://github.com/llvm-mos/llvm-mos/pull/591) (`wbniv:mos-branch-range-diagnostic` @ `b47ed3ee08e2`; user-triggered companion post alongside open #549 — ours yields and rebases if #549 lands first; courtesy [companion comment on #549](https://github.com/llvm-mos/llvm-mos/pull/549#issuecomment-5188046767) posted 2026-08-05). **Hardened and pushed 2026-08-05** with a #549-class regression net: boundary-exact PCRel8/PCRel16 pairs plus a CPU × branch-kind × direction matrix, hand-derived from the datasheet; the 65CE02 16-bit rows are `XFAIL`'d against today's still-buggy correction and cite #549. MC 43 pass + 1 expected XFAIL; CodeGen 78 pass + 1 pre-existing UNSUPPORTED. GitHub's macOS/Linux/Windows checks were triggered at the new head. [Explanatory PR comment posted](https://github.com/llvm-mos/llvm-mos/pull/591#issuecomment-5189214169). **#549 merged first** (2026-08-15, `12a0ea72`) — the coordination note above resolved itself. **🎉 #591 MERGED upstream 2026-08-30** (rebased over #549 as anticipated). Fork patch `patches/llvm-mos/0019-mos-branch-range-diagnostic.patch` stays until the vendor pin (`8be0546128a5`, 2026-07-13, unmoved) is bumped past both merges. |
| 22 | **#585 watch — `G_ASHRE` ASR legalization (mlund)** — merge adjacency + validation | **watch + review support** | mlund's open [PR #585](https://github.com/llvm-mos/llvm-mos/pull/585) legalizes 1-bit arithmetic right shifts as `G_ASHRE` (native `ASR` on 65CE02; `CMP #128 + ROR` elsewhere) across `MOSLegalizerInfo`/`MOSCombine.td`/`MOSInstrGISel.td` — the heart of `0002`'s territory, so its landing forces a reconciliation in the next vendor rebase. Alignment opportunity: our a16 s16 `G_ASHR` lowering (`cmp #$8000; ror a` — the 16-bit sibling of their idiom) could be re-expressed through `G_ASHRE` post-merge, shrinking the fork delta. **Validation pass DONE 2026-08-05** ([investigation](investigations/2026-08-05-585-gashre-validation.md) · [plan](plans/2026-08-05-585-gashre-validation.md)): applies to our stack with **zero conflicts** (offsets only, max +593); corpus PASS set **identical** to baseline (42/63 both legs); lit failing set **identical** across base/#585/#585+fix (7, all pre-existing fork divergences) and the PR's `asr-65ce02.ll` + `combiner.mir` **pass**; 7 of 8 rows of mlund's byte table reproduce exactly (`int32_t>>1` understates: −10 not −8, confirmed on stock llvm-mos). **Found a real defect:** `MOSCombinerImpl::getDemandedBits` has no `G_ASHRE` arm → falls to `default:`/all-ones → `matchShiftUnusedCarryIn` can no longer elide the sign carry-in, so `lsr` becomes `cmp #128; ror` on **every non-65CE02 CPU** (size only, not a miscompile; `mos6502` −28% worse on a signed-bitfield kernel). Minimal 3-line repro + one-arm fix restores byte-identity across all 10 780 sweep pairs while keeping all 16 65CE02 wins (−529 B). **DRAFT comment reviewed and tightened 2026-08-05, NOT posted:** reduced to the actionable finding, removed speculative material, and added a chained-`G_ASHRE` MIR regression that uniquely exercises the missing analysis arm; the proposed fixed compiler rewrites both dead carry-ins to constant zero. [`upstream-585-validation-comment.md`](upstream-585-validation-comment.md). **65CE02 execution validated:** the native-`ASR` path is now confirmed by *execution*, not just codegen — bare-metal kernel on xemu's C65 target using our **own synthesised ROM** (no copyrighted ROM needed; MAME's `c65` is unusable, its `$E000` window is deliberately unmapped). Host oracle == pre-#585 == #585 == #585+fix == `0xE0E8`, with the #585 builds running **15 native `asr`** vs 0 at baseline (−100 B on that kernel). Recipe + traps: [howto-testing-65ce02-code.md](howto-testing-65ce02-code.md). **POSTED 2026-08-05** — [llvm-mos#585 (comment)](https://github.com/llvm-mos/llvm-mos/pull/585#issuecomment-5198287883). Two edits before sending: the execution paragraph now links the [kernel + xemu harness](https://github.com/wbniv/llvm-mos-65816/tree/d124a9c/dev/c65asr) instead of describing it inline, and the `int32_t>>1` byte-table correction (−10 vs the stated −8) was dropped — that finding still stands and is recorded in the investigation §4, it was simply not raised upstream. | analysis + validation in-session 2026-08-05 | **posted — done** |
| 21 | **65816 BRL follow-up — evaluated, no optimization PR proposed (2026-09-20)** | assessment | #549 and #550 merged August 15/22. W65816 only relaxes BRA to BRL; conditional branches have no long form. Replacing absolute JMP with BRL saves no bytes and adds one cycle. The proposed general gate extension and blanket ROM-size claim are withdrawn. | [Assessment](pr-preparations/2026-09-20/brl-assessment.md) | no PR on this premise |
| 23 | ✅ **REVIEW POSTED 2026-08-05** ([review](https://github.com/llvm-mos/llvm-mos/pull/575#pullrequestreview-4865539082), CHANGES_REQUESTED, summary + 2 inline suggestions) — **review of third-party PR #575** — hand-tuned softfloat has a severe subnormal bug | **PR review** | First substantive review of ANOTHER contributor's PR ([#575](https://github.com/llvm-mos/llvm-mos/pull/575), 4 hand-written 6502 FP routines). Method: per-routine independent bit-exact Python models fuzzed vs numpy (200k–500k pairs + targeted edge classes), divergences hand-traced to the assembly. **Findings: two real `addsf3.c` bugs** — (1) SEVERE: results exactly 2× too large when a subtraction lands subnormal (normalize loop shifts once too many at the exp 1→0 crossing; 31% in-class hit rate), (2) alignment sticky-bit sign flip on subtract (+1 ULP, ~63/300k); both inherited by `__subsf3`. `mulsf3`/`divsf3` clean (divsf3: 2 fragility notes). Meta: the PR's claimed 22-vector `subsf3` test is NOT in the diff; no MOS CI runs any of its claims. Verdict: don't merge as-is. **UPDATE: both bugs now have a VERIFIED FIX** (1M-pair re-fuzz 0 mismatches, original failing seeds replay clean, real clang-23 compile all opt levels +37 B, disasm hand-verified; mos-sim run NOT done — sysroot friction, honestly flagged); patch in the review draft, offered-not-posted. **Pre-flight before posting: re-check line refs vs GitHub's diff view; user picks format (combined review+fix vs review + suggested-changes).** Strategic: reviewing others' PRs is our best engagement lever for the 11-PR queue. **#575 itself was CLOSED by its author 2026-08-22, not merged** — the review's findings were never incorporated upstream; the offered-not-posted fix patch has no home unless the author reopens or someone else picks up hand-tuned softfloat. | [review draft](upstream-575-softfloat-review.md) | **POSTED** ([#575 review](https://github.com/llvm-mos/llvm-mos/pull/575#pullrequestreview-4865539082)) — **PR closed unmerged 2026-08-22** |
| 18a | ✅ **POSTED 2026-08-04** — **optional BRK signature operand** | **fix PR — fast track** | Baseline MOS accepts only bare `brk`. Standalone additive fix keeps `BRK_Implied` unchanged and adds assembler-only `BRK_Immediate`; bare `brk` remains `[00]`, while decimal `brk #66` becomes `[00 42]` under bare `llvm-mc`. The regression deliberately avoids `$` syntax so this PR is independent of item 19. COP is explicitly excluded. **Revision from the [2026‑09‑13 bundle](pr-revisions/2026-09-13/README.md) PUBLISHED 2026‑09‑14** with Will's approval: branch fast-forwarded `064d33fc43ca` → `a2f81a87b01c` (johnwbyrd's requested round-trip tests, MOS6502/W65816 object-disassembly checks; ca65 prior art cited in the reviewed body), body replaced via `gh api` (`gh pr edit` failed on an unrelated GitHub GraphQL bug fetching classic-project cards; the REST PATCH succeeded and the live body was verified byte-identical to the bundle's). Re-verified before publishing: MC/MOS suite 40/40 on a rebuilt `llvm-mc`. | [BRK-only PR body](upstream-brk-signature-operand-pr.md) · patch `patches/llvm-mos/0024-mos-brk-signature-operand.patch` (re-synced 2026‑09‑14 to the published `a2f81a87b01c` test — disassembly + round trips; [plan](plans/2026-09-14-fork-patch-followups.md)) · [split plan](plans/2026-08-04-split-brk-cop-patch-ownership.md) | [**PR #586**](https://github.com/llvm-mos/llvm-mos/pull/586) (`wbniv:mos-brk-signature-operand` @ `a2f81a87b01c`) |
| 18b | ✅ **POSTED 2026-08-04** — **COP mnemonic + signature operand** — 65816 opcode `$02` was absent | **fix PR** | W65816-only assembler support remains separate from baseline BRK ownership. The fork carries `COP_Immediate` in the a16 patch and the natural-mnemonic ROM gate passes. **Design DECIDED 2026-08-04: MANDATORY operand (the fork's `0002` shape — decoder-visible 2-byte decode, bare `cop` rejected); the combined draft's optional design is retired. Reduction spec + rationale in the draft's banner. **Reduction DONE 2026-08-04:** branch `wbniv:mos-65816-cop-mnemonic` @ `3ac109760642` (cut from upstream main, independent of #586, not pushed), COP-only body rewritten (`44d0274`, self-stripping post commands in its banner); red/green per test, MC suite 39/40 (`addr-asciz.s` pre-existing), new `cop-signature.s` carries the load-bearing `mos65el02` predicate guard + positive 2-byte disasm round-trip.** | [as-posted body](upstream-cop-brk-signature-pr.md) · [split plan](plans/2026-08-04-split-brk-cop-patch-ownership.md) | [**PR #588**](https://github.com/llvm-mos/llvm-mos/pull/588) (`wbniv:mos-65816-cop-mnemonic` @ `3ac109760642`, 2026-08-04, **open**) |
| 19 | ✅ **POSTED 2026-08-04** — **`llvm-mc` clobbers the target's Motorola-integer default** | **fix PR (tiny)** | `AsmLexer` initializes from `MCAsmInfo::shouldUseMotorolaIntegers()`, but `llvm-mc` unconditionally overwrites it from a default-false option. Fix: call `setLexMotorolaIntegers` only when the option occurred. Focused regression proves bare MOS `$ea` encodes as `0xea` while explicit false still yields the symbolic fixup. Kept independent of BRK PR #586, whose test uses decimal `#66`. Regression dates to llvm-mos PR #352 (2023-09-21), exposing an override introduced by LLVM commit `4db18d62afa8` (2021-01-26). | [PR body](upstream-llvm-mc-motorola-default-pr.md) · [plan](plans/2026-08-04-llvm-mc-motorola-default.md) · patch `patches/llvm-mos/0025-llvm-mc-preserve-motorola-default.patch` (**#587 MERGED upstream 2026-08-30**, `mergedAt` per `gh pr view 587`; patch stays until the vendor pin — currently `8be0546128a5`, 2026-07-13, unmoved — is bumped past it) | [**PR #587**](https://github.com/llvm-mos/llvm-mos/pull/587) (`wbniv:llvm-mc-preserve-motorola-default` @ `579bc0f087c1`, **merged**) |
| 20 | **Validated; publication held for #320/#321 (rechecked 2026-09-26)** — `VirtRegRewriter` drops an undef-lane definition with an identity copy | **fix PR** | A stock-MOS eight-instruction MIR fails after `greedy,virtregrewriter`: source and destination allocate to one physical pair, the identity copy is deleted, and a later read of the undef lane lacks a physical definition. Preserve the copy as a zero-code `KILL` when any source lane has no live subrange. The selected refactor keeps lane state local to `rewriteInstruction`. Dated September 21 evidence: upstream CodeGen 85 pass / one unsupported, downstream verifier gate 34/34, 24 corpus inputs with identical MIR/assembly. September 26: generic X86 packet independently reviewed; two focused RUNs and 102 filtered X86 passes / one existing XFAIL on current LLVM. | [Current packet](pr-preparations/2026-09-26/llvm-validation.md) · [dated validation](pr-preparations/2026-09-21/0028-validation.md) · [PR body](pr-preparations/2026-09-26/0028-pr-body.md) · [investigation](upstream-rc-undef-ra-pure-virtual-issue.md) | not yet pushed; the user-presentation hold is the remaining gate |
| 17 | **MVN/MVP block-move bank order** | fix PR | Current upstream encodes source,destination bytes although the hardware consumes destination,source. The fork’s `0020` now includes both constant-byte and symbolic-fixup corrections. Preparation against `742d554bf080` includes both corrections and a regression covering unequal banks, disassembly, symbolic relocations, and forward-defined constants. | [Review bundle](pr-preparations/2026-09-20/README.md) · [PR mockup](pr-preparations/2026-09-20/mvn-mvp-pr-preview.html) · [PR body](pr-preparations/2026-09-20/mvn-mvp-body.md) | local commit `ae3108c31890`; five targeted checks and 130 suite tests pass (one unsupported); posted as [#604](https://github.com/llvm-mos/llvm-mos/pull/604), awaiting review; focused fix description, simulator discussion separate |

### 1 — F4 PR (a code-change PR; #5 DWARF is the other)

Branch `wbniv/llvm-mos:mos-late-opt-txy-dead-flag` (commit `f690dc886`, branched from `c798c3141`, a clean
ancestor of upstream `main`) is pushed; the body is drafted. Also carried locally as
`patches/llvm-mos/0003-late-opt-txy-dead-flag.patch` (drop once merged + the vendor pin bumps). Open it:

```
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-late-opt-txy-dead-flag --base main \
  --title "[MOS] mos-late-opt: clear dead/kill flags when rewriting LDImm to TYX/TXY" \
  --body-file docs/321-upstream-late-opt-txy-pr.md   # strip the status/metadata preamble first
```

### 2 — P3 issue (an issue, **not** a PR)

Source-verified write-up; **no fork patch** (issue only — the safe behaviour for ordinary C is already
correct). File it:

```
gh issue create --repo llvm-mos/llvm-mos \
  --title "[MOS] Clarify whether __attribute__((reentrant)) must prevent inferred nonreentrant allocation" \
  --body-file docs/upstream-reentrant-soft-stack-issue.md
```

### 3 — #320 far-pointer design note (a post, not a PR)

Drafted and ready; the manual step is posting it to the llvm-mos Discord / issue #320
(@asiekierka / @mysterymath) to open the ABI-blessing discussion. This **unblocks** the future #320 PR below.

**Now also carries a "Code model: near vs far" section** (added 2026-06-22) — two distinct artifacts on one
topic: (a) **compiler-side framing** (llvm-mos #320): near = `small`/`JSR` is the default, far = `medium`/`large`
is per-symbol opt-in, so **no `-mcmodel` codegen mode is warranted**; (b) **SDK-side enforcement**
(llvm-mos-sdk): the SNES near-code budget (`$8000–$FFAF`, 32688 B) is a *link-time contract* — `platforms/snes`
+ `snes-far` `link.ld` carve the header/vectors into a `romhdr` region so an over-budget link fails with
`region 'rom' overflowed by N bytes` (landed in-fork, ROM byte-identical for in-budget programs;
[plan](plans/2026-06-22-snes-near-code-budget-and-code-model.md)). (a) rides this note; (b) is an
llvm-mos-sdk-side change carried in our platform.

### 4 — register-scavenger live-`$p` fix (a **PR** now — was an issue)

**FIXED 2026-06-26** (supersedes the issue-only draft). **Reachable on stock upstream (2026-09-22):**
gcc torture `strlen-4.c` at `-O0`, `mos6502`, fails the verifier on pristine `742d554bf080` (`PH $p`
undefined; `assertNZDeadAt` on an assertion build) and 0011 fixes it with no other change across the
4,170-comparison c-torture differential; see the
[reachability record](pr-preparations/2026-09-22/0011-stock-6502-reachability.md). The `0011` fix is
ready to post:

- **`0011-mos-scavenger-live-p-save.patch`** — `MOSRegisterInfo::saveScavengerRegister` assumed N/Z dead at
  every scavenge point and that a live `$p` only needs preserving across a *balanced* range; both break under
  16-bit-accumulator flag live ranges → illegal `STImag8 $p` (`$p is not a GPR`) + undefined-`$p` `PH $p`.
  Fix: route `$p` hard-stack-neutrally through a dead 8-bit index register into `RC17` for the unbalanced
  case, flag the wholly-undefined `PHP` `undef`, drop the stale `assertNZDeadAt`, widen
  `canSaveScavengerRegister(P)`. PR body: [`docs/upstream-scavenger-live-p-pr.md`](upstream-scavenger-live-p-pr.md).
  **Revised 2026-08-01 (still unposted, so the revision lands in the same patch):** the `undef`
  predicate was a *reaching-definition* scan (`hasNoReachingDef`) and therefore under-fired — the
  machine verifier tracks **forward availability** and accepts the composite use when *any*
  sub-register is available, so a `$c` that is defined above and then killed/dead-flagged leaves
  `$p` wholly undefined at the `PHP` while a reaching-def scan still sees a modifier and declines
  to flag it. `-verify-machineinstrs` tripped on exactly that shape in `examples/snes/seamdemo.c`
  (`seamvm_step`), where an a16 ADC chain defines `$c` repeatedly and dead-flags the last one. The
  predicate is now `hasNoAvailableValue`, built on `LivePhysRegs::addLiveIns` + `stepForward` +
  `available()` — the verifier's own set. `0011` now also carries the regression test
  `llvm/test/CodeGen/MOS/scavenger-p-undef.mir`, which pins **both** directions in one function
  (`PH undef $p` where nothing is available; plain `PH $p` where `$c` is), so an over-eager `undef`
  — the only direction that could miscompile — fails the test too.
- **Retired follow-up `0012` (2026-08-05; do not post):** the `LDCImm 1` failure surfaced after the
  scavenger fix, but no current upstream producer emits that form. Patch `0027` corrected the former
  downstream producer to canonical `-1`; the proposed direct MIR regression manufactured the state.
  The patch and [draft](upstream-ldcimm-set-lowering-pr.md) remain historical evidence only.

Post (user-triggered) — mint branches off pristine `c798c31416f7`, then:

```
# scavenger fix
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-scavenger-live-p-save \
  --title "[MOS] Register scavenger: preserve a live processor-status register across an unbalanced stack range" \
  --body-file <(sed '0,/-->/d; /^# \[MOS\]/d' docs/upstream-scavenger-live-p-pr.md)
```

The original issue-only draft ([`docs/321-upstream-scavenger-nz-issue.md`](321-upstream-scavenger-nz-issue.md))
is retained for history with a SUPERSEDED banner. Full internal analysis + resolution:
[`docs/investigations/65816-a16-scavenger-nz-liveness.md`](investigations/65816-a16-scavenger-nz-liveness.md) ·
[plan](plans/2026-06-26-321-scavenger-nz-live-p-save-fix.md).

### 5 — DWARF step-6 *test + docs* PR

The 65816 DWARF *content* is already correct upstream — **no codegen change** (Step-1 audit clean,
2026-06-18; re-verified 2026-06-19). Two drafted halves guard + document it, bundled as one PR:

- **test:** [`dev/lit/DebugInfo/MOS/dwarf-65816.ll`](../dev/lit/DebugInfo/MOS/dwarf-65816.ll) — pins the
  65816 DWARF shapes (`addr_size 0x04`, `DW_AT_frame_base = DW_OP_regx RS0`, a 16-bit local in an
  imaginary-register pair `DW_OP_regx RSn`, line table, `--verify` clean). Verified by its manual
  `llc | llvm-dwarfdump | FileCheck` pipeline (full `llvm-lit` needs `count`/`not`, unbuilt here). Drops
  into `llvm/test/DebugInfo/MOS/`.
- **docs:** [`docs/321-upstream-dwarf-output-elf-companion.md`](321-upstream-dwarf-output-elf-companion.md)
  — documents that `ld.lld` writes a `<output>.elf` DWARF companion beside the flat ROM for **any**
  `OUTPUT_FORMAT { FULL/TRIM }` link (undocumented today; it's the artifact a source-level debugger loads).
  Proposes a documentation-only `lld/ELF/Writer.cpp` comment + an SDK doc sentence — **no behavior change**.

The durable in-repo guard is **`dev/run.sh dwarf`** (7/7, real `--config -g` build, companion-ELF
asserted). **No fork patch carried** (the lit test is a drop-in; the doc comment is maintainer territory).
Branch `wbniv/llvm-mos:mos-dwarf-65816-test-docs` (commit `0ae9415`, branched from `c798c3141`, upstream `main`) is pushed. Post it:

```
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-dwarf-65816-test-docs --base main \
  --title "[MOS] DebugInfo/MOS: 65816 DWARF test + document the <output>.elf companion" \
  --body-file docs/321-upstream-dwarf-output-elf-companion.md   # strip the status block first
```

May also split: the lit test alone is a pure backend-test PR; the `<output>.elf` documentation is a
separate `lld`/SDK docs change. See [DWARF round-trip plan, Step 6](plans/2026-06-18-dwarf-round-trip-roadmap-step-6-drmon-tie-in.md).

### 6 — #321 CC frame-ABI design note (a post, not a PR)

Implementation-backed evidence for the #321 calling-convention discussion: we built the feasibility proof and
measured the *opportunity* for a per-frame hardware-stack ABI (TCD direct-page window / stack-relative) vs the
soft static stack. Finding: **feasible but NULL** — 0/13 realistic functions would benefit, because llvm-mos
keeps locals register-resident in `__rc` (frames ≈ unused). The note argues to keep the soft static stack *by
measurement*, and documents why the textbook commercial DP-frame doesn't transplant onto the fixed-ZP
imaginary-register model. **No code change** (the off-by-default `+mos-dp-frame`/`+mos-sr-frame` spike was not
landed — it failed the go/no-go bar). Reproducible via `dev/frameabi-census.sh` + `dev/run.sh frameabi_a0`.
Post it (issue comment and/or the Discord CC thread):

```
gh issue comment 321 --repo llvm-mos/llvm-mos --body-file docs/321-upstream-cc-frame-abi-note.md   # strip the status block first
```

Full internal record: [frame-ABI study plan §Outcome](plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md).

### 7 — #320 far-CC measurement note (a post, not a PR)

Implementation-backed evidence for how a far (addrspace 2) pointer should cross a call. We built **all four**
plausible ABIs behind off-by-default `+mos-farcc-*` features and measured them on the same realistic
round-trip (a far ptr returned from one `noinline`, passed into another, dereferenced across a bank), gated
`0xF3` on MAME + bsnes-jg: **(a) Imag32 70 B/50441 · (b) Imag16+bank 86 B/41385 · (c) A:X+Y 102 B/43572 ·
(d) soft-stack 174 B/30626**. **Imag32 wins on both axes**, so far-ptr-across-call ships **Imag32 by
default** in-fork (patch `0004`); the others are retained only as the measured spike. **Follow-up to #3** —
post after the design note opens the conversation. Reproducible via `dev/measure-far-cc.sh` +
`dev/farcc_{imag32,split,axy,stack}.sh` + `dev/probe-cycles.lua`. Post it (Discord/#320 thread):

```
gh issue comment 320 --repo llvm-mos/llvm-mos --body-file docs/320-upstream-far-cc-measurement-note.md   # strip the status block first
```

Full internal record: [far-cc study + land plan](plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md).

### 8 — DP-arg calling-convention issue (an issue, **not** a PR)

Source-verified write-up of an **upstream** crash, surfaced as the "dp→near" residual of the #320
far-pointer-value work: passing an `addrspace(1)` (8-bit direct-page) pointer as a **function argument**
crashes the backend. Root cause is `MOSCallingConv.td:65` — `CCIfPtr<CCAssignToReg<[RS1..RS7]>>` assigns
*every* pointer arg to a 16-bit `RS` pair (`CCIfPtr` = `CCIf<"ArgFlags.isPointer()">`, address-space-blind),
so an 8-bit `addrspace(1)` pointer gets a 16-bit home → illegal `%vreg:(p1) = COPY $rsN` (`Def Size = 8,
Src Size = 16`). Three faces: `-verify-machineinstrs` rejects it; an asserts build aborts at
`MOSRegisterInfo.cpp:1059` (`copyCost`, during RA); a release build SIGSEGVs in `MOSLateOptimization`.
**No fork patch** (issue only — the fix is address-space-aware CC assignment, e.g. `CCIfPtrAddrSpace<1, …>`
to an 8-bit slot; maintainer territory). Reproduces on a **pristine** build at base `mos6502` (no
`+mos-a16`/`mosw65816`); our vendor pin `c798c31` == upstream `main`. 2-line repro included. File it:

```
gh issue create --repo llvm-mos/llvm-mos \
  --title "[MOS] Calling convention passes an addrspace(1) (8-bit direct-page) pointer argument in a 16-bit register — illegal size-mismatched COPY" \
  --body-file docs/320-upstream-dp-arg-cc-issue.md   # strip the status block first
```

Full internal record: [far-value residuals plan §Part A](plans/2026-06-22-320-far-value-residuals.md).

### 9 — Native-65816 setjmp: platform integration, fix already exists

**Current assessment (2026-09-20):** [native SDK setjmp report](upstream-sdk-setjmp-issue.md).
The downstream page-1 override can accompany the SNES platform contribution; filing
an issue is optional coordination, not a substitute for integrating that fix. The
separate common-SDK zero-value bug now has a tested candidate patch and does not
wait for SNES. The original investigation and posting recipe follow.

Surfaced scoping demo #35 (the `setjmp`/`longjmp` battery member). The SDK's common
`mos-platform/common/c/setjmp.S` is a **6502** implementation: `setjmp` reads the return address from a
**hardcoded page `$0100`** (`tsx`; `lda $101,x`/`$102,x`) and saves only the **8-bit** hard stack pointer
(`txa`); `longjmp` restores it with `tax; txs`. On the **65816 in native mode** (which the SNES crt0 enters
via `XCE`) the stack pointer **S is 16-bit and not page-1-bound**, so `longjmp` restores a corrupted S and
`rts`-es to a garbage address — **`longjmp` never returns**. `setjmp` + normal return works; only the
`longjmp` restore is broken. Reproduces in **default-8-bit AND `+mos-a16`** → pre-existing upstream, **not**
the #321 fork.

**FIXED in the fork 2026-07-02** — the fix rides with our **SNES platform** (the natural upstream home, since
`common/c/setjmp.S` is compiled once as 6502 and merged into every `libc.a`, so an `#ifdef` there would never
fire for the SNES). New **`platforms/snes/setjmp.S`** (built `-mcpu=mosw65816`, added to `snes-c` ahead of the
`common-c` merge so it shadows common's 6502 `setjmp.S.obj` by archive order) reconstructs the page-1 16-bit
`S = $01xx` (`ora #$0100; tcs`) instead of the broken `txs`, and reads/writes the return address
stack-relative — **no `jmp_buf` ABI change** (the SNES stack is page-1 by crt0 contract). Verified through the
full differential: **host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg**, all
`corpus_result = 0x2007` (regression guard `corpus/setjmp_sim.c`). Plan:
[35-setjmp-longjmp-65816-fix](plans/2026-07-02-35-setjmp-longjmp-65816-fix.md).

**Upstream posture:** this belongs in llvm-mos-sdk's SNES platform. It should land **as part of the SNES
platform PR** (llvm-mos-sdk#415 reconciliation — see *Future / blocked*), since upstream has no SNES platform
target yet to compile a 65816 `setjmp.S`. Standalone, still file the bug so it's tracked:

```
gh issue create --repo llvm-mos/llvm-mos-sdk \
  --title "[65816] longjmp corrupts the stack pointer in native mode — common setjmp.S is 6502-only (8-bit page-\$0100 stack)" \
  --body-file docs/investigations/2026-06-30-setjmp-longjmp-65816-native-stack-bug.md   # trim to the repro + root cause + our fix
```

Full internal record: [setjmp/longjmp 65816 investigation](investigations/2026-06-30-setjmp-longjmp-65816-native-stack-bug.md)
(root cause) + [fix analysis report](investigations/2026-07-02-setjmp-longjmp-65816-fix-analysis.md) (design
rationale + verification, for the PR narrative).

## Unposted reports and future work

Readiness is tracked by implementation and dependencies in the
[pending-work chart](upstream-pending-work.md); unfiled issues still represent real work.
Native SDK setjmp has a fix already: [current assessment](upstream-sdk-setjmp-issue.md).

- **llvm-mos-sdk companion: far memory runtime entries — future/blocked.** The #320 series routes far memory intrinsics that are not inlined to `__memset_far`, `__memcpy_far`, `__memmove_far` (16-bit `size_t` length) and `__memset_far32`, `__memcpy_far32`, `__memmove_far32` (`uint32_t` length). Upstream `llvm-mos-sdk` main (`3f6968bbc156`, October 1) defines none of the six; they exist only in this repository's [`platforms/snes/mem-far.c`](../platforms/snes/mem-far.c). Without them a far memory intrinsic that is not inlined fails to link, loudly. The SDK PR must land with or before the #320 PR, and it is blocked on the #320 series itself (and on its #594 alignment). Nothing is drafted yet. Source: finding N11 of the [second independent review](pr-preparations/2026-09-30/far-word-rebase/independent-review-2.md).

- **Mixed-width pointer/call register exhaustion — fix prepared September 22.**
  The [issue draft](upstream-mixed-width-call-regalloc-issue.md) has a standalone C
  reproducer verified with stock upstream Clang at `742d554bf080`, targeting
  `mos6502` through object emission. `-O1/-O2/-O3/-Os/-Oz` fail without needing
  MachineVerifier; `-O0` passes. No #320/#321 feature flags or IR editing are
  required. [Patch 0029](../patches/llvm-mos/0029-llvm-twoaddr-physreg-reschedule.patch)
  prevents the two-address pass from hoisting a physical argument definition
  across virtual operands that require that register. The standalone
  [PR draft](upstream-twoaddr-physreg-reschedule-pr.md) uses a plain 6502 reproducer;
  [validation](pr-preparations/2026-09-22/0029-validation.md) records the isolated
  MOS suite, runtime checks, and 231 passing focused X86/ARM/AArch64 regressions
  with assertions enabled. The [final simulated review](pr-preparations/2026-09-22/0029-simulated-review.md#final-submission-review--september-22)
  found no actionable defect. An [independent review](pr-preparations/2026-09-22/0029-claude-review.md)
  then refined the guard (reserved class members are not counted as available)
  and ran the complete X86, ARM, AArch64 and MOS suites on the revised patch with
  assertions: no codegen failures. Those results remain scoped to September's revision. The [October 10 refresh](pr-preparations/2026-10-10/0029/README.md) uses exact upstream `0f031168a7cc`: the local standalone branch and matching-input IR/MIR red/green are complete, and 140 MOS tests pass with one unsupported. All 24 full-driver and 24 candidate-backend C checks pass; preview approval and posting remain. The [canonical record](defects/twoaddr-physreg-reschedule-exhaustion.json) migrates this existing defect. Unposted.

- **Newton post-RA expansion — fix prepared September 22.**
  [Patch 0030](../patches/llvm-mos/0030-mos-copy-phys-reg-liveness.patch) clears
  stale kill flags when `getRegWithVal` extends a physical value's live range.
  The [PR draft](upstream-copy-phys-reg-liveness-pr.md) supersedes the
  [issue draft](upstream-newton-6502-postra-issue.md).
  [Validation](pr-preparations/2026-09-22/0030-validation.md): six focused MIR
  cases pass; MOS CodeGen has 84 passes and one unsupported, and MC 46, with
  assertions enabled. The original C-derived input verifies at all six
  optimization levels with byte-identical assembly, and the
  [independent review](pr-preparations/2026-09-22/0030-claude-review.md) adds a
  c-torture differential: 20 verifier failures repaired, 4,070 assemblies
  identical. No runtime-miscompile claim is made. The
  [browser preview](pr-preparations/2026-09-22/0030-pr-preview.html) carries the
  description, patch, and both AI attributions. The
  [audit](pr-preparations/2026-09-22/0030-review-audit.md) confirms the code and
  standalone suites and corrects the corpus accounting. Claude's attribution
  now includes CLI `2.1.278`; branch preparation and publication remain; unposted.

- **Zero-page indexed globals — fix prepared September 23.**
  [Patch 0036](../patches/llvm-mos/0036-mos-zero-page-indexed-globals.patch)
  recognizes zero-page sections during indexed-opcode selection and checks the
  address operand of indexed stores. The existing whole-object contract permits
  the compact form. Standalone MOS suites pass; all 27 C-case object mismatches
  are repaired and all 18 ordinary-section controls retain identical objects.
  The local compiler is installed, with three regressions and 36 width-mode
  compilations passing. [PR draft](upstream-zero-page-indexed-globals-pr.md) ·
  [validation](pr-preparations/2026-09-23/0036-validation.md).
  [Review audit complete](pr-preparations/2026-09-23/0036-review-audit.md);
  submission preparation remains; unposted. The separate
  `mos16(constant)` parser-width defect it exposed is fixed by
  [patch 0039](upstream-asm-modifier-width-pr.md).

- **Prefetch — two fixes prepared September 23.**
  [Patch 0034](upstream-prefetch-legalize-pr.md) makes the MOS backend discard
  `G_PREFETCH`, a hint unsupported by its hardware. [Patch 0035](upstream-clang-prefetch-int16-pr.md)
  corrects generic Clang: explicit read/write and locality operands must use
  `i32` regardless of their promoted C types. This repairs ordinary literals on
  16-bit-`int` targets and wider arguments such as `1L`/`2L` on x86-64. Omitted
  arguments already use `i32`. The pair passes all 18 MOS C-torture compilations.
  Both are installed locally and unposted. Submission destinations differ:
  `llvm-mos/llvm-mos` for 0034 and `llvm/llvm-project` for 0035.
  [Validation](pr-preparations/2026-09-23/0034-0035-validation.md).
  Independent audits: [0034](pr-preparations/2026-09-23/0034-review-audit.md)
  has 130 standalone suite passes and 28 all-CPU legalization checks;
  [0035](pr-preparations/2026-09-23/0035-review-audit.md) passes 32 frontend
  cases, repairing 21 verifier failures and retaining identical IR for the
  other 11. 0035 revised accordingly: wider-argument and two-argument cases in
  the committed test, comments corrected. Both ready to post.

- **`__builtin_return_address` / `__builtin_frame_address` — fix prepared September 23.**
  [Patch 0038](../patches/llvm-mos/0038-mos-return-frame-address.patch): neither intrinsic was
  legalized on MOS (15 c-torture compilations). The frame address is the incoming soft stack
  pointer, a fixed frame object at offset 0 through the existing frame-index lowering; the return
  address is the word `JSR` pushed plus one, read from the hard stack by an in-place pseudo that the
  new `MOSLowerReturnAddress` pass expands last, with the depth from a forward dataflow over the
  CFG (`tsx ; lda $0101+d,x`, 65816 `lda 1+d,s`, SPC700 without the `+1`). Levels above 0 and
  interrupt handlers return 0. Aimed at `llvm-mos`. [PR draft](upstream-return-frame-address-pr.md) ·
  [dated validation](pr-preparations/2026-09-23/0038-validation.md).
  The September 26 [posting packet](pr-preparations/2026-09-26/README.md) now has
  independent review, five focused passes, and 134 current-main MOS suite passes.
  Ready locally; unposted. (The SPC700
  `-O2` crash seen during its validation is patch 0003's defect, open PR #584, absent from the
  isolated validation stack only; the project toolchain has the fix.)

- **GlobalISel indirect inline-asm outputs — fix prepared September 23.**
  [Patch 0037](../patches/llvm-mos/0037-llvm-gisel-inline-asm-indirect-output.patch):
  Clang lowers `asm("" : "+g"(x))` to `"=*imr,0"`; generic `InlineAsmLowering` picked the
  register alternative for the indirect output but never stored it through the pointer and
  rejected the call. The fix stores each indirect register def through its pointer after the
  `INLINEASM`, as SelectionDAG does. 10 c-torture compilations repaired, corpus otherwise
  identical; reproduces on AArch64 GlobalISel too. Aimed at `llvm/llvm-project`.
  [PR draft](upstream-gisel-inline-asm-indirect-output-pr.md) ·
  [validation](pr-preparations/2026-09-23/0037-validation.md).
  [Independent audit complete](pr-preparations/2026-09-23/0037-review-audit.md); unposted.
  The September 26 generic/AArch64 submission variant now passes exact-current
  LLVM applicability, all four focused RUNs, and 168 filtered AArch64/X86
  tests / three existing XFAILs. [Current packet](pr-preparations/2026-09-26/llvm-validation.md):
  ready locally, unposted.

- **Spill hoisting versus scratch virtual registers — fix prepared September 23.**
  [Patch 0033](../patches/llvm-mos/0033-llvm-spill-hoist-no-new-vregs.patch): greedy's
  post-allocation spill hoisting re-emits spills through the target hook, and MOS's soft-stack
  `STStk` mints a scratch `Imag16` vreg that is never assigned (`Remaining virtual register` with
  assertions; a Machine Copy Propagation segfault in release builds, 9 c-torture files at `-O2`).
  `mos-clang` has masked it with a blanket `-mllvm -disable-spill-hoist`. The fix makes
  `hoistAllSpills` refuse a group whose re-emitted spill introduces virtual registers and drops the
  driver flag. [PR draft](upstream-spill-hoist-scratch-vregs-pr.md) ·
  [validation](pr-preparations/2026-09-23/0033-validation.md).
  [Independent audit](pr-preparations/2026-09-23/0033-review-audit.md): the
  standalone guard clears all 18 original virtual-register failures; 16 finish
  and two expose the independent scavenger assertion. Its rollback-statistic
  finding is fixed and revalidated; its provenance finding was a container
  mount alias (the run used the guarded build). Ready to post.

- **Copy-destination reuse — follow-up reviewed September 22.**
  [Patch 0031](../patches/llvm-mos/0031-mos-copy-phys-reg-reuse-dst.patch),
  stacked on 0030, makes the second reuse path of `getRegWithVal` reachable (its
  clobber map was updated before the copy was inspected, so a copy's destination
  always looked clobbered). [PR draft](upstream-copy-phys-reg-reuse-dst-pr.md),
  [validation](pr-preparations/2026-09-22/0031-validation.md),
  [preview](pr-preparations/2026-09-22/0031-pr-preview.html): new MIR test, one
  upstream test's autogenerated checks regenerated, no new failures over the
  c-torture corpus. The [independent audit](pr-preparations/2026-09-22/0031-review-audit.md)
  confirms 85 CodeGen passes, one unsupported, and 46 MC passes; 374 of the
  435 changed pairs assemble, with `.text` reduced by 2,530 bytes overall
  (352 shrink, 16 equal, six grow). Six additional clobber/liveness probes pass.
  Local emulator integration records 79/79 passes separately. The PR description
  and preview use corrected upstream evidence and both AI attributions.
  Prepare the submission after 0030; unposted.

- ~~**MC-layer `cop` mnemonic (assembler gap, found by demo #140, 2026-08-04).**~~ ✅ **POSTED
  2026-08-04** as [**PR #588**](https://github.com/llvm-mos/llvm-mos/pull/588)
  (`wbniv:mos-65816-cop-mnemonic` @ `3ac10976`, cut from `1f334fef`): `cop` with a **mandatory**
  signature operand (WDC's own asymmetry vs #586's optional BRK; decoder-visible 2-byte decode —
  `$02 5a` now disassembles as `cop #$5a`, was `<unknown>` + bogus byte), `FeatureW65816`-gated
  (`$02` is `NXT` on the 65EL02, pinned by a negative RUN line). MC suite fully green — 40/40 on the PR branch. The live #588 body already carries a same-day in-body *Correction* note for the retracted "39/40 / addr-asciz pre-existing" claim (stale-`llvm-readelf` artifact; suite 40/40; "pre-existing on pristine main" was vacuously true — same missing binary both sides). A redundant correction comment posted 2026-08-05 was deleted same-day once the in-body note was found. [CORRECTED 2026-08-04: the earlier '5 pre-existing failures on pristine tip' / '39/40 lone failure' claims were exit-127 tool-missing artifacts of the minimal build-pr tool set (opt, llvm-readelf absent); with the tools built the suites are fully green — CodeGen 79 pass + getchar-regression.ll upstream-disabled (UNSUPPORTED: target), 0 failures; MC 39/39 (+ the branch's own new tests). Rule: build the tools the suite RUNs before quoting numbers; exit-127 in a lit log is an environment defect.] Body pre-flighted: source link verified 200 post-push; a16/xy16 wording de-forked
  (`cb87da8`). [As-posted body](upstream-cop-brk-signature-pr.md) ·
  [#140 plan](plans/2026-08-04-140-snes-brkcop.md).
- **#320 five-address-space model + PR.** The real far-pointer codegen PR (asiekierka's 32-bit-default /
  packed 24-bit / zero-bank / abs-16 layout). Blocked on maintainer **ABI blessing** — gated behind posting
  the #320 design note above. Not drafted as a PR yet. **The fork-side implementation body is now large and
  feature-complete (2026-06-21/22)** and would form the bulk of this PR once unblocked — now **landed on
  `main`** as `patches/llvm-mos/0001` (a16-free) + `0004` (far-ptr CC, Imag32 winner) + `0005` (the lone
  a16-context-entangled `MOSLegalizerInfo` PF-as-value hunk) + **`0006`** (AS3 packed-24: the 3-byte far-ptr
  storage form for tables, incl. the static-init relocation fix); round-trip-proven against
  `wt/320-far-followups` (also pushed `origin/wt/320-far-followups`). **All five of asiekierka's spaces are
  now measured** — AS0/1/2 ship, AS3 packed-24 built (measured win), and **AS4 zero-bank = CONFIRMED
  measured-null** (2026-06-22 de-lumped census `dev/measure-zerobank-census.sh`: bit-identical to a near
  pointer, 0 realistic bank-0-far sites; the five-space model is complete). The **packed-24 productionization
  thread is CLOSED** (2026-06-22, [close-out](plans/2026-06-22-320-packed24-residuals-close.md)): Task A
  measured + verified, Task C (`__far_packed` spelling) closed (no AS2 spelling to mirror), and Task B (byte-2
  absolute-long cost) is the near-abs bank-relaxation `0007` — its plan is literally "the realization of Task
  B". That separate optimization (`0007`, near globals → `abs` not `abs-long`, for ALL near pointers) is built
  on `wt/320-near-abs-bank-relax`, **now folded onto `main`'s patch stack** (`0001`–`0007`, 2026-06-22):
  - **far calls (b):** far→near mixed-banking via the bank-0 thunk `__call_near_from_far` (shipped to `main`).
  - **far function pointers (a):** the p2-value sub-project (Layers 1–3 + Gap A/B), the `jsl __call_indir_far`
    indirect-call mechanism, **and the clang front-end (F2):** a MOS **`far`/`long_call`** function/type
    attribute (`MOSFarCall`) — notably it reuses the MIPS `long_call`/`far` GNU spelling via a **shared
    `ParseKind="LongCall"`** (the same multi-target pattern `interrupt` uses), and a `CGExpr`/`CGExprScalar`
    rewrite to the `store @__mos_far_target` + `call @__call_indir_far` shape. Both a **direct** `far` call
    and a **stored** `far_fn_t fp = far_leaf; fp(x)` pointer work in single-file C (a `far` bit on
    `FunctionType::ExtInfo` → `ptr addrspace(2)`). **Completed in Phase B (2026-06-26, `ec4a80b`):** the
    runtime stub `__call_indir_far`/`__mos_far_target` (`platforms/snes/call-indir-far.s`) — authored on the
    retired follow-ups worktree but never landed — is now in the tracked SDK, so a far-indirect call **links +
    runs** (`far_fnptr.c`, `0xFF` both emulators; was `ld.lld: undefined symbol`). Also fixed a **pre-existing
    far-indirect-from-far-caller miscompile**: a far function calling `__call_indir_far` was mis-routed through
    `__call_near_from_far` (`IsFarNearThunk` captured the bank-0 thunk global) → stack corruption (the indir
    thunk `jml`s away, never returns to the near thunk's `pea` site); fix excludes `__call_indir_far` from
    `IsFarNearThunk` so it JSLs directly (`far_indir_tail.c`).
  - **far-pointer sizing:** `getPointerWidthV(AS2)`→32 + a `getTypeInfoImpl` arm so `sizeof(FAR*) ==
    sizeof(far_fn_t) == 4` (matches the `p2:32:8` IR width).
  - **a crash fix worth flagging upstream-adjacent:** `isFarSymbol` was treating any `.far*`-sectioned
    symbol as far (24-bit), crashing when a `.far_rodata` datum's address is taken as a *near* pointer;
    restricted to **functions** (`isa<Function>`). This is a fix to fork-only far machinery, so it rides the
    same #320 PR rather than standing alone.
  - **far tail calls — all three forms (2026-06-23..26, `0001`):** the post-RA tail-call peephole
    (`MOSLateOptimization::tailJMP`) keyed only on near `JSR`/`RTS`, so a far function's `JSL g; RTL` tail was
    never converted. Added a `TailJML` pseudo (→ `JMP_AbsoluteLong`/`$5C`, relocates `R_MOS_ADDR24`) + a far
    arm that now folds **three** provably-far callees, each matched precisely (conservative — a misclass only
    misses a win): (a) a **direct far global** (`isGlobal && .far_`, `4adda8b`); (b) the **far→near** thunk
    `__call_near_from_far` (an external symbol — matched by name, `ff3694c`); (c) the **far-indirect** thunk
    `__call_indir_far` (a bank-0 global — matched by name, Phase B `ec4a80b`). Each folds `JSL;RTL → TailJML`
    (−1 B, drops the redundant return push/pop); the `RTL` terminator proves the frame is far, so the
    dangerous near→far `JSL;RTS` shape can't match. a16-independent. Verified `dev/run.sh far_tail`/
    `far_near_call`/`far_indir_tail` (`0xCB`/`0xE0`/`0xFF`) MAME+bsnes-jg.
  - **far array-subscript miscompile fix (2026-06-25, `0001`):** clang's `EmitArraySubscriptExpr`/`EmitIdxAfterBase`
    (`CGExpr.cpp`) promoted the GEP index to the **default 16-bit `IntPtrTy`** for every address space, so a far
    (AS2, 32-bit) subscript `tbl[idx]` emitted `sext_i16(idx)*2` — truncating indices ≥ 32768 and corrupting the
    bank byte (silent miscompile; far indexed loads only worked within one 64 KiB bank). Fixed to promote to the
    **base pointer's per-AS index width** (`getIntPtrType(ctx, TargetAS)`) — generically correct (a no-op for
    single-pointer-width targets; only bites an AS *wider* than the default = far). **Now regression-guarded by a
    dedicated committed gate (2026-06-26):** `dev/run.sh farindex` — `examples/65816/farindex.c`, promoted from an
    open repro to a passing gate, reads a `const FAR uint16_t tbl[]` spanning banks $C1/$C2/$C3 at three runtime
    indices via `lda [dp]` and folds `corpus_result==0x0001D8A1`, host == +mos-a16 on MAME + bsnes-jg. Also
    exercised in production by the ~200 KiB sin-LUT-in-far-rodata work (`platforms/snes-hirom`, `dev/run.sh k_trig32lut`
    `0x87F0B404` MAME+bsnes-jg, corpus 7/7). Like the `isFarSymbol` fix, it touches fork-only far machinery (AS2 isn't
    upstream) so it rides the #320 PR — but the `CGExpr` change is itself generic. Drafted: [`docs/320-upstream-far-subscript-index-fix.md`](320-upstream-far-subscript-index-fix.md).
  Verified end-to-end on **MAME + bsnes-jg** (the whole far suite, 12 ROMs incl. `far_tail`) + corpus 7/7 + csmith 0-mismatch.
  Still ABI-blessing-gated; the `far`/`long_call` attribute spelling-sharing design is a candidate talking
  point for the #320 note when it's posted.
- **llvm-mos-sdk#415 reconciliation.** Engage @Phillip-May's existing open SNES-target PR (not marked draft as of 2026-09-20) (build on
  his `snesxc` reg lib + multi-bank linker, contribute our native-mode crt0 + dual-emulator CI on top). This
  is *engaging someone else's PR*, not opening our own. Strategy in
  [`docs/415-snes-target-reconciliation.md`](415-snes-target-reconciliation.md).
- **Native 65816 16-bit codegen (`+mos-a16` / `+mos-xy16`) + the index-width register model.** The whole #321
  native-16-bit slice is fork-only — upstream's `W65816` is **8-bit / emulation-mode** (`FeatureAccum16` /
  `FeatureIndex16` are *not* implied by `FamilyW65816`; `Ac16/Xc16/Yc16/XH/YH` and `MOSInsertREPSEP` are
  net-new in `0002`). The **M2** goal is to upstream this. A correctness prerequisite surfaced 2026-06-20: the
  16-bit **index-register model must encode the hardware invariant** that narrowing the 65816's *single shared
  index-width flag* zeroes `XH`/`YH` — so a 16-bit index value can't be live across an 8-bit-index op (else
  its high byte is silently lost; the seed 247/445 miscompile). Root cause + fix scoping:
  [`docs/investigations/65816-xy16-index16-highbyte-clobber.md`](investigations/65816-xy16-index16-highbyte-clobber.md).
  Fixed fork-side as a **structural hardware invariant** (not an `xy16` special-case); carry that model into
  the upstream contribution. Blocked on the broader native-16-bit upstreaming (large; maintainer ABI alignment).
  **Stage-1 surface measured-complete (2026-06-22):** `dev/measure-native-s16-surface.sh` consolidates the
  per-op ALU/compare/shift/load-store + chains + cross-block M-flag + A16-threading surface — all at their
  measured optimum; the sustained-16-bit kernel class is **−22 % aggregate** vs the 8-bit build (corpus 7/7),
  while 8/16-interleave stress kernels are larger (opt-in/per-op-gated by design, lessons #1/#2) — with **one**
  shared deferred core (RA-level 16-bit residency under register pressure). The drafted upstream "stage-1
  native-s16 is measured-complete" paragraph is in the
  [surface consolidation plan](plans/2026-06-22-321-native-s16-surface-consolidation-and-close.md) (posting
  rides this same ABI-gated native-16-bit contribution; user-triggered).
  **32-bit `long`/`int32_t` now value-verified (2026-06-23):** the `+mos-a16` s32 representation
  (2×s16 + 4×s8↔s32 (un)merge + `__mulsi3`/`__udivsi3`/`__umodsi3` libcalls) gained a dedicated `a16s32`
  4-way differential micro-test and a gated `--s32` track in the builtin fuzzer (lockstep C-emit/Python-oracle,
  deterministic) — strengthens the test story carried with this contribution. Test/tooling only, no codegen
  change. [plan](plans/2026-06-23-321-32bit-long-verification.md).

> *(The ROADMAP-step-6 DWARF **test + docs** item moved up to **Ready to post now #5** on 2026-06-19 —
> both halves are now drafted: the staged lit test + the `<output>.elf` doc note.)*

## Hygiene — leftover fork branch — RESOLVED (deleted 2026-06-23)

`wbniv/llvm-mos:revert-540-fix/soft-stack-spill-crash` (a leftover **revert** branch of **upstream PR #540**,
"fix(MOS): use reserved RS8 for soft stack spill scratch register", **MERGED upstream 2026-01-26**) was
**deleted by the user on 2026-06-23** (`gh api -X DELETE
repos/wbniv/llvm-mos/git/refs/heads/revert-540-fix/soft-stack-spill-crash`). It was the documented corner
case: a *revert* of an *already-merged* PR, so "retain until merged upstream" was already satisfied; no open
PR used it. No leftover fork branches remain.

**Standing policy (user, 2026-06-21) unchanged: keep fork branches around — do not auto-propose deleting
them.** This one was removed on the user's explicit request, which is the only condition under which a fork
branch is deleted.

## Historical verification (2026-06-25 through 2026-07-26)

Our first upstream contributions are now live: **2 PRs + 1 issue open** (was 0 through 2026-06-22).
**Re-verified 2026-06-25:** unchanged — #561/#562/#563 all still **OPEN** (none merged), the three fork
branches (`mos-dp-arg-cc`, `mos-late-opt-txy-dead-flag`, `mos-dwarf-65816-test-docs`) intact, all nine
drafted `*-upstream-*` artifact docs present.

```
$ gh pr list --repo llvm-mos/llvm-mos --author wbniv --state all
#563 [OPEN] [MOS] Pass addrspace(1) (8-bit direct-page) pointer arguments in an 8-bit register
#562 [OPEN] [MOS] mos-late-opt: clear dead/kill flags when rewriting LDImm to TYX/TXY

$ gh issue list --repo llvm-mos/llvm-mos --author wbniv --state all
#561 [OPEN] [MOS] Calling convention passes an addrspace(1) ... pointer argument in a 16-bit register
            (fixed by PR #563 — Fixes #561, auto-closes on merge)

$ gh api repos/wbniv/llvm-mos/branches --jq '.[].name' | grep -v '^main$'
mos-dp-arg-cc                              # PR #563 — DP-arg CC fix (pushed 2026-06-23)
mos-late-opt-txy-dead-flag                 # PR #562 — F4 dead-flag fix
mos-dwarf-65816-test-docs                  # DWARF step-6 PR — pushed, not yet opened (queue #5)
# (revert-540-fix/soft-stack-spill-crash deleted 2026-06-23 — stale revert of merged #540)

$ gh pr view 540 --repo llvm-mos/llvm-mos --json number,title,state,mergedAt
{"number":540,"title":"fix(MOS): use reserved RS8 for soft stack spill scratch register",
 "state":"MERGED","mergedAt":"2026-01-26T22:23:07Z"}
```

**Update 2026-07-25 (discovered, not re-verified live via `gh`):** #562 and #563 are merged — found by
inspecting a fresh `llvm-mos/main` clone (commits `9142aebae` and `8be054612`), not by re-running the
`gh` commands above. `dev/upstream-status.sh` should be re-run to get a live-verified snapshot and
replace this note with a proper `gh`-sourced one.

**Update 2026-07-26 (`git ls-remote` — real remote state, no auth needed; `gh` still unauthenticated
here so PR/issue metadata is still not live-queried):**

```
$ git ls-remote https://github.com/llvm-mos/llvm-mos.git refs/heads/main
8be0546128a5...  refs/heads/main          # == our rebase base; tip has NOT moved
$ git ls-remote https://github.com/wbniv/llvm-mos.git   # branches only
c798c3141...  main                        # stale; FF to 8be054612 at posting time (user-triggered)
0ae94157b...  mos-dwarf-65816-test-docs   # active queue branch (campaign Wave 1, item 3)
# mos-dp-arg-cc + mos-late-opt-txy-dead-flag: DELETED post-merge (normal cleanup)
$ git ls-remote https://github.com/llvm-mos/llvm-mos-sdk.git refs/heads/main
61e4e1ad5e85...  refs/heads/main          # setjmp-issue target repo
```

Plus per-artifact `git apply --check` vs pristine `8be054612` (clean worktree):
`0010` ✅ · `0011` ✅ · `0012` ⛔ retired · `0015` ✅ · `0016` ✅ · `0017` ❌ (needs `0002` context; rides #321).
```

> **Note — two repos, don't conflate.** The PRs/issues/branches above target **`wbniv/llvm-mos`** (the LLVM
> compiler fork → upstream `llvm-mos/llvm-mos`). Separately, the **project** repo `wbniv/llvm-mos-65816`
> (this bench + the tracked `patches/`) had its `main` pushed to `e39d0ed` on 2026-06-23 (carrying fork
> patch `0008` + the #561/#563 artifacts); `main` has since advanced with later bench work. Either way
> that is *our* history, not an upstream contribution.

## Refresh this snapshot

```
gh pr list --repo llvm-mos/llvm-mos --author wbniv --state all --limit 100 \
  --json number,title,state,mergedAt,headRefOid,reviewDecision,url
gh api repos/wbniv/llvm-mos/branches --jq '.[].name'               # pushed branches = candidate PRs
ls docs/32*upstream* docs/320-upstream*                            # drafted artifacts in the repo
```

Cross-check the drafted-artifacts list against the TODO **Upstream / Contribution** section; each `*upstream*`
doc here should map to a TODO item, and vice-versa.

October 10 standalone 0029 refresh: OpenAI Codex CLI 0.162.0; model `gpt-6.1-sol`; medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`. Earlier contributors and dated results retain their recorded credits.
