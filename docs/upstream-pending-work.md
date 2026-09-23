# Pending upstream work and dependencies

**PR status last verified 2026-09-21; patch 0028 revalidated September 21;
patch 0029 validated on MOS and the complete X86/ARM/AArch64 CodeGen suites September 22.
Patch 0030's copy-liveness fix passes the MOS CodeGen suite, local compiler
integration checks, and an independent review with a c-torture differential
September 22; its follow-up, patch 0031 (copy-destination reuse), has also passed
independent review, with 85 MOS CodeGen passes, one unsupported, and 46 MC passes.
Patch 0032's symbol-quoting fix was validated September 23: 84 CodeGen passes,
one unsupported, 48 MC passes, and all 61 recorded assembly failures repaired.
Other implementation readiness follows the dated validation records and local
drafts.** This is the actionable view of the
[contribution tracker](upstream-contribution-status.md). Status describes the work,
not whether its GitHub container is called an issue or a pull request.

Use the [saved unpatched upstream reference](upstream-reference-build.md) for new
reproduction checks; keep candidate patches in separate builds.

## What remains to post

**Feature-independent submissions prepared September 22–23:**

1. [Mixed-width pointer/call register exhaustion](upstream-mixed-width-call-regalloc-issue.md):
   [fix PR prepared](upstream-twoaddr-physreg-reschedule-pr.md), with patch 0029
   and plain-6502 IR/MIR tests. The two-address pass must preserve an available
   register for constrained virtual operands when hoisting physical definitions.
   [Validation](pr-preparations/2026-09-22/0029-validation.md): MOS CodeGen/MC
   131 pass / one unsupported; a separate assertion-enabled build passes 169 X86,
   29 ARM, and 33 AArch64 tests, plus both bundled MOS tests. No failures or skips
   in that focused run. The [coverage inventory](pr-preparations/2026-09-22/0029-cross-target-validation.md#backend-coverage-at-the-pinned-revision)
   lists the 22 remaining untested backends.
2. [Newton `-O0` post-RA verifier failure](upstream-newton-6502-postra-issue.md):
   [fix PR prepared](upstream-copy-phys-reg-liveness-pr.md), with patch 0030.
   Copy expansion reuses Y without clearing an earlier kill. The fix passes
   six focused MIR cases and 84 MOS CodeGen tests, with one unsupported;
   all 46 MOS MC tests pass in the standalone audit.
   The original input verifies at all six optimization levels, with identical
   assembly before and after the fix. The local compiler is rebuilt and installed,
   with 24 integration compilations passing.
   [Validation](pr-preparations/2026-09-22/0030-validation.md) ·
   [PR preview](pr-preparations/2026-09-22/0030-pr-preview.html).
3. [Register-named assembly symbols](upstream-register-named-symbols-pr.md):
   patch 0032 preserves quotes around symbols such as `s`, `x`, `y`, and `a`.
   It fixes both rejected assembly and a silent memory-to-accumulator opcode
   change. [Validation](pr-preparations/2026-09-23/0032-validation.md): standalone
   MOS suites pass; all 61 recorded corpus failures now assemble with unchanged
   direct objects. The compatible local patch is installed. The
   [independent review audit](pr-preparations/2026-09-23/0032-review-audit.md)
   confirms the implementation and measures 821 assembler failures repaired
   across the full set of 4,091 emitted files (79 backend failures excluded).
   Applies to current upstream; branch preparation and publication remain.
4. [Scavenger live-`$p`](upstream-scavenger-live-p-pr.md): patch 0011, held since
   June for lack of a stock producer; gcc torture `strlen-4.c` at `-O0` on
   `mos6502` is one. Upstream-runnable test added, a liveness-tracking guard
   fixed the regression the existing `scavenger.mir` exposed on assertion builds.
   [Record](pr-preparations/2026-09-22/0011-stock-6502-reachability.md).
5. [Copy-destination reuse](upstream-copy-phys-reg-reuse-dst-pr.md): patch 0031,
   on top of 0030 (second PR on its branch, or second commit). The second reuse
   path in `getRegWithVal` was dead code; `.text` −2,530 bytes over 374 changed
   corpus pairs. [Validation](pr-preparations/2026-09-22/0031-validation.md) ·
   [audit](pr-preparations/2026-09-22/0031-review-audit.md).
6. [Spill hoisting versus scratch vregs](upstream-spill-hoist-scratch-vregs-pr.md):
   patch 0033, generic `hoistAllSpills` guard plus removal of the driver's
   blanket `-disable-spill-hoist`; release-build segfault on 9 c-torture files.
   MOS, X86, ARM and AArch64 suites clean; emulator gate 79/79.
   [Validation](pr-preparations/2026-09-23/0033-validation.md).
7. [Reentrant-attribute contract](upstream-reentrant-soft-stack-issue.md):
   semantics question, now verified with the stock upstream frontend and `opt`.

## Backend failure triage (gcc c-torture, 2026-09-23)

Of 4,170 backend compilations of the 1,390 files the pinned Clang accepts
(`-O0`, `-O2`, `-Os`, IR through `llc`), 79 failed on every build. Patch 0033
repairs 18 (12 files). What remains, by class, with the assessment behind the
rank in `TODO.md`:

| Compilations | Class | Assessment |
|---:|---|---|
| 18 | `G_PREFETCH` never legalized (`__builtin_prefetch`) | a hint; dropping it is legal; tiny fix, real reach (portable code uses the builtin) |
| 10 | `asm("" : "+g"(x))`: "unable to translate instruction: call" | the `g` constraint is unsupported in GlobalISel inline-asm lowering; a common barrier idiom |
| 12 + 3 | `llvm.returnaddress` / `llvm.frameaddress` unlegalized | unsupported builtins; a feature (read the hard stack) or a clean diagnostic |
| 6 | GlobalISel `InlineAsmLowering` assertion: multi-register tied operand (`"=r"(i) : "0"(x)` on a 16-bit value in `20030222-1.c`) | shape-specific (a simple `int` case compiles); needs the exact reduction |
| 6 + 2 | `<4 x float>` / `<2 x double>` FADD/FDIV unlegalized | vector extensions; scalarization missing |
| 4 | "Stack pointer decrement too large" (frames over 32 KiB) | a hard limit reported cleanly; not a defect |

Not in the corpus but found alongside: the asm printer and object emitter
disagree on zero-page-indexed symbol operands (`[T4]` in `TODO.md`).

These are unposted contributions and do not require #320/#321. The register
exhaustion and physical-copy liveness fixes are implemented and validated. The
attribute report needs agreement on semantics before selecting a change.

Patch 0029 submission status:

- [x] Reproduce the failure with stock `mos6502` C and validate the standalone fix.
- [x] Complete the simulated review, including both liveness-analysis paths.
- [x] Run focused X86/ARM/AArch64 regressions with assertions enabled.
- [x] Review the final submission bundle; [no actionable defect found](pr-preparations/2026-09-22/0029-simulated-review.md#final-submission-review--september-22).
- [x] Independent review: guard refined for reserved class members, comment reworded,
  complete X86/ARM/AArch64/MOS suites pass on the revised patch; [record](pr-preparations/2026-09-22/0029-claude-review.md).
- [x] Current upstream applicability: llvm-mos `main` is identical to the pinned base (`gh api …/compare`).
- [ ] Check current upstream applicability and prepare the standalone branch.
- [ ] Publish the standalone fix PR.

Patch 0030 submission status:

- [x] Reproduce the C failure and isolate copy expansion's stale kill flag.
- [x] Implement the fix and test register reuse, aliases, and clobber handling.
- [x] Pass the MOS CodeGen suite and compare original-input assembly at six levels.
- [x] Rebuild and install the local compiler; pass 24 integration compilations
  and all five MIR cases.
- [x] Independent review: sixth MIR case, c-torture differential (20 repaired, 4,070 identical), upstream `main` identical to the pinned base; [record](pr-preparations/2026-09-22/0030-claude-review.md).
- [x] Audit the independent review: correct corpus accounting and confirm six
  cases plus both MOS suites with the saved 0030-only binary;
  [record](pr-preparations/2026-09-22/0030-review-audit.md).
- [x] Prepare the [browser preview](pr-preparations/2026-09-22/0030-pr-preview.html)
  with the exact patch and AI attribution, including tool version, model, and effort.
- [x] Review the 0030 code and corrected validation claims.
- [x] Claude's updated attribution records CLI `2.1.278`, model
  `claude-fable-5-1`, and `high` reasoning effort.
- [x] Current upstream applicability: llvm-mos `main` identical to the pinned base (2026-09-22); both 0030 and 0031 also apply on the newer local clone.
- [ ] Prepare the standalone branch and publish the fix PR.

**Prepared but held: patch `0028`, the `VirtRegRewriter` undef-lane fix.**
The stock-upstream reproducer, fix, regression, and
[PR description](upstream-virtregrewriter-undef-lane-identity-copy-pr.md) are prepared.
Per the September 22 user decision, defer publication until we are ready to open
the #320/#321 series. Its stock-MOS regression has no native-width dependency;
the hold concerns presenting the downstream C triggers in context. The choice
between the smaller boolean-parameter fix and the current refactor remains open:
[comparison and recommendation](plans/2026-09-21-0028-local-identity-copy-state.md#publication-hold-and-implementation-choice--2026-09-22).
The refactor now keeps lane state inside `rewriteInstruction`, without a boolean
parameter to a separate cleanup helper. [Validation](pr-preparations/2026-09-21/0028-validation.md):
upstream CodeGen 85 pass / one unsupported, downstream verifier gate 34/34,
and 24 corpus inputs with identical MIR/assembly to the prior patch.
[PR simulation](pr-preparations/2026-09-21/0028-pr-preview.html).
Provenance: the trigger occurred in downstream native-width C torture tests; stock
upstream is covered by a constructed MIR reproducer. Stock-upstream C-to-MIR
reachability has not been established. [Evidence](pr-preparations/2026-09-21/0028-validation.md#reproducer-provenance).
The [September 22 plain-6502 search](investigations/2026-09-22-0028-plain-6502-reachability.md)
found no 0028 C trigger; it did expose a separate `-O0` Newton post-RA expansion
failure with the stock upstream frontend and backend.

| Unposted contribution | Readiness and remaining work |
|---|---|
| Undef-lane identity-copy fix (`0028`) | Validated; publication held until #320/#321 are ready to open; choose implementation and revalidate the exact submission |
| #320 far-pointer series | Refresh drafted [design note](320-upstream-far-pointer-note.md) and [calling-convention evidence](320-upstream-far-cc-measurement-note.md); agree ABI, extract coherent commits, and validate |
| #321 native-width series | Extract native-only commits, document ABI/interrupt contracts, validate, and prepare one complete draft PR; [frame-ABI evidence note](321-upstream-cc-frame-abi-note.md) is drafted |
| SNES SDK contribution around #415 | Baseline checkout and [file inventory](415-snes-reconciliation-inventory.md) prepared; resolve provenance/review requirements, implement and validate the reconciled native platform and runtime |
| 65816 simulator discussion | Separate [discussion draft](pr-preparations/2026-09-20/65816-simulator-discussion-body.md) prepared; unposted |
| Reentrant attribute semantics | Report drafted; agree the intended contract before selecting a fix or documentation change |
| Register exhaustion across calls | [Fix PR prepared](upstream-twoaddr-physreg-reschedule-pr.md), patch 0029; MOS suite and complete X86/ARM/AArch64 CodeGen suites pass; final and independent reviews complete; current-upstream applicability, branch preparation, and publication remain |
| Newton `-O0` post-RA expansion | [Fix PR prepared](upstream-copy-phys-reg-liveness-pr.md), patch 0030; six focused cases and MOS CodeGen/MC pass; review audited and attribution complete; check upstream applicability, prepare branch, and publish |
| Physical-copy destination reuse | [Fix PR reviewed](pr-preparations/2026-09-22/0031-review-audit.md), patch 0031 on top of 0030; five regression cases, six extra probes, and MOS suites pass; prepare its submission after 0030 |
| Spill-hoisting scratch vregs (`0033`) | [Fix PR prepared](upstream-spill-hoist-scratch-vregs-pr.md): generic `hoistAllSpills` guard + driver flag removal; release-build crash on 9 c-torture files at `-O2`; [validation](pr-preparations/2026-09-23/0033-validation.md) | **Fix PR prepared, unposted** | Publish | No SDK dependency |
| Register-named assembly symbols (`0032`) | [Review audited](pr-preparations/2026-09-23/0032-review-audit.md); no code defect found; standalone suites pass; full-corpus assembler failures fall from 821 to zero across 4,091 emitted files; compatible local patch installed; check current upstream, prepare branch, and publish |
| Scavenger live-P (`0011`) | Producer established (gcc torture `strlen-4.c`, stock `mos6502` `-O0`); test replaced by an upstream-runnable one; validated; post |
| Call-clobbered coalescing guard (`0015`) | Revalidate diagnosis and upstream reachability; prefer a root-cause fix |
| Trunc-selection fallback (`0023`) | Establish a real upstream producer for the independent Imag8-to-i1 portion; retain fork-specific content with its feature series |

The ABI notes are discussion contributions, separate from publishing the compiler
series. The far calling-convention evidence follows the #320 design discussion.
Older notes need a current-content review before publication.

**Already posted:** six compiler PRs (#578, #584, #586, #588, #589, #604) and SDK
#450. No new merges or reviews since September 20; all seven have no merge conflicts.
#604 now has verified Ubuntu/macOS passes and a Windows failure; SDK #450 reports
no checks. #589 still carries `CHANGES_REQUESTED` despite the published revision.
See the [live-status snapshot](upstream-contribution-status.md#current-pr-progress)
for the complete CI table. Job failure causes were not re-audited September 21.

## Recommended order

1. Prepare the standalone branch for patch 0029 and publish its PR. The fix,
   full-suite validation, final review and independent review are complete, and
   upstream `main` is identical to the pinned base; it has no #320/#321 dependency.
2. Check upstream applicability, prepare the branch, and publish
   [patch 0030](pr-preparations/2026-09-22/0030-pr-preview.html), whose code and
   evidence have been reviewed. Patch 0031's
   [separate review](pr-preparations/2026-09-22/0031-review-audit.md) is complete;
   prepare its submission after 0030.
3. Prepare the #320/#321 presentation before publishing `0028`; retain both fix
   implementations for the submission decision.
4. Follow review/CI of the six posted compiler fixes and SDK #450; request re-review
   of the published #589 revision when following up with maintainers.
5. In parallel, make **SNES platform reconciliation with SDK #415** the platform
   priority. Prepare a coherent contribution including the runtime requirements of
   whichever CPU mode it enables.
6. Prepare the #320/#321 compiler feature series and investigate the remaining
   allocator/scavenger reports independently of the SDK platform's merge timing.

## SNES — separate platform track

**Upload/review next; do not wait for it to merge before posting independent fixes.**
There is already an upstream [SNES target PR #415](https://github.com/llvm-mos/llvm-mos-sdk/pull/415).
It is open, **not currently marked draft**, at `e6a5c17cab52`. Our reconciliation and
native-runtime additions are not posted. Work with that proposal instead of opening
a competing duplicate target.

| SNES deliverable | What exists | What remains | Dependency |
|---|---|---|---|
| Basic SDK SNES target | Existing #415; our downstream platform and emulator harness; isolated baseline and [file inventory](415-snes-reconciliation-inventory.md) prepared | Resolve reviewed startup, vector provenance, interrupt and config requirements; implement and validate the reconciled patch | Technically possible with existing codegen; maintainer requires proper 65816 support before merge (see below) |
| Native-mode startup and stack contract | Working downstream XCE/startup and runtime | Specify M/X, DBR/DP and hardware-stack assumptions; validate the reconciled platform | Must ship with the runtime support required by native mode |
| Native-mode setjmp/longjmp | Working page-1-specific downstream override | Integrate and test with the native platform; agree buffer/stack contract | Same platform change or a dependent PR; no reason to merge an incomplete native runtime first |
| Native 16-bit codegen integration | Downstream `+mos-a16`/`+mos-xy16` implementation | SDK opt-in configuration/examples after compiler support is accepted | Compiler #321 series; baseline SNES target need not wait |
| Far-pointer/banked-C integration | Downstream far runtime and layouts | Reconcile SDK support after address-space/calling-convention agreement | Compiler #320 series; baseline SNES target need not wait |

**Acceptance dependency:** [the #415 maintainer review](https://github.com/llvm-mos/llvm-mos-sdk/pull/415#issuecomment-3463891415)
requires proper 65816 support before merging the platform. Our earlier statement
that a baseline target need not wait described technical feasibility, not the stated
merge policy. Reconcile in parallel; agree the required compiler/ABI scope before
expecting a platform merge. Independent MC fixes remain independent.

The SDK platform and compiler backend are different repositories and review tracks.
Current #320 and #321 remain open design/feature issues, not posted PRs for our
implementation. #321 also has another contributor's accumulator-only experiment;
coordinate and cite that work when presenting our broader series.
A SNES platform can run existing 8-bit codegen. Conversely, the compiler changes
support 65816 users beyond SNES and can be submitted without an SDK SNES merge.
See [reconciliation strategy](415-snes-target-reconciliation.md) and the
[native setjmp assessment](upstream-sdk-setjmp-issue.md).

## Chart — other pending work

| Work | Fix / implementation exists? | Posting state | Next work | Must wait for SNES? |
|---|---|---|---|---|
| #578 MOSCopyOpt loop liveness | Yes; root-cause revision published | **Awaiting review/merge** | Maintainer review of revised fix | No |
| #584 non-GPR immediate loads | Yes; simplified revision published | **Awaiting review/merge** | Maintainer review | No |
| #586 BRK signature operand | Yes; requested tests published | **Awaiting review/merge** | Maintainer review | No |
| #588 COP mnemonic | Yes; reserved-range tests published | **Awaiting review/merge** | Maintainer review; completed Ubuntu CI run | No |
| #589 CmpZero terminator | Yes; requested revision published | **Awaiting re-review/merge** | Clear outstanding change request | No |
| MVN/MVP bank order (`0020`) | Complete fix validated, including symbolic relocations | **Posted: [compiler #604](https://github.com/llvm-mos/llvm-mos/pull/604)** | Maintainer review / CI follow-up | No |
| Common SDK `longjmp(env, 0)` | **Fix tested**, 20/20 simulator cases | **Posted: [SDK PR #450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450)** | Maintainer review / CI follow-up | **No; plain 6502 bug** |
| Reentrant attribute contract | Source behavior confirmed; no agreed semantic fix | **Unposted question/report** | Decide whether attribute only cancels `-fnonreentrant` or must force reentrant allocation; then fix/docs + tests | No |
| Undef register-lane verifier failure | Constructed stock-MOS MIR reproducer; generic fix and regression validated | **Held until #320/#321 are ready to open** | Choose smaller fix or refactor; revalidate exact submission before publication | No technical SDK dependency; publication timing tied to feature presentation |
| Scavenger live-P (`0011`) | Fix, draft, stock-6502 producer and upstream-runnable test | **Ready to post** | [Reachability record](pr-preparations/2026-09-22/0011-stock-6502-reachability.md) | No SDK dependency; otherwise include with native compiler feature |
| Call-clobbered coalescing guard (`0015`) | Downstream workaround/draft exists | **Not ready to post** | Revalidate diagnosis and stock-upstream reachability; prefer root-cause fix | No SDK dependency; currently triggered by fork features |
| Mixed-width pointer across call: RA exhausts registers | Patch 0029 validated, final and independent reviews complete; MOS suite and complete X86/ARM/AArch64 CodeGen suites pass | **Fix PR prepared, unposted** | Check current upstream applicability, prepare branch, and publish | No |
| Post-RA physical-copy reuse: stale Y kill | Patch 0030 validated and review audited; six focused cases and MOS CodeGen/MC pass; original assembly unchanged at six levels | **Fix PR prepared, unposted** | Check current upstream applicability, prepare branch, and publish | No |
| Physical-copy destination reuse | Patch 0031 independently reviewed against 0030 alone; MOS CodeGen 85 pass / one unsupported, MC 46 pass; net size saving with six small increases | **Fix PR prepared, unposted; depends on 0030** | Prepare submission after 0030 | No |
| #320 far-address-space series (`0001` and related content) | Substantial downstream implementation exists | **Series not posted** | Agree ABI, extract coherent compiler commits and validate standalone | No; SDK integration follows agreed compiler/runtime ABI |
| #321 native-width series (`0002` and related content) | Substantial downstream implementation exists | **Series not posted** | Extract native-only commits from mixed aggregate, document ABI/interrupt contract, validate and post one complete draft PR | No; native runtime required to execute examples |
| `0023` trunc-selection fallback | Downstream patch exists; includes fork-specific content | **Unassessed standalone candidate** | Prove a real upstream producer for the Imag8→i1 half; keep Imag32/a16 half with its feature | No; not ready for a standalone PR |

**Already merged upstream:** #562, #563, #577, #579, #587, #590 and #591.
These need no new PR. Downstream housekeeping is separate: audit the vendor revision
and retire each carried patch only once that revision contains its fix.

**Removed from the active queue:** BRL gate extension (no demonstrated 65816 size
win; BRL costs more cycles than the absolute JMP it replaces), `0012` LDCImm
(noncanonical input without a real upstream producer), rotate-Ac RA companion
(misdiagnosis resolved by #578), and the retracted bitmask-loop report.

## Flowchart

Solid arrows show work/dependencies. The independent tracks can proceed in parallel.

```mermaid
flowchart TD
  subgraph Independent[Independent fixes]
    MC[MVN/MVP complete fix] --> MCT[Validated: five checks; 130 suite tests pass]
    MCT --> MCP[Compiler PR 604 posted] --> MCM[Review and merge]
    Z[Common SDK longjmp zero fix] --> ZT[Integrated SDK regression: 20 pass]
    ZT --> ZP[SDK PR 450 posted] --> ZM[Review and merge]
    OPEN[Compiler PRs 578 / 584 / 586 / 588 / 589] --> REVIEW[Review / CI follow-up] --> MERGED[Merge]
    UNDEF[Undef-lane fix 0028 validated] --> HOLD[Wait until 320 and 321 are ready to open]
    HOLD --> FINAL[Choose implementation and review submission]
    FINAL --> UNDEFPR[Publish fix PR] --> MERGED
    RA[Register-exhaustion fix 0029: reviewed, full suites] --> RAPR[Publish fix PR] --> MERGED
    COPY[Physical-copy liveness fix 0030: reviewed and audited] --> COPYPR[Publish fix PR] --> MERGED
    COPYPR --> REUSEPR[Publish 0031 destination reuse on top of 0030] --> MERGED
    SCAV[Scavenger live-P fix 0011: stock-6502 producer, upstream-runnable test] --> SCAVPR[Publish fix PR] --> MERGED
    SYM[Register-named symbols 0032: reviewed and audited, full-corpus round trip] --> SYMPR[Publish fix PR] --> MERGED
    HOIST[Spill-hoist guard 0033: MOS/X86/ARM/AArch64 suites, emulator gate] --> HOISTPR[Publish fix PR, drops driver flag] --> MERGED
    TRIAGE[c-torture backend triage: prefetch, g constraint, return/frame address, tied asm operand, float vectors] --> NEXTFIX[Next fixes, ranked in TODO]
  end
  subgraph SNES[SNES platform — separate track]
    EXIST[Existing SDK PR 415 + our platform] --> RECON[Reconcile baseline target and CPU mode]
    NATIVE[Our native startup + stack contract + setjmp override] --> RECON
    RECON --> SDKPR[Post additive platform changes]
    SDKPR --> SDKMERGE[Review and merge SNES support]
  end
  subgraph Features[Compiler feature tracks]
    FARABI[Far ABI agreement] --> FAR[Prepare and post 320 series] --> FARDONE[Merge far support]
    ACCEPT[Agree proper 65816 support required by SDK 415] --> SDKMERGE
    WIDTHABI[Native-width ABI and clean extraction] --> WIDTH[Prepare and post 321 series] --> WIDTHDONE[Merge native-width support]
    FARDONE --> FARSDK[Integrate far SDK support]
    SDKMERGE --> FARSDK
    WIDTHDONE --> WIDTHSDK[Integrate native-width SDK opt-ins]
    SDKMERGE --> WIDTHSDK
  end
  subgraph Reports[Reports needing decisions or development]
    CONTRACT[Reentrant contract question] --> DECIDE[Agree semantics] --> FIX[Develop and test fix or documentation]
    GUARDS[Coalescing / trunc candidates: 0015, 0023] --> REPRO[Establish valid stock-upstream reproducers]
    REPRO --> FIX
    FIX --> REPORTPR[Post fix PR; link issue if one exists] --> REPORTMERGE[Review and merge]
  end
```

## Independent simulator discussion

The MVN/MVP PR is focused on the bank encoding fix and existing regression results.
The emulator proposal has been removed from its description and mockup.

A [separate discussion draft](pr-preparations/2026-09-20/65816-simulator-discussion-body.md)
([preview](pr-preparations/2026-09-20/65816-simulator-discussion-preview.html)) covers
prior work, 65816 runner choice, CI setup and test conventions. It is prepared but
unposted; execution coverage remains proposed, not implemented. This is a separate
work item, with no dependency on or merge condition for the MVN/MVP fix.

## What “issue” means here

An issue is a discussion/tracking artifact, not a category of incomplete code.
A fix PR can contain the reproducer and close a bug without a separately filed
issue. The three reports have different actual readiness:

| Report | Is a fix missing? | Why called an issue? | Best next deliverable |
|---|---|---|---|
| Reentrant | An agreed contract and validated implementation are missing | Maintainers must decide what the attribute promises | Small semantics report with source/IR evidence; fix or documentation follows |
| Undef-lane verifier | **No** | Stock-upstream reproducer and tested `VirtRegRewriter` fix are ready | Post the prepared PR |
| Native SDK setjmp | **No**, for our page-1 SNES contract | Fix needs an accepted native platform/ABI home | Platform PR including the override, optionally preceded by a support-gap issue |

Treat all as work items; distinguish them by evidence, implementation readiness and
dependencies. “Issue filed” is not “bug fixed,” and “no issue filed” does not mean
no fix can be submitted.

## Research notes and evidence

**Reentrant:** current clang `Reentrant` is marked `Undocumented`; lowering merely
suppresses the global `nonreentrant` attribute. MOSNonReentrant can then infer
`nonreentrant` for a `norecurse` function. [Issue #248](https://github.com/llvm-mos/llvm-mos/issues/248)
records the original opt-out motivation. A fresh upstream `opt` confirmed both functions gain the same `nonreentrant`
attribute set. The draft now avoids claiming an ordinary
C miscompile or using `longjmp` as evidence of simultaneous activations.
[Focused report](upstream-reentrant-soft-stack-issue.md).

**Undef lane:** an eight-instruction MIR reproducer fails on current upstream HEAD
without 65816 features. The failure is an identity copy removed by
`VirtRegRewriter` even though it carries an undef-lane definition. Patch `0028`
retains it as a zero-code `KILL`; the lit regression and downstream witnesses pass.
[Focused report](upstream-rc-undef-ra-pure-virtual-issue.md) ·
[PR body](upstream-virtregrewriter-undef-lane-identity-copy-pr.md).

**Native setjmp:** current SDK revision `3f6968bbc156ff9a63102a8e158db868819bd61c`
still has the common 6502 implementation and no SNES directory. #415 remains open.
The existing downstream runtime evidence is preserved; no new native emulator run
is claimed here. [Focused report](upstream-sdk-setjmp-issue.md).

**New zero-value bug:** compiled current upstream `setjmp.S` explicitly into the
existing 6502 simulator harness, using the local MOS clang and installed SDK support
libraries (`-fno-lto`). All four optimization levels (`-O0/-O1/-O2/-Os`) return the
failure sentinel 42 for value 0; values 1, 7, 256 and -1 pass. The candidate assembly
normalization passes all 20 combinations. This is isolated current-source runtime
evidence, not a from-scratch build of the entire latest SDK. The
[POSIX.1-2024 longjmp specification](https://pubs.opengroup.org/onlinepubs/9799919799/functions/longjmp.html)
requires zero to become one. [Repro](investigations/repro/upstream-issues-2026-09-20/longjmp-zero.c),
[candidate patch](pr-preparations/2026-09-20/sdk-longjmp-zero.patch),
[matrix](pr-preparations/2026-09-20/sdk-longjmp-matrix.txt).

GitHub searches of both repositories found no matching open issue for these three
report topics or the zero-value bug. Search results are not proof that no related
report exists. No issues, comments, PRs or branches were published by this research.

**SDK test integration completed:** fresh current-SDK libraries and simulator now
run the 20 cases through `test-sim`/CTest: baseline 16 pass / four zero failures;
fixed 20 pass. The compiler remains the local installed MOS compiler.
[Commands and evidence](pr-preparations/2026-09-20/sdk-longjmp-validation.md).

**Publication update:** [SDK PR #450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450) is open, head `0f8ad11589f5`;
the submitted description and commit match the reviewed bundle. Earlier no-publication
statements describe the research stage. MVN/MVP is now also published as [compiler #604](https://github.com/llvm-mos/llvm-mos/pull/604), head `ae3108c31890`.
