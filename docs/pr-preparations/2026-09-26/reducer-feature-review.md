# Reducer and feature-dependent submission review — September 26, 2026

Independent reviewer: OpenAI Codex CLI **0.157.1**, subagent
`/root/review_reducer_features`, model **`gpt-6-astra`**, **`xhigh`** reasoning
effort. Verified from the subagent's session metadata and turn context, session
`01a0db97-39fe-7452-bbab-73d26f1d19a9`; this is not the parent session's version.

Scope: independently review the parallel MIR reducer's correctness and ownership,
then audit submission boundaries for `0013`, `0028`, `0045`, `0052`, `0054`,
`0055`, and `0061`–`0063`. The feature rows below are dependency/extraction
assessments, not a new comprehensive implementation approval. No remote writes,
posts, pushes, shared compiler rebuilds, or baseline modifications were made.

## Decisions

- Do **not** present the carried `0060` in-memory parallel MIR implementation as
  independently thread-safe. It fixes the preserved null-`MMI` witness, but its
  work items are not context-isolated. The earlier serial-fallback submission
  recommendation below is **superseded**: current LLVM already rejects parallel
  MIR. Prefer the exact existing-upstream guard backport to MOS, as established
  in the [current-upstream reconciliation](#0060-current-upstream-reconciliation).
- `0052` repairs a downstream far-addressing relaxation policy that is absent
  from current MOS upstream. Include it with that policy's feature series;
  do not submit it as an independently reproduced upstream failure.
- `0054` belongs to **llvm-mos**, despite changing a generic CodeGen file. Its
  target hook is absent from current llvm/llvm-project. The existing focused
  MIR reaches the affected path on a stock MOS compiler without native flags;
  a `#321` prerequisite is unnecessary if the candidate passes this configuration.
- The complete `0061` artifact requires **both** far and native-index compiler
  support. Its X8-only opportunity can be separated, but the current patch also
  defines `HasIndex16`/`Xc16` operations. `0062` additionally builds on `0061`.
- Compiler-feature dependencies and the user's `0028` presentation hold are not
  dependencies on merging the SNES SDK platform. Preserve those distinctions.

## Prior-work reconciliation

Reviewed the canonical
[reducer record](../../defects/llvm-reduce-parallel-mir-crash.json), its
[fix investigation](../../investigations/2026-09-25-llvm-reduce-parallel-mir-fix.md),
the earlier [0015/0028 investigation](../../investigations/2026-09-25-coalescing-0015-revalidation.md),
the [current queue](../../upstream-pending-work.md), TODO, carried patches, and
the live `ReducerWorkItem`, delta runner, MIR reduction passes, `MachineFunction`,
`MachineModuleInfo`, and MOS target hooks. Git history was searched for
`parallel.*MIR` and `llvm-reduce`; no separate canonical reducer defect is needed.

The preserved `0060` evidence is valid evidence for the **specific null-MMI
crash**. The review concern below is not a claim that its recorded red/green was
invalid, nor a new confirmed race defect. The separate historical `#320` failure
behind `0023` remains qualified; this review neither reconstructs its missing
original input/compiler nor closes it.

Read-only current source comparison used MOS main
`7bd67c0ae4e8bb65a3f980912bf201df22131e34`. The generic LLVM comparison used the
parent's retained `Delta.cpp` from LLVM main
`e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`, plus these exact upstream files:
[TargetRegisterInfo.h](https://github.com/llvm/llvm-project/blob/e59a0c697552ae7d1c3aeed5774e829cdc5e16b5/llvm/include/llvm/CodeGen/TargetRegisterInfo.h)
and
[RegisterScavenging.cpp](https://github.com/llvm/llvm-project/blob/e59a0c697552ae7d1c3aeed5774e829cdc5e16b5/llvm/lib/CodeGen/RegisterScavenging.cpp).

## 0060: ownership review and conservative alternative

The submitted algorithm correctly recognizes the immediate transport problem:
LLVM IR bitcode does not contain machine functions, so `readBitcode` does not
reconstruct `MachineModuleInfo`. The preserved parallel instruction reducer
therefore dereferences a null `MMI`. Returning a MIR work item avoids that loss.

The task queue itself waits for outstanding workers before modifying the chunk
sets. `shared_future` copies share the result work item, and moving the selected
work item out does not compete with a second reader in the inspected queue.
The shared `Module` ownership keeps the IR objects referenced by the machine
functions alive. These aspects are not findings.

The isolation claim does not extend to the other referenced objects:

1. `ReducerWorkItem::clone` assigns `CloneMMM->M = M`, sharing the module and
   `LLVMContext` between workers.
2. `cloneMF` constructs its destination `MachineFunction` with
   `SrcMF->getTarget()`, `SrcMF->getSubtarget()`, and **`SrcMF->getContext()`**.
   The newly allocated destination `MMI`'s `MCContext` is not passed to that
   constructor. This is true in both the carried source and current MOS main.
3. Verification, target-specific cloning, and MIR printing remain part of each
   worker. Separate machine-instruction allocators alone do not establish a
   thread-safety contract for all those shared contexts and target callbacks.

No data-race crash or ThreadSanitizer finding was reproduced in this review.
The MCContext relationship is an existing serial clone property, not an
independently diagnosed new defect. Nevertheless, extending that API to
concurrent execution needs an ownership/thread-safety argument and coverage
beyond the retained simple MOS input. Approval of the carried parallel design
is withheld on that basis.

### Earlier tested candidate, superseded for posting: MIR stays serial with `-j > 1`

The alternative adds a per-pass predicate:

```cpp
const bool UseParallelism = NumJobs > 1 && !Test.getProgram().isMIR();
```

Use it for thread-pool construction, bitcode serialization, and selection of the
parallel chunk-processing branch. MIR then follows the existing serial clone
path for every requested job count; IR's worker/context/bitcode behavior is
unchanged. This is a correctness fallback, **not parallel MIR support**. The PR
description must state that limitation.

The exact source-only candidate against retained current LLVM `Delta.cpp` is
`build/post-ready-review-reducer/0060-serial-alternative-source.patch`, SHA-256
`8ba24ca87c31501ebce005996a103fd0cb4234824836a4e497fd4aca7ba7cc0f`.
The baseline source snapshot hash is
`5b648a7574003b8a9268ea44bbc25c0c824709e760490bfb3ffcf8dded2c181e`.
The same transformation was compiled against the existing LLVM 23 vendor pin
and linked into two isolated tools, sharing read-only objects/libraries and
differing only in `Delta.cpp`. The current LLVM source itself was **not built by
this reviewer**. An exact-current isolated build remains a submission gate.

The candidate passes the retained MOS regression and original interestingness
test, and preserves the existing parallel IR regression. This reviewer approves
the fallback's small control-flow change; approval of an eventual upstream
package additionally requires the exact-current build and non-MOS regression
execution.

Proposed generic regression:
`build/post-ready-review-reducer/parallel-instr-reduce-x86.mir`, SHA-256
`1d01a1ab586789a133b44dd9880251b5798efc4c72dbcdd0a75c428c8ed60584`.
It requests `-j 1` and `-j 2`, checks that `MOV32ri 2` and `RET` survive, and
compares the serial outputs. Input validity was checked with the saved
assertion-enabled X86-capable `llc`; the reducer test's RUN lines still need
execution on an X86-enabled candidate. The source fix does not require MOS or
any far/native/SNES implementation.

## Fresh local checks and identities

All generated logs and executables from this review are confined to
`build/post-ready-review-reducer/`. The retained tools and evidence are unchanged.
Scripts `replay.py`, `build-serial.py`, and `test-serial.py` in that scratch
directory record exact arguments, build commands, output hashes, and exit codes.

| Check | Observed result |
|---|---|
| Preserved failing reducer, retained focused MOS MIR, `-j 2` | SIGSEGV, exit `-11` |
| Existing carried-0060 candidate, same focused MIR, `-j 2`, `4`, `16` | All exit `0`, FileCheck passes |
| Fresh matched unpatched Delta tool, focused MIR, `-j 1` / `2` | Serial passes; parallel exits `-11` |
| Fresh serial-fallback tool, same MIR, `-j 1`, `2`, `4`, `16` | All pass; four outputs identical to unpatched serial output |
| Serial-fallback tool, original retained MIR and `interesting-rewriter.py`, `-j 2`, one complete pass iteration | Exit `0`; output still interesting; hash equals prior retained green output |
| Serial-fallback tool, existing `parallel-workitem-kill.ll`, `-j 4` | Exit `0`, FileCheck passes |
| Proposed X86 MIR, saved cross-target `llc -run-pass=none -verify-machineinstrs` | Input passes verification; this is not execution of its reducer RUN lines |

The original-input replay used:

```sh
build/post-ready-review-reducer/llvm-reduce-serial -x=mir -j 2 \
  --max-pass-iterations=1 --test=/usr/bin/python3 \
  --test-arg=docs/defects/evidence/2026-09-25-coalescing-0015/interesting-rewriter.py \
  docs/defects/evidence/2026-09-25-coalescing-0015/stock-identity-copy-model.mir \
  -o build/post-ready-review-reducer/matched-serial-original.mir
```

| Artifact | SHA-256 |
|---|---|
| Preserved failing reducer | `993b1e90ac19b57723c03c9b6365c7864bdc1543b18bee508361a84c7f490db6` |
| Existing carried-0060 candidate | `9f9f8351fea4032544a2ad6ca563cc2f0ef327ebf8aabbdd61226a7d221a79dd` |
| Fresh matched unpatched Delta tool | `558bb7e82958e3e51adcbdec18fff1a12caa038fe72dc2e896a54e8b6a2287d0` |
| Fresh serial-fallback tool | `9fed0314606de29a1300a04d33be42f6c65c0d4cb8e636aca979736a8b5d9329` |
| Original-input reduced output | `5818c65ef6859f96e8b966ee402fae888a1d303eccfaf4a246ecd9d699f3acca` |
| `serial-build.json` | `a65431468755493479e0d1424d0bbdcb3520d9142f4fd1f744949539cf72c6db` |
| `serial-tests.json` | `9f8dd7f03fcdf0baeb4262f5d0437ff2bb0826ecfe9aa460cfcc4964d0dab7fe` |

Build conditions: `g++ 15.2.0`, C++17, `-O2 -DNDEBUG`, no sanitizer; read-only
existing LLVM 23 headers and libraries. This is a scoped Delta-only validation,
not a fresh rebuild of the entire compiler or an assertion-enabled reducer run.
The saved cross-target input validator hash was
`149af7e3d2547e574ac72e8ed80d75572d87dfef7fe921bc982960fe5acd3e95`.

## 0054: usable stock-MOS trigger and correct venue

This subsection retains the earlier same-day **assertions-off** observation.
Its PEI entry is not an approved current assertions-on regression. The
[current-build follow-up below](#0054-current-assertions-on-follow-up-and-final-packet-approval)
qualifies that attempt and records the replacement test and final approval.

The exact existing `scavenger-status-save-range.mir` needs no native feature
flags to enter the erroneous range extension on the preserved stock compiler:

```sh
build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin/llc \
  -mtriple=mos -mcpu=mosw65816 -run-pass=prolog-epilog -verify-machineinstrs \
  vendor/llvm-mos/llvm/test/CodeGen/MOS/scavenger-status-save-range.mir \
  -o build/post-ready-review-reducer/0054-stock-current-pass.mir
```

This exits `-6`. The output attempts `$rc17 = STImag8 $p` and
`$p = LDImag8 $rc17`; both violate the GPR operand contract. The save was extended
outside the balanced accumulator push/pull interval. This is an additional
stock-MOS observation of the existing range defect, not a new discovery or
new canonical record. The old test's `prologepilog` spelling instead exits `1`
with “run-pass prologepilog is not registered”; that is **not** a red defect test.
The modern spelling is `prolog-epilog`.

The read-only current MOS source still checks `canSaveScavengerRegister` when
choosing a survivor but extends the range without rechecking it. The carried
fix conservatively keeps the last feasible range if extension is rejected;
the source change has no native-width feature dependency. Replay the native-free
test on the exact current unpatched/patched MOS tools and check PHP/PLP ordering.
This reviewer approves that source-level repair, subject to those package checks.

LLVM main at the recorded revision has neither the target hook nor its initial
call in `findSurvivorBackwards`. A PR against llvm/llvm-project would therefore
need a different proposal that introduces the hook/contract, not the extracted
`0054` fix alone. Current **llvm-mos** is the appropriate standalone venue.

Local failure log SHA-256:
`43e5698368cc3eb9db43e22d38ef96e42aae42faf34bb4fd3909cb7c111e9114`.
The exact command, reference binary hash, input hash, and failed obsolete-pass
control are recorded in scratch `results.json`, SHA-256
`a6852bdff678c706a247ddd430748144e1cc7d669fe302d4ee7e4f553c5f66b1`.
The reference revision is **742d554b**, not today's 7bd67c0 source comparison.

## Feature and extraction audit

“Prepare with prerequisite” below means a coherent local stacked submission can
be prepared; it does not mean the feature already exists on upstream main or
that its current package has completed isolated validation.

| Item | Correct submission boundary | Genuine readiness requirement |
|---|---|---|
| `0013` far memops | Part of far-pointer compiler/runtime ABI work. Existing [same-input revalidation](../../investigations/2026-09-26-far-memset-revalidation.md) establishes the older repair; do not rediscover it. | Extract after far pointer types, casts, call lowering, and the agreed `__memset_far`/`__memcpy_far`/`__memmove_far` ABI. Explain the bank-zero widening contract and where the runtime symbols come from. Compiler posting need not wait for an SNES SDK merge. |
| `0028` undef-lane identity copy | Generic CodeGen repair with a constructed **stock-MOS** MIR regression. Natural C witnesses are downstream native-width programs. The current refactor and smaller boolean alternative are already retained. | Choose and revalidate the exact artifact, retaining the user's September 22 hold until `#320/#321` are ready to open. Do not turn the presentation hold into a technical SDK dependency or claim stock C reachability. Routing `0015`'s recovered witness here avoids a duplicate repair PR. |
| `0045` native immediate printing | Printer correctness coupled to a producer of plain small 16-bit immediate MC operands. Existing regression uses downstream `+mos-a16`; disassembly wraps operands itself. | Prepare with `#321`, or provide a genuine independently runnable MCInst/printer test that exercises the unwrapped operand. An MC assembly/disassembly round trip alone does not exercise this producer. No SDK merge prerequisite. |
| `0052` bank-relax section offset | Correction to downstream suppression of ordinary-section bank relaxation, introduced with far/near policy. Current upstream has no such suppression. | Carry with that policy and document near-bank/section ABI assumptions. Do not describe current upstream's conservative relaxation as this wrong-width defect. |
| `0054` scavenger range | Standalone llvm-mos fix to its generic hook contract; stock trigger demonstrated above. | Modernize pass spelling, omit unnecessary native flags, and validate exact current red/green and output ordering. Not a standalone llvm/llvm-project patch. |
| `0055` wide ANYEXT | `hasAccum16()`-gated legalizer change, part of the `#321` compiler series. [Original-input and runtime evidence](../../investigations/2026-09-25-shift-inlineasm-fixes.md) is retained. | Isolate after the native-width legality implementation; keep s8/s16/s32-to-s64 and masked-byte tests, including default-mode controls. No independent upstream native trigger before the feature exists. |
| `0061` far `long,X` | X8 slice needs `#320`; the **whole existing patch** also needs `#321` index-width features, `HasIndex16`, `Xc16`, and local width-mode handling. | Either split the X8 feature from the X16 extension or declare both compiler prerequisites. Validate unsigned-byte, unsigned-word, scaled-byte, negative/signed, and fallback paths on the extracted stack. Measurement-only historical prose is not implementation validation. |
| `0062` native far word accesses | Depends on far addressing, native accumulator support, and `0061`'s far indexed pseudos; native indexed-word cases also use X16. | Prepare after those compiler pieces, retaining bank-boundary runtime evidence, byte-resident ABI controls, explicit long-form selection, and verifier tests. Independent generic LLVM venue is inappropriate. |
| `0063` near shared store | Native-width optimization over the byte-store lowering and test already carried inside `0002`. | Extract the underlying near-store implementation/test with `#321`; `0063` alone modifies an absent upstream test. Preserve atomic, call/inline-asm, cross-block, and native-producer controls. Its unit-arithmetic improvement does not claim the broader indirect/shared-value cases completed. |

The `0061`/`0062` measurement records explicitly describe a measurement-only
phase. Their historical results should remain dated; link implementation checks
from the new preparation package rather than rewriting the measurements to
pretend that they already tested the later compiler implementation.

## Handoff

The parent owns current-summary, draft, canonical-record, dependency-manifest,
inventory, and final package updates. Incorporate the review and relevant local
logs into the durable preparation evidence before claiming a new submission
gate complete. None of this review authorizes or performs publication.

## 0054: current assertions-on follow-up and final packet approval

Later on September 26, the coordinator's isolated build at MOS main
`7bd67c0ae4e8bb65a3f980912bf201df22131e34` exposed an input-entry limitation
not checked by the earlier release replay. Both unpatched and patched tools
abort in `PEIImpl::spillCalleeSavedRegs` at
`MF.getProperties().hasNoVRegs()` when given the old raw scratch-vreg MIR
through `prolog-epilog`. That is an **invalid test entry**, not matching-input
red/green evidence for the repaired range contract. The earlier old-pass-name
failure and assertions-off execution above remain dated observations; neither
establishes a valid current PEI fixture.

The coordinator retains both failures under
`build/post-ready-validation-mos-r2/0054/`. Its receipt has SHA-256
`1559a90186c19d0cbe311577b1b80f444c03fa9fdfa6eaeef27f05aaf7407035`.
No assertion was disabled and no MIR property was falsified to get past this
gate.

### Valid scavenger entry and isolated trigger

Current upstream already provides `scavenger-test`, a registered test pass
which initializes the scavenger and calls `scavengeFrameVirtualRegs` directly.
Existing MOS `scavenger.mir` and `scavenger-65c02.mir` use it for block-local
scratch virtual registers. It is the appropriate entry point for this input.

Simply switching the old fixture to that harness reached the baseline's genuine
P-save assertion, but the candidate then hit `assertNZDeadAt` while spilling
another GPR around inserted status operands. That intermediate attempt is
retained under `build/post-ready-review-reducer/scavenger-valid-entry-v2/`.
It is not passing candidate evidence or a separately diagnosed compiler defect.
The [later reconciliation below](#0054-residual-nz-assertion-is-the-existing-0011-contract)
establishes that this is a **valid input exposing the already-recorded 0011
N/Z-liveness problem**, not an invalid fixture to dismiss.
The first scratch attempt, in `scavenger-valid-entry/`, used a `.txt` filename
without selecting MIR input and stopped in the input parser; it is not a defect
reproduction either.

The replacement moves the X=6 and Y=7 definitions until after the first virtual
value's last use, before the balanced accumulator push/pull pair. Thus the
unrelated scratch value can use free X without spilling, while X, Y, and carry
are all live over the temporary status value. The earlier virtual use still
tempts the faulty backward extension across the unmatched accumulator push.
The transformation changes only test construction, not compiler source.

Exact fixture:
`build/post-ready-review-reducer/scavenger-status-save-range-isolated.mir`,
SHA-256 `cbcf1622dc2024d68aa5b50ced78db65ba2184fc12fe54923829c62e23c4145a`.
Both saved binaries separately exit 0 with
`-mtriple=mos -mcpu=mosw65816 -run-pass=machineverifier` on that input before
scavenging. The fixture declares no false `noVRegs` property.

Fresh independent comparisons use `-run-pass=scavenger-test
-verify-machineinstrs`, with no native-width feature flags:

| CPU | Preserved unpatched tool | Identified candidate |
|---|---|---|
| `mos6502` | SIGABRT at P-save range assertion | Exit 0; FileCheck passes |
| `mos65c02` | SIGABRT at P-save range assertion | Exit 0; FileCheck passes |
| `mosw65816` | SIGABRT at P-save range assertion | Exit 0; FileCheck passes |

The genuine baseline assertion is in `MOSRegisterInfo::saveScavengerRegister`,
`MOSRegisterInfo.cpp:201`: a P save cannot use an unbalanced hardware-stack
interval. The candidate retains `PH $a; PH $p; temporary carry work; $p = PL;
$a = PL`, with the original carry used afterward. The expected stored-byte
contract is unchanged, but no new ROM execution is claimed.

The exact saved `llc` hashes are:

- Baseline: `f215e4d24f07a5e6720de665f5fdbda4b6b537aac021c55bbe14678f53af8331`.
- Candidate: `b4f1c266fb28d34e6eaddfc41b81f45c9fba27641207195f9c9c45eab7cf4096`.

Commands, all three CPU outcomes, tool/input hashes and logs are retained in
`build/post-ready-review-reducer/scavenger-valid-entry-v3/results.json`, SHA-256
`17396013d2984b42245b68e7358af825b3ea3791ff175d8b7b02ed0f1a0aaa02`.
The w65816 baseline log has SHA-256
`3416dbc2351fc2eca021d5ce3dc110a3971a5e4a504347a6236160d013d1ff49`.
This reviewer executed these comparisons using the coordinator's saved tools,
not a new reviewer-built compiler.

### Final posting-artifact audit

**Approve the exact [0054 posting patch](0054-llvm-mos.patch)**, SHA-256
`a80b2ed392acfef33ff33b18934c9801721bbd62c4c2314bf1f4d30a3f30178f`, for
the llvm-mos venue. Extracting its new test yields the exact fixture hash above.
Its `RegisterScavenging.cpp` source-diff section is byte-identical to the
previously reviewed carried patch's section, SHA-256
`77ba83ae16f9e626e40a7b80d748eb22f9ab87dcf725d68cce99385045aeacb0`.
This is a regression-entry correction, not a new source algorithm.

The coordinator's completed final receipt,
`build/post-ready-validation-mos-r3/0054/receipt.json`, SHA-256
`45f4f23cdcdfaab7ad35c4a4584e3c808584a5af7e2680928495079a28fd628b`, identifies
that exact base, patch, test and both compiler hashes. The retained CMake cache
sets Release with `LLVM_ENABLE_ASSERTIONS=ON`. Both builds succeed; the baseline
log shows the genuine P-save assertion, the candidate's packaged RUN passes,
and the current MOS CodeGen/MC suite reports **132 passed, one unsupported,
zero failed**. I inspected that receipt and its logs; the coordinator ran the
build and suite. The draft correctly states the harness, venue, three-CPU
supporting checks and distinction from the historical runtime evidence.

Independent fixture development, execution, and final-package review in this
follow-up: OpenAI Codex CLI **0.157.1**, subagent `/root/review_reducer_features`,
model **`gpt-6-astra`**, **`xhigh`** reasoning effort, verified session
`01a0db97-39fe-7452-bbab-73d26f1d19a9`. Earlier implementation and coordinator
build credits remain separate. No posting, source modification, or baseline
replacement was performed by this reviewer.

## 0054 residual N/Z assertion is the existing 0011 contract

The v2 `scavenger-test` input is valid: both current assertions-on tools accept
it with `-run-pass=machineverifier`, as do the retained 0011 compiler and the
integrated fork. Its candidate failure must not be dismissed as merely an
invalid fixture. The **PEI entry** was invalid; the separate **scavenger-test
entry** exposes two existing compiler limitations in sequence.

Prior-work reconciliation identifies the exact second assertion in the
[0011 investigation](../../investigations/65816-a16-scavenger-nz-liveness.md),
[0011 PR draft](../../upstream-scavenger-live-p-pr.md), and
[September 22 stock-6502 reachability record](../2026-09-22/0011-stock-6502-reachability.md).
The existing repair was introduced in `a320cbd3`, with the stock witness and
liveness guard updated in `1327d596`. Its target implementation removes
`assertNZDeadAt`, whose per-save N/Z-dead assumption is not a general invariant
for interleaved GPR/status saves. The 0054 source does not change that assertion
or its target implementation. No new defect record or repair is warranted.

To distinguish mechanisms, I constructed
`build/post-ready-review-reducer/scavenger-nested-save-control.mir`. It explicitly
contains the balanced P save/restore that 0054 retains, leaving only the earlier
GPR scratch virtual. No virtual status register or invalid range extension is
needed for this control to reach `assertNZDeadAt` on **unpatched current MOS**.
The full-P use makes N/Z appear live to the target's backward precondition even
though only incoming carry is semantically consumed by this witness. Both
the current baseline and 0054-only candidate reject it at the same assertion;
the previously preserved assertions-on 0011 build accepts it with the expected
Y-save/P-save ordering and MachineVerifier enabled.

Fresh read-only execution results:

| Input | Pristine current MOS | Current MOS + 0054 | Retained 0011 + 0030/0031, before 0054 | Integrated fork |
|---|---|---|---|---|
| v2 combined virtual-status/GPR witness | P save-range assertion | `assertNZDeadAt` | Unbalanced P range, no free index register | Pass, FileCheck passes |
| Explicit balanced-status / virtual-GPR control | `assertNZDeadAt` | `assertNZDeadAt` | Pass, FileCheck passes | Pass, FileCheck passes |
| Existing 0011 `scavenger-p-undef-6502.ll`, O0 | `assertNZDeadAt` | `assertNZDeadAt` | Pass, FileCheck passes | Pass, FileCheck passes |

The nested MIR runs use stock `mosw65816`, no native flags, and the valid
scavenger harness. The existing LLVM IR witness uses stock `mos6502` and the
normal pipeline through PEI. All successful checks include machine verification.
The old 0011 executable reports an optimized assertions-enabled LLVM 24 build;
its documented base is `742d554b` plus 0030/0031, **not** current main. The
integrated fork has assertions off and contains many other patches: its success
is supporting evidence, not an isolated assertions-on combined-fix proof.

**The exact 0054 package approval stands for the range-feasibility repair.**
Its valid isolated regression reproduces that specific mechanism and passes
with 0054 alone; the full current MOS suite also passes. The combined v2 witness
is not repaired by 0054 alone, and the draft/evidence should say so. The separate
0011 false-assertion repair is an existing upstream submission, not a new
0054 regression or a reason to claim all scavenger failures fixed. Opening
0054 independently is sound with that scope; combined coverage needs both
contracts satisfied. No causal claim is based solely on changing the test to
avoid the residual.

Exact additional provenance:

- Reconciliation manifest:
  `build/post-ready-review-reducer/scavenger-nz-reconciliation/results.json`,
  SHA-256 `00792e45135d7d1ad16906248bfe4dbfc9c38e2782064f883ad0cb2f2bf46fd8`.
- Nested control SHA-256:
  `c2f78c93143c6c149f4f468f671a45ba9688ec6f0fb6567ea9a6a36b3eb42c39`.
- v2 fixture SHA-256:
  `62c100687cf1d689614b21d384303153f1425baf738a0c0163fa919ec1fdecee`.
- Retained `build/0030-claude-review/llc-0031-plus-0011` SHA-256:
  `a1e94512271b745b9b2343def2bf03cce9ab8ed0bf1e9ca9d12cb193f93db320`.
- Existing 0011 test SHA-256:
  `1de8c3986b43fb7d7605aefc4fce8fafa2c5e396ff68dc1e5a7a4c31b528d108`.

The current baseline/candidate and integrated compiler hashes remain those
recorded above. The new manifest retains exact commands, input-validity checks,
outputs and log hashes. No recompile or source modification was made.
Reconciliation, controls and review: OpenAI Codex CLI **0.157.1**, model
**`gpt-6-astra`**, **`xhigh`** reasoning effort, subagent
`/root/review_reducer_features`, verified session
`01a0db97-39fe-7452-bbab-73d26f1d19a9`. Historical 0011 attribution is retained
in its linked records.

## 0060 current-upstream reconciliation

This later September 26 check **supersedes the LLVM serial-fallback submission
recommendation above**, without changing the earlier experiments or the
preserved local defect evidence. The coordinator's first exact-current LLVM
build exposed an entry-point guard that the earlier Delta.cpp-centered current
source comparison did not inspect. The original retained binaries were not
current LLVM, so their red/green results could not establish current LLVM
reachability. This was a reconciliation gap in this preparation review.

Current LLVM already carries
[`b1ba3d515a0238adbfc6c349ed3b33f9060cea72`](https://github.com/llvm/llvm-project/commit/b1ba3d515a0238adbfc6c349ed3b33f9060cea72),
[`llvm-reduce: Error on -j with MIR inputs` (#226225)](https://github.com/llvm/llvm-project/pull/226225).
The published commit is dated **September 24, 2026, 17:24:49 UTC**, before the
September 25 local report. Read-only GitHub commit-history and commit-detail
queries identify the original change; the truncated local LLVM clone cannot
traverse its missing parent objects. The retrieved metadata and exact hunks are
retained in [0060-upstream-guard.json](0060-upstream-guard.json), SHA256
`df30e3ec3f104e1b11041cfeb6bd07b39bdb81c4094fde46e29c9d64365317d0`.
Original author: Matt Arsenault. The published AI co-author credit is Claude
Opus 5; actual tool/version, exact model ID/version and reasoning effort are
unknown in that metadata, not inferred from this review's session.

In LLVM `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`, `llvm-reduce.cpp` rejects
`ReduceModeMIR && getNumChunkProcessingJobs() > 1` before parsing or dispatching
the work item. Its diagnostic is `-j is not supported for MIR reduction`, exit
1. The upstream commit includes an existing
`mir/parallel-jobs-unsupported.mir` regression, a Delta.cpp job-count accessor,
its Delta.h declaration, and the CLI include and guard. MOS main
`7bd67c0ae4e8bb65a3f980912bf201df22131e34` lacks all these additions.

Consequently the proposed LLVM Delta-only fallback is unreachable for the
advertised CLI input. Do not remove the guard to manufacture a red test, file
a new LLVM defect, or claim another LLVM repair. Keep the abandoned
[LLVM patch](0060-llvm-project.patch), SHA256
`c6c82bd59f2b1840c9ae0151850e93fe678bcefc97f1ab29f9aee8cc5a3006f9`, and its
[superseded draft](0060-llvm-serial-pr-body-superseded.md) as rejected local
preparation artifacts, not ready submissions. The captured baseline/candidate
receipt at `build/post-ready-validation-llvm/0060/receipt.json`, SHA256
`2ab519d0d4fe1b6fa4ad69b66ed0d0a55e53a309283977d08edf70e37b4978d8`, records a
failed preparation attempt and must remain distinct from successful evidence.

That initial standalone RUN harness also passed bare `FileCheck` as the
interestingness executable. Unlike lit's tool substitution, that invocation
did not resolve the executable path for the spawned test. Its first `-j 1`
failure is a harness failure, not causal defect red. Fresh checks explicitly
name the preserved FileCheck binary and recover the expected serial behavior.

### Fresh current-tool comparison

Using the valid X86 MIR already retained in this scratch directory and an
absolute FileCheck path:

| Preserved tool | MIR `-j 1` | MIR `-j 2`, `-j 4` | Parallel IR control |
|---|---|---|---|
| Pristine current MOS main | Passes and remains interesting | SIGSEGV (`-11`) | Passes |
| Pristine current LLVM main | Passes and remains interesting | Both diagnostic exit 1 | Passes |
| LLVM with the rejected Delta-only candidate | Passes and remains interesting | Both diagnostic exit 1 | Passes |

Binary SHA256 values:

- MOS `build/post-ready-validation-mos/0039/baseline-bin/llvm-reduce`:
  `92e017df99e79256919f4e88fce4086f3c2d91802ade48f0a313a5e80a5bfde1`.
- LLVM `build/post-ready-validation-llvm/0060/baseline-bin/llvm-reduce`:
  `857b5b41f3488f12135bb89a1cc34d9f0c25f8def0d84186833e71469deabfde`.
- Rejected LLVM candidate, sibling `candidate-bin/llvm-reduce`:
  `a3b995967330c41ce17e264ee3bf0f6e1d66fb6bca73dfa610ebeee315adc55d`.

All are identified Release/assertion-enabled snapshots. Commands, versions and
log hashes are retained in
`build/post-ready-review-reducer/0060-current-upstream-reconcile/results.json`,
SHA256 `c9ab41c39b3370dcf3b0d0ab733329bafe3126b8475f32412551f8860b9a841a`.
No existing binary or source was edited, and no LLVM guard was disabled.

### Preferred MOS backport and extraction review

The [MOS package](0060-llvm-mos.patch), SHA256
`a62ebcdbdd7059d85c638e20c9bff8efaed808e9df5c35c4d2d6c93b3be04601`, carries
**all four original upstream file changes verbatim**, not just the CLI hunk.
The accessor exposes the existing requested job count; the early guard selects
only multi-worker MIR requests. Serial MIR and all IR requests remain on their
existing code paths. This follows current LLVM behavior and has no compiler
feature, ABI, SNES or other local candidate prerequisite.

The sole addition beyond the published backport is a valid X86 MIR companion
test. It first verifies MIR validity, exercises successful serial reduction,
requires clean diagnostics for both inferred `-j 2` and explicit `-x=mir -j 4`,
and checks parallel IR through existing `operands-skip.ll`. Its SHA256 is
`d2554ec26ed0c0fbd00efb8c4eda808b20caff776d5b8de26dc3cb5412cb63e5`.
All seven RUNs pass on preserved current LLVM. On preserved current MOS, the
input verifier, serial reduction/check and parallel IR/control pass; the two
guard expectations fail because the reducer crashes. This supplements the
original upstream error-path test with a genuine valid-input baseline witness.
Exact commands/logs are in
`build/post-ready-review-reducer/0060-guard-packet-check/results.json`, SHA256
`30b48c0acf5d6021b1579ffd9c10f5a15e70fe845f9b47c35be9a74e24a85b75`.

The package passes `git apply --check` on current MOS. Source extraction was
approved as an existing-upstream backport; exact MOS candidate compilation,
matching-input diagnostic green, and reducer-suite checks were pending at this
stage and subsequently completed below.
Current LLVM's passing result proves the upstream behavior, not that the MOS
backport has been built. Silent serial fallback is no longer the preferred
posting alternative, and the shared-context parallel candidate still lacks a
general thread-safety review approval. The canonical local failure and all
earlier evidence remain intact; its current upstream scope must link the
already-published repair rather than create a duplicate report.

Reconciliation and backport review: OpenAI Codex CLI 0.157.1 (`codex-tui`),
model `gpt-6-astra`, `xhigh` reasoning effort, verified reviewer session
`01a0db97-39fe-7452-bbab-73d26f1d19a9`.

### Final exact MOS backport approval

The coordinator's completed receipt is
`build/post-ready-validation-mos-reducer/0060/receipt.json`, SHA256
`cbceaf24d6bdf5a1608c31c9a101c78588640479ad7a5a27ca5684172e9b1950`.
It identifies MOS main `7bd67c0ae4e8bb65a3f980912bf201df22131e34`, the unchanged
packet hash `a62ebcdbdd7059d85c638e20c9bff8efaed808e9df5c35c4d2d6c93b3be04601`,
and no candidate prerequisite. The retained CMake configuration is Release,
assertions enabled, MOS plus X86/ARM/AArch64 targets. Container image:
`sha256:eeecfab76840167d9f16982b1efddae90d4969c5d7891ec16e87e46150ac94c1`.

The preserved baseline reducer hash is
`92e017df99e79256919f4e88fce4086f3c2d91802ade48f0a313a5e80a5bfde1`; candidate:
`3415ba4d35ceb2a4317515a75e20c5e95d22f690e80030ba5a633dc3d940c8bd`.
This reviewer checked those files against the receipt, the exact fixture hashes,
the baseline failure logs and the suite summaries. The valid companion passes
input verification and serial reduction on the baseline, then its parallel
request segfaults in instruction reduction. The candidate passes all nine
focused RUNs, including clean diagnostic checks in both input modes and the
serial-MIR/parallel-IR controls. Absolute FileCheck substitution is recorded
in every standalone interestingness command.

The original tiny upstream test's baseline failure is **not** crash proof:
without the guard it invokes FileCheck without a matching CHECK prefix and
reports an uninteresting input. The valid companion supplies the actual
matching-input crash-to-diagnostic comparison. A verifier warning about an
attempted reduction in that crash log does not invalidate the starting MIR,
which independently passed input verification.

The complete llvm-reduce suite changes from 178 passed / 27 unsupported on
baseline to **180 passed / 27 unsupported / zero failures** with the candidate;
the two added tests account for the increase. The 27 unsupported tests are not
claimed covered, and this tools-only validation does not imply another full
CodeGen-suite run. Baseline suite-log SHA256:
`952e83bdf5d4708af10482dc38db4a5bd66aefb53afa8446390b7c548ffae471`;
candidate suite-log SHA256:
`fed682355b149755cc735bdfdb467de95c788318217b5925c3a976f321fd3499`.

**Approved: ready to post as a MOS backport of existing upstream commit
b1ba3d515a02, unposted.** This approval neither restores the rejected new-LLVM
submission nor approves the historical shared-context parallel algorithm.
The separate [backport review](0060-backport-review.md) independently confirms
the exact upstream extraction and current LLVM behavior.
