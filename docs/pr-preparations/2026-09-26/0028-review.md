# Patch 0028: implementation selection and independent review

Review date: 2026-09-26. Reviewer: OpenAI Codex CLI 0.157.1, model
`gpt-6-astra`, `xhigh` reasoning effort; verified child session
`01a0db96-a6cd-7800-82a5-6b871eb7e177`, agent `/root/review_inline_asm`.
This is a separate review pass, not a human or different-model review. Earlier
implementation and investigation credits remain in their original records.
Nothing was posted, pushed, or deployed. No shared compiler source, build
archive, or saved executable was modified.

Current disposition: the exact LLVM package subsequently passed the clean-base
validation audited in [the final follow-up below](#final-llvm-main-validation).
The initial recommendation and earlier-build evidence remain dated evidence;
the #320/#321 publication hold remains in force.

## Recommendation

Use the **existing per-instruction refactor** as the single implementation to
prepare for posting. Its exact starting artifact is
[0028-upstream.patch](../2026-09-21/0028-upstream.patch), SHA256
`699c6f95de7cbe7bb1f686f52be8b937e18c3226d5426015927832c47a1dfeeb`.
No correctness or material maintainability defect was found that justifies
replacing the already tested implementation with the boolean-parameter variant.
The latter remains a reasonable alternative, not a defective implementation.

For `llvm/llvm-project`, extract the **unchanged VirtRegMap.cpp source diff**
and substitute the X86 regression and six X86 companion contracts developed in
this review; do not submit the MOS test files to that repository. The full
existing artifact remains applicable to `llvm-mos/llvm-mos` with its MOS tests.
The coordinating agent owns the final extracted patch, current-main build, and
posting-package identity. This review approves the selected source algorithm
and the proposed X86 tests, not an unexamined final package.

**The user's #320/#321 presentation/publication hold remains in force.**
Selecting one implementation and preparing a generic regression do not lift
that hold. Neither this review nor the new X86 MIR establishes ordinary
stock-upstream C reachability. Readiness to prepare/open and permission to post
are separate; the current instruction expressly forbids posting anything.

## Why retain the refactor

The reviewed boolean artifact is
[0028-boolean-parameter.patch](../2026-09-21/0028-boolean-parameter.patch), SHA256
`cb6b248b1b788278a839a84dcce5087d5189cbe4138b0e0064aaaf10bcaf7d70`.
It is byte-identical to `build/0028-refactor/bool-parameter.patch`.

The two versions compute the same pre-rewrite lane predicate and preserve an
identity copy under the same condition. The boolean version has a smaller diff
and explicitly passes a fact across the two phases; there is nothing inherently
wrong with that API. The refactor keeps both phases and their shared fact inside
one operation whose argument is the instruction being transformed. It avoids
instruction-local mutable pass state and is already the implemented, tested,
documented candidate.

Source audit of the refactored file found:

- Lane detection runs before virtual identities/subregister indices are erased.
  It considers only the source subregister's lanes when present, subtracts the
  live subranges, and does not incorrectly mark the whole partial source undef.
- Operand rewriting, implicit kills/deads/defs, bundle expansion, and identity
  cleanup keep their original order. `*MI.getParent()` substitutes for the
  enclosing block iterator before bundle expansion, when they name the same block.
- The physical-copy check, identity-copy statistic, deferred-allocation guard,
  `RewriteRegs`, slot-index removal, and `eraseFromBundle` bookkeeping remain.
  The outer early-increment loop does not touch an erased instruction afterward.
- All three temporary vectors are exhausted before cleanup. Giving them
  instruction scope does not carry or drop pending operands between instructions.
  It can change allocation-capacity reuse for unusually large operand counts;
  the earlier timing experiments did not show a consistent slowdown, but are not
  a proof that every target/workload has identical compile time.
- Final physical-register live-range invalidation and `RewriteRegs.clear()`
  remain outside the instruction loop.

There are **no P0/P1/P2 implementation findings**. The larger mechanical diff is
a review cost, not a demonstrated semantic or performance regression. Preserving
one stable candidate with tested contracts is preferable here to switching
implementations solely to reduce line count. The
[September 22 smaller-patch recommendation](../../plans/2026-09-21-0028-local-identity-copy-state.md#publication-hold-and-implementation-choice--2026-09-22)
remains dated evidence of an alternative, not an earlier user selection.

## Prior-work reconciliation and scope

Reviewed the original [implementation/validation record](../2026-09-21/0028-validation.md),
[reachability search](../../investigations/2026-09-22-0028-plain-6502-reachability.md),
current PR draft and tracker, Git history, standalone artifacts, and live/saved
VirtRegMap sources. The patch is existing work; this review adds validation and
a non-MOS test rather than claiming a new compiler fix.

The canonical [bitboard record](../../defects/bitboard-inline-register-pressure.json)
and [coalescing-witness record](../../defects/mos-coalescing-rc-undef.json) already
identify 0028 as the repair. Fresh replay of both recorded matching-input pairs,
with their compiler and input hashes checked, reproduces the expected verifier
failure without 0028 and success with it. The reconstructed baselines are not
the missing original August/June toolchains.

The [0015 investigation](../../investigations/2026-09-25-coalescing-0015-revalidation.md)
establishes a trigger-avoidance guard, not a separate proven allocator/regmask
repair for its recovered witness. Retain that guard and historical evidence;
do not revive the superseded standalone diagnosis or remove the guard as part
of preparing 0028. No additional canonical defect record is needed for the X86
model of the same identity-copy lane mechanism.

## Current-source applicability

The exact `VirtRegMap.cpp` blob is identical in LLVM main
`e59a0c697552ae7d1c3aeed5774e829cdc5e16b5` and llvm-mos main
`7bd67c0ae4e8bb65a3f980912bf201df22131e34`:
Git blob `92a5996c733e4f4f51bb0835a44e2abf1abd12cb`, SHA256
`1ded7d97cb2d2936eb2a06472406e3fac966f0a1f9634a152d82b6608b3da48e`.

I exported those blobs read-only into reviewer-owned scratch trees and checked
and applied the existing refactored artifact there. Both applications succeed.
The resulting source is byte-identical to the preserved tested
`build/0028-6502/VirtRegMap.patched.cpp`, SHA256
`6086afbeb17b6a8ffb6724644712aa77f279ef70b90d5c4555f9f817cb4cdd5c`.
This establishes exact source applicability, not a fresh complete build of either
current repository. The ability to add a MOS test file does not make that test
runnable in LLVM main, which has no MOS backend.

## Fresh tests and generic-target regression

The existing MOS regression still fails on saved upstream
`build/0028-6502/llc-unpatched` and passes on `llc-patched` and the saved
`build/0028-refactor/llc-bool`. The six MOS companion functions pass on all three.
FileCheck succeeds for every expected green result. In this new comparison,
the boolean and refactor output files differ only in the fork-versus-upstream
module datalayout line; the complete files are **not** byte-identical.
The earlier same-fork 24-input equivalence result remains separate dated evidence.

A constructed X86 MIR now exercises the same contract without MOS:

```mir
%0:gr8_abcd_l = MOV8ri 1
undef %1.sub_8bit:gr16_abcd = COPY %0
%2:gr16_abcd = COPY %1
%3:gr8_abcd_h = COPY %2.sub_8bit_hi
%4:gr32 = MOVZX32rr8 %3
$eax = COPY %4
RET64 implicit $eax
```

Run `-mtriple=x86_64 -enable-subreg-liveness` explicitly. The input passes
`-run-pass=none -verify-machineinstrs`; running `greedy,virtregrewriter` on the
baseline deletes the AX identity copy and then fails on an undefined AH use in
`MOVZX32rr8`. The selected refactor retains `renamable $ax = KILL renamable $ax`
and passes. This is a constructed backend regression with subregister liveness
enabled, not evidence of an X86 C frontend trigger or a default-X86 failure.
An initial plain `gr64`/low-byte probe had an invalid register-class/subregister
combination; its corrected full-RAX form passed. Neither was counted as a red
defect baseline. The high-byte model above passes input verification and is the
discriminating test.

Proposed tests, ready for the coordinator to retain and package:

| Reviewer scratch input | SHA256 |
|---|---|
| `build/post-ready-review-inline/0028/x86-undef-high-byte-result.mir` | `22bca8d6a976886fbe800a2697eae2fdf6cbe57335636581bc3232683d47e852` |
| `build/post-ready-review-inline/0028/x86-copy-contracts.mir` | `c5b2da74af50a3b855e719ab023cbc8d04421118bc681bcbe1061bb9b7abc169` |

The companion test covers six contracts: defined identity removal, explicit-undef
preservation, implicit super-register definition preservation, parallel-copy
ordering, defined source-subregister removal, and non-identity partial-undef copy
preservation. It passes both baseline and candidate. Both test files contain
normal RUN/FileCheck checks, not expected crashes or MOS instructions.

For causal validation, I compiled the **exact refactored VirtRegMap.cpp source**
and replaced only its object in a private copy of `libLLVMCodeGen.a`. All other
link inputs are the same for two private assertion-enabled cross-target links.
The original source/build directories were bind-mounted read-only; only
`build/post-ready-review-inline/` was writable. No installed compiler was replaced.

| Comparison executable | SHA256 |
|---|---|
| Preserved `build/0041-inlineasm-build/llc-0041` | `38ae5c6aa8cc91e2fd61912cfae42252e68b1178afdcd4117489499d0d7d9660` |
| Private `0028/cross-build/llc-baseline` | `ba8879650a4ecd92359195426ee1b272309a9b5d74005235ca3da5ae2aec4e94` |
| Private `0028/cross-build/llc-0028` | `af28e05daba4795dccef291d675b46eabe74c2294253e546e50d2094bf315fb8` |

The original cross-target build is an earlier patched llvm-mos build, **not** a
clean LLVM main build. Its baseline VirtRegMap source matches the current-main
blob above. The new build container identity is
`sha256:1a17c89d4817cdd5a1c46eacdce89d407558ec1e0dea31bca680ef1e7045de11`.
The private baseline/candidate archives hash to
`efce19f9f2b77a5a49b4ef174ad40b4c714fac299e6c3f81b67acff004203bcb` and
`5a43918315640285042ba7102d2c35d1ccfde400a306cc45610e6850338a54fe` respectively.

All twelve X86 runs have the expected result: two test files, three binaries,
input verification versus allocation/rewriting. The two pre-fix allocations
reject the failing model for the recorded reason; the fixed one passes. Every
input-only check and all companion checks pass. Fresh commands, diagnostics,
hashes, and build recipe are retained locally in reviewer scratch:

```sh
python3 build/post-ready-review-inline/review0028.py
python3 build/post-ready-review-inline/check0028x86.py
```

`0028/results.json` holds the MOS/current-source/canonical-witness results;
`0028/x86-results.json` holds matched-input X86 results; `0028/cross-build/`
holds build logs, binaries, and `identity.json`. The source/build helper is
`build/post-ready-review-inline/build0028.py`. These are fresh scratch evidence;
the coordinator must retain the relevant inputs/logs alongside the final
submission package rather than treating an ignored build directory as durable
publication evidence.

## Initial remaining gates (before the final receipt)

The implementation choice is resolved by this recommendation and the coordinator's
selection. Remaining work is to package/hash the exact source-only LLVM patch
with the two X86 tests, run the clean current-main build and relevant suites,
record the final receipt, and update dependent current summaries. This review
does not claim new all-target, AMDGPU/deferred-allocation, runtime, emulator,
performance, or GitHub CI validation. It does not clear the #320/#321 hold.
The coordinator owns document-dependency registration, maintained-summary
reviews, and generated inventory refresh.

## Final LLVM-main validation

The coordinator built the exact [LLVM packet](0028-llvm-project.patch), SHA256
`f312c1c59d31b7ee00fccbc21d529f449bf3938e9aa2f89c36c855bf0d15d8c2`,
standalone on LLVM `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`.
The archived [receipt](validation/runs/post-ready-validation-llvm/0028/receipt.json)
has SHA256 `8f839da3204ff874d3e50d3770646d2196e0ee0608974175a1d16794df11c834`.
Its Release build enables assertions and only X86/AArch64 targets, using image
`sha256:eeecfab76840167d9f16982b1efddae90d4969c5d7891ec16e87e46150ac94c1`.

The pristine current-main `llc` hashes to
`93b6a35c447f85042c65830e1daea85e0f6103c1fb380c3df78cec658009c81c`;
the exact candidate hashes to
`6358aa8563663ba264ca2ec0c424508ac2faa077b51cdf3b287127d9c3238560`.
The current baseline emits AL's definition but loses AX's identity definition,
then reports an undefined physical AH operand in `MOVZX32rr8` in
`undef_high_byte_identity_copy`. This is the same lane-definition mechanism,
not a test-tool failure. The candidate passes the same regression and all six
companion functions: two focused RUN commands pass. Both packet MIR hashes
match the reviewer-developed inputs recorded above.

The filtered AArch64/X86 allocation/spill suites pass: baseline 100 passes and
one expected failure; candidate 102 passes and the same one expected failure.
There are no unexpected failures. This is the filter
`(virtregrewriter|undef.*subreg|subreg.*undef|regalloc|spill)`, not full target-suite
or all-target coverage. The candidate suite excludes 9,855 other tests.

I independently rehashed the exact patch, both phases' four input snapshots,
all eight referenced logs in both local and archived copies, the archived runner,
and each phase's `llc`, `FileCheck`, `not`, and `split-file` snapshots. All match
the receipt; reconstructed patch inputs match the snapshots byte for byte.
No compiler build or regression rerun was performed by this final audit.
Build/test execution credit: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort, coordinator session
`01a0db16-f6a0-7e32-ada6-0c8098813933`. Final audit credit is the reviewer named
at the top. I authored the X86 fixtures, so this is not an independent review of
my own fixture design; the coordinator independently built and tested them.

The exact package's technical build/test gate is complete. **It remains held
from posting by the user's #320/#321 presentation decision.** This receipt does
not establish stock-C reachability, resolve historical #320 evidence gaps, or
add runtime, performance, AMDGPU, or GitHub CI coverage. Nothing was posted.
