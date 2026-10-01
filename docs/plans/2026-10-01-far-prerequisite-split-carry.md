# Carry the far-prerequisite repairs into the #320 split commits

Status: first carry implemented (2026‑10‑01; verification below). Third round implemented 2026‑10‑01 ([Third round](#third-round-n17n22-and-the-older-open-items); verification at the end). Second round implemented 2026‑10‑01 (verification below): #594 option 1, B8, B9 and N10–N16 from the [second independent review](../pr-preparations/2026-09-30/far-word-rebase/independent-review-2.md); see [Second round](#second-round-594-option-1-b8-b9-n10n16). This plan carries the downstream B1–B4 repairs ([far-prerequisite plan](2026-09-30-far-prerequisite-defects.md), commit `664b877a`), the B6 extraction gap, and the independent review's N3/N4 cleanups into the #320 commits of the [#320/#321 split](2026-09-30-split-320-321-series.md). It then re-verifies the split and the far-word 0069/0070 packet for a second independent review. It belongs to the two TODO items "Prepare native-word speed policy 0070 for upstream review" and "Prepare the bounded Farblit range proof for upstream review", whose shared blocker is these defects. The user approved the work on 2026‑09‑30 ("go ahead on 0069 and 0070 when it doesn't conflict with work in-flight"); the conflicting pressure-set change landed on origin as `b145a581`.

Attribution: Claude Code 2.1.285 (t4-opus-high agent), model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort; session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F).

No visible surface: compiler commits, tests and review packets; no mockups.

## Where each repair and finding lands

A fix goes into the commit that introduces the code it corrects, with its test, as the split's invariants require. The split's [#320 reviewer map](../pr-preparations/2026-09-30/split-320-321/REVIEWER-MAP-320.md#where-the-independent-reviews-findings-land) said findings would become follow-up commits; that is superseded here by folding each fix into its commit.

| Item | Change | Lands in | Test (added or extended) |
|---|---|---|---|
| B1 | Ungated `CCIfPtrAddrSpace<2, CCAssignToStack<4, 1>>` directly after the RL1–RL3 rule | #320‑2 (`MOSCallingConv.td`) | `far-ptr-arg-exhaustion.ll` (added) |
| B3, loads and stores | `rejectFarAccessWithoutLong`: diagnose far G_LOAD/G_ZEXTLOAD/G_SEXTLOAD/G_STORE without 65816 long addressing | #320‑2 (`legalizeCustom`) | `far-access-non-65816.ll` (added, load/store functions) |
| B6 | `Pat<(i16 (trunc Imag32:$s)), (EXTRACT_SUBREG Imag32:$s, sublo16)>` under `HasAccum16` | #320‑2 (`MOSInstrLogical.td`) | `far-ptr-trunc.ll` (added) |
| B2 | Keep the 16-bit `__mem*_far` call only for provably 16-bit lengths; otherwise call `__mem*_far32` with a `uint32_t` length | #320‑3 (`createFarMemLibcall`) | `far-memop-length.ll` (added) |
| B3, memory intrinsics | Diagnose a far memop without 65816 long addressing at the top of `legalizeMemOp` | #320‑3 | `far-access-non-65816.ll` (extended with `set_far`) |
| B4 | Drop the locations of debug uses of the dead pointer adds once the last access folds | #320‑4 (`tryFarRuntimeIndexFold`) | `far-index-fold-debug.ll` (added, byte fold) |
| B4, word fold | No code change: the 0070 word fold reuses `tryFarRuntimeIndexFold` | far-word patch 12 | `far-index-fold-debug.ll` (extended with the word fold) |
| N3 | `clang-format-diff` on each #320 commit's own C++ hunks | #320‑1..4 | none (no codegen change) |
| N4 | Remove the history tags (`#321 Phase 2 inc …`, `#321 Ph2`) from #320‑4's comments, and drop #320‑1's stray rewrite of #321‑1's "Native widths:" comment to "#321 Increment 1b:" | #320‑1, #320‑4 | none |

Far-word patch 12 reformats #320‑4 lines. Once #320‑4 is formatted, those hunks disappear from patch 12, which the review asked for (N3). Far-word patches 5–14 are otherwise carried unchanged.

Not in scope: B5 (far-quad DWARF numbering) and B7 (#594), both below; N3 in the #321 commits and far-word patches 5, 6 and 10; N4 in the #321 commits (including the broken "(Native widths: )" comment in #321‑8); N1, N2, N5, N7–N9. The #321 commits are not modified, so the near-index and 0065 packets keep their commits.

The SDK side of B2 (`__memset_far32`, `__memcpy_far32`, `__memmove_far32` in `platforms/snes/mem-far.c`) is downstream already. The #320‑3 message states the runtime contract the compiler now calls.

## #594 reconciliation (B7)

#594 was read with the public GitHub API on 2026‑10‑01: open draft, head `7b80f7e18768`, last updated 2026‑08‑19, no comments or reviews. It is unchanged since the independent review. It defines the same `sublo16`, `subhi16`, `MOSImagReg32`, `MaxImag32Regs`, `RL#I`, `MOSReg32Class` and `Imag32` as #320‑1, with two incompatible choices:

- **Allocation.** #594 marks `Imag32` `isAllocatable = false` and makes allocation wait for an llvm-mos-sdk linker contract that identifies platforms with contiguous four-byte imaginary registers. #320‑1/‑2 allocate RL and put RL1–RL3 in the default calling convention for every MOS CPU.
- **Numbering.** #594 numbers RL from `Imag16RegsOffset + MaxImag16Regs`; #320‑1 uses `0x600` and `DwarfNumbers = [-1]`. The numbering is also B5's open DWARF decision.

Aligning #320‑1 means choosing one of these, and each option changes the far ABI or depends on #594's author:

1. Carry #594 unchanged as #320‑1a (author credit) and add allocation in #320‑1b now, gated on 65816. This contradicts #594's stated plan.
2. Wait for #594's SDK contiguity contract, then gate RL allocation and the RL calling convention on it. The far series stays blocked until then.
3. Keep far pointers out of RL allocation by passing them on the stack or in `A`/`X`/`Y`. This is an ABI redesign.

That is a design choice between incompatible options that needs the user, and #594's author and maintainers. It is escalated rather than decided here.

**Decision (user, 2026‑10‑01): option 1, with a coordination comment on #594 before filing.** Carry #594 unchanged as #320‑1a with mlund's authorship, and adopt its numbering (`Imag16RegsOffset + MaxImag16Regs`, which settles B5). Add RL allocation and the RL calling convention as #320‑1b. Read on 2026‑10‑01, #594's own roadmap puts an SDK linker contract for contiguous four-byte imaginary registers first (`mlund/llvm-mos-sdk:imag32-contract`) and allocation after it. The [drafted comment](../pr-preparations/2026-10-01/594-comment.md) therefore proposes gating allocation on that contract, with the SNES platform declaring it, and keeps a 65816-only gate as the fallback. It also proposes agreeing on one far address space with mlund's planned MEGA65 `[ptr],z` work. Implementation starts after the second independent review of the carried #320 commits, and follows mlund's reply if one arrives first. #320‑1 is carried with its register definitions unchanged; only N3/N4 are applied to it. Every repair above is independent of that choice.

## Method

1. Branch `split-320-321-carry` from the second MC commit `25c40909b44a` in `build/split-320-321/source`. The old head `1a616f08ea67` stays on branch `split-320-321`.
2. For each #320 commit: cherry-pick it, apply its repairs and tests, run `clang-format-diff` on its own C++ hunks, and amend it with a message that states the repaired contract. Record the carry as `spec/carry-320.diff` (old end tree to new end tree), the messages as `spec/msgs-carry/`, and the commits themselves as `patches-320/`. (Deviation: the plan first proposed one diff per commit; the patches already give each commit's exact content, so a per-commit carry diff would only restate them.) `spec/carry-finalize.sh` re-creates the final commits from the gated run commits with the final messages and fixed committer data; the trees do not change.
3. Rebase far-word patches 5–14 on the new #320‑4 with `git am -3`. Resolve patch 12's formatting hunks by keeping only its semantic change, and add the word-fold part of `far-index-fold-debug.ll` to patch 12.
4. Per-commit gates on `build/split-320-321/build`, with every heavy build under `flock -w 14400 build/.heavy-build.lock` at `-j3`. Each commit is built with assertions and must pass MOS CodeGen+MC and introduce no new MOS warnings. Each added test must be red on its parent and on the unrepaired version of its commit, and green on its own and every later commit. Default-mode hashes of the fixed input set are compared with the parent.
5. Update the end-tree invariant: the new #320 end tree equals the old one (`1a616f08ea67`, which is the pressure-set reference `fa1928c8b9ca` plus 13 added tests) plus `spec/carry-320.diff`, and no other path differs.
6. Regenerate `patches-320/`, the far-word packet's `patches-split/` and `split-series.json`, and check whether the near-index and 0065 packets changed. Rerun the far-word suites with its pre-0070 (patch 11) and candidate (patch 14) `llc`.
7. Compile the far-word packet's 58 frozen post-LTO IR configurations with the new pre-0070 and candidate `llc` and compare object hashes with the previous split's candidate and with the September 28 results. Rerun MAME, bsnes and the Farblit measurement only if an object differs.
8. Lesson 4 (gate by optimization level): for any repair that changes code for inputs that compiled before, measure it at O0, O1, O2, O3, Os and Oz on its own objective. B2 is the only candidate: it changes a far memop call only when the length cannot be proven to fit 16 bits. That is a correctness repair, so it must not be level-gated.
9. Records: append the split-series carry as `additional_runs` (same input on the unrepaired and repaired split commits) to each B1–B4 record; the baselines stay unchanged. Update the split and far-word READMEs, the #320 reviewer map and the far-word status.

## Verification

1. The split `#320` end tree equals the old end tree plus `spec/carry-320.diff`, which touches only the files named in the table above; `patches-mc/` then `patches-320/` applied to the #321 end reproduce every commit tree.

    ```text
    $ git diff --stat 1a616f08ea67 59d98c37ab77 | tail -1      # = spec/carry-320.diff
     16 files changed, 533 insertions(+), 96 deletions(-)
    $ git diff --name-status fa1928c8b9ca 59d98c37ab77 | cut -f1 | sort | uniq -c   # vs the pressure-set reference
         18 A      (13 earlier split tests + far-access-non-65816.ll, far-index-fold-debug.ll,
                    far-memop-length.ll, far-ptr-arg-exhaustion.ll, far-ptr-trunc.ll)
         11 M      MOSCallingConv.td MOSInstrInfo.h MOSInstrLogical.td MOSInstructionSelector.cpp
                   MOSLegalizerInfo.cpp MOSLegalizerInfo.h MOSMCInstLower.cpp MOSRegisterInfo.cpp
                   MOSRegisterInfo.td MOSZeroPageAlloc.cpp TargetDataLayout.cpp
    $ (patches-321 + patches-mc + patches-320 applied with git apply --cached to 06bc967d2668)
    22 patches applied in order to 06bc967d2668; every intermediate tree matches: True ; final tree c80a2ee108f3
    ```

    PASS. The five files beyond the repairs (`MOSMCInstLower.cpp`, `MOSZeroPageAlloc.cpp`, `MOSRegisterInfo.cpp`, `TargetDataLayout.cpp`, `MOSInstrInfo.h`) carry only N3 formatting of #320‑1 lines and the rewritten `AddressSpace` comment.

2. Every #320 commit builds with assertions, passes MOS CodeGen+MC, and adds no MOS warnings.

    ```text
    $ cut -f1,3,6,7 evidence/carry/stages.tsv
    label     final_commit  mos_warnings  lit
    c-320-01  abfb29168fca  0             PASS=161 UNSUPPORTED=1
    c-320-02  3576ad627b5b  0             PASS=166 UNSUPPORTED=1
    c-320-03  eab4edb9dc32  0             PASS=168 UNSUPPORTED=1
    c-320-04  59d98c37ab77  0             PASS=170 UNSUPPORTED=1
    c-fw-11   79bce92541e8  0             PASS=175 UNSUPPORTED=1
    c-fw-14   a5515aab9219  0             PASS=179 UNSUPPORTED=1
    ```

    PASS. The gates ran on the run commits; `carry-finalize.sh` then replaced only messages and committer data, and every tree is unchanged (`evidence/carry/message-update.tsv`).

3. Every added or extended test is red on its parent and on the unrepaired commit, and green on its own and every later commit, including far-word patches 5–14.

    ```text
    $ bash spec/carry-red-green.sh evidence/carry-red-green.tsv     (41 probes)
         14 red FAIL      e.g. far-ptr-arg-exhaustion.ll on unrepaired p-320-02: "Found 1 machine code errors"
                               far-ptr-trunc.ll on p-320-02: Assertion `Builder.getMRI()->getType(From) == LLT::scalar(16)'
                               far-memop-length.ll on p-320-03: CHECK: expected string not found
                               far-index-fold-debug.ll (word) on c-fw-11: CHECK: expected string not found
         27 green PASS    on c-320-02..04, c-fw-11, c-fw-14 as applicable
    ```

    PASS. The far-word green runs cover patch 11 (`c-fw-11`) and patch 14 (`c-fw-14`); patches 12–14 share one `llc` because 13 and 14 change only tests. Patches 5–10 were not built individually, as in the packet's earlier evidence.

4. The default-mode comparison of each #320 commit with its parent matches the previous split's result (commits 1, 3 and 4 identical; commit 2 identical for compiling inputs), except where a repair adds a diagnostic on non-65816 CPUs.

    ```text
    c-320-01 vs p-320-00: mos6502 89 identical, 1 asm differ; mosw65816 89 identical, 1 asm differ
      (trapguard aborts on both with the same LoopStrengthReduce assertion; the hashed first stderr line
       starts with the llc file name, "p-320-00:" vs "c-320-01:")
    c-320-02 vs c-320-01: 85 identical, 5 asm differ in each mode (the five far inputs; all fail before and after)
      mos6502: farbank, k_mandel_far, lzss-gallery now stop at "far (address space 2) memory access requires
      65816 long addressing"; far_fnptr, farptrcmp-natural unchanged; mosw65816 errors unchanged
    c-320-03 vs c-320-02: 90 identical in both modes
    c-320-04 vs c-320-03: 90 identical in both modes
    ```

    PASS.

5. The far-word packet round-trips (all intermediate trees match) and its suites pass on pre-0070 and candidate. The 58 frozen configurations produce identical objects, or the changed ones pass MAME and bsnes with their measurements recorded.

    ```text
    $ python3 spec/packet-record.py c-far-word 06bc967d2668 pkt-c-far-word 77dc044c39bb docs/.../far-word-rebase
    c-far-word: 32 patches, trees match: True, final f3aba3593673, delta vs original: 31 paths, PASS=179 UNSUPPORTED=1
    $ carry-replay-objects.py (carried c-fw-11/14) ; (pre-carry o-fw-11/14, o-fw-14 = fd38e1c16b78, the packet's recorded llc)
    carried vs pre-carry (pressure-set) split: 58 identical, 0 different
    pre-carry vs Sep 28 recorded: differ 34
    $ runtime.py --work build/split-320-321/runtime-carry
    rc=0   58 results; all repeat_equal: True ; bsnes==mame==expected: True
    ```

    PASS. The carry changes no replay object. The 34 objects that differ from September 28 come from the pressure-set change and had not been run; all 58 now pass on both emulators.

6. `python3 dev/check-defect-evidence.py --worktree` passes with the four records extended.

    ```text
    $ bash spec/carry-record-replay.sh /home/will/llvm-mos-65816-splitcarry
    b1-unrepaired-320-02: exit_code=134   b1-carried-320-02: exit_code=0   b1-carried-fw-14: exit_code=0
    b2-unrepaired-320-03: exit_code=1     b2-carried-320-03: exit_code=0   b2-carried-fw-14: exit_code=0
    b3-unrepaired-320-02: exit_code=1     b3-carried-320-02: exit_code=0   b3-carried-fw-14: exit_code=0
    b4-unrepaired-320-04: exit_code=134   b4-carried-320-04: exit_code=0   b4-carried-fw-14: exit_code=0
    b4-word-unrepaired-fw-old: exit_code=134   b4-word-carried-fw-14: exit_code=0
    $ python3 dev/check-defect-evidence.py --worktree
    Defect evidence: PASS (32 records, worktree)
    ```

    PASS.

## Measurements by optimization level (lesson 4)

B2 is the only repair that changes code for inputs that compiled before. `carry-b2-levels.sh p-320-03 c-320-03` compiles `far-memop-length.ll` and `far-memset.ll` as written and with every function forced to `optsize` (Os) or `optsize minsize` (Oz), in A16 and XY16:

| Level | Callees changed (both modes) | `.text` of far-memop-length.ll | far-memset.ll |
|---|---|---|---|
| O0 | the same eight functions move to `…_far32` | 111 → 160 bytes | unchanged (31 bytes) |
| O1, O2, O3, Os, Oz | the same eight | 92 → 141 bytes | unchanged |

The eight are the constant lengths 65536, 65537 and 70000, the unbounded runtime lengths and the loop idiom's scaled length. `set_65535`, `set_zext`, `mov_masked` and `set_i16` keep the 16-bit entries at every level, so known-bits proves the bound even at O0. The decision does not depend on the level, and a length truncation must not be traded for size, so B2 is not level-gated. The far-word 58-configuration replay shows 0070's own gate unchanged: Os and Oz identical, O2 and O3 faster.

## Second round: #594 option 1, B8, B9, N10–N16

Added 2026‑10‑01 after the [second independent review](../pr-preparations/2026-09-30/far-word-rebase/independent-review-2.md) (origin `590f9616`) and the user's #594 decision (origin `9125c46d`). The reviewed series stays on branch `split-320-321-carry` as the reference. The new series is on branch `split-320-321-r2` (`ad7b2f4239a2`..`d19b7155d3c6`), and the far-word packet on `pkt-r2-far-word` (top `c275e191de52`).

### New #320 layout

| Commit | Content | Tests |
|---|---|---|
| #320‑1a (3 commits) | #594 as posted by mlund: "Avoid newlines in inline asm operands", "Accumulate composite zero-page CSR benefit", "Add nonallocatable 32-bit imaginary registers". Authorship and messages kept. | #594's own |
| #320‑1b | The far address space (`p2:32:8`, `AS_Far`), Imag32 bank membership and reservation, and RL allocation behind one predicate, `MOSSubtarget::hasAllocatableImag32()`, which is the 65816 until an SDK contiguity contract exists. Also the RL calling convention with B1's stack fallback, the `i32` calling-convention type for far pointers, and incoming 32-bit values. Whatever old #320‑1 adds beyond #594. | allocation-gate test (replaces #594's `imag32-nonalloc.mir` expectation on the 65816); the call-lowering half of `far-ptr-arg-exhaustion.ll` |
| #320‑1c | Imag32 quad spills: far-word patch 10 moved here (B9) | patch 10's `prologepilog.mir` cases |
| #320‑2 | As before, plus the B8 helper at the absolute-long fold, the N12 fix, N13, N14 and N15 | the full-compile half of `far-ptr-arg-exhaustion.ll`; the B9 reproducer (four far pointers live across a call); `-g` absolute-long test |
| #320‑3 | As before, plus N10 | mixed-space cases in `far-memop-length.ll` |
| #320‑4 | As before; the B4 walk is replaced by the shared B8 helper at both fold paths | `-g` displacement-window test and store case |
| far-word 5 | plus the B8 helper at the absolute-indexed fold | `-g` absolute-indexed test |
| far-word 6–9, 11–14 | unchanged except context; patch 10 is gone | — |

### #594 carry: one mechanical adaptation, one escalation

#594 does not apply unchanged to the split. Upstream #571 (`26d7c2c1eebf`, in `06bc967d2668`) renumbered the imaginary registers after #594 was written: RC is at `0x20000`, RS at `0x30000`, and `MOSReg` takes a 32-bit number. The two unrelated #594 commits apply with identical changed lines. The register commit needs two things:

- a context-only conflict resolution, because both sides add a branch at the same place in `copyPhysRegImpl`, and #594's hunk context holds the old numbering `defvar`s;
- one token: `class MOSImagReg32<bits<16> num …>` becomes `bits<32>`. `0x30080` does not fit 16 bits, which is the same widening #571 applied to `MOSReg`.

Each changed line is otherwise identical to `7b80f7e18768`, and a rebase note records the adaptation below mlund's message.

**ESCALATE (numbering).** On the current base, #594's formula `Imag16RegsOffset + MaxImag16Regs` gives RL numbers `0x30080 + K`. The comments in `MOSRegisterInfo.td` (from #571) read the MOS DWARF specification as a type byte: `0x02` RC and `0x03` RS. So `0x30080` sits in the RS type range, as RS index 128, which does not exist. The lldb MOS plugin (`MOSImaginaryRegisters`) recognizes only the RC and RS banks. A far pointer's location is therefore a well-formed single `DW_OP_regx`, and B5's malformed composite is gone, but no current consumer can resolve it. The alternative, a new type such as `0x04` at `0x40000`, needs the specification's maintainers, and the specification page itself returns HTTP 403. The series implements the user's literal choice, the formula (one `defvar`), and the numbering question goes back to the user and the #594 comment.

### B8 design

Chosen: one static helper in `MOSLegalizerInfo.cpp`, `dropDeadFarAddressDebugUses(MRI, Register Ptr)`. It is called after a far fold erases an access, with that access's pointer. It climbs from the pointer through `G_PTR_ADD` bases while the whole tree of adds on a register is dead. A tree is dead when every non-debug user is a `G_PTR_ADD` based on that register whose own tree is dead. The helper then sets every `DBG_VALUE` of the dead tree to `$noreg`. It stops at the first register with a live user (the base the new pseudo reads), so it never drops a live location. It replaces B4's walk, which is the case where the climb starts from a constant add on the runtime add.

Rejected: a generic salvage change in `CodeGenCommonISel.cpp`, which would drop unsalvageable operands and salvage `G_PTR_ADD` as `DW_OP_plus_uconst`. It would also repair the near shapes, but it is an llvm-project change and must not ride inside #320. It is proposed in the upstream record instead.

Sites: #320‑2 `tryFarAbsoluteAddressing`, #320‑4 both paths of `tryFarIndirectIndexedAddressing` (runtime fold and window), and far-word patch 5 `tryFarAbsoluteIndexedAddressing`. Records: the four new far sites share B4's mechanism, but B4's closure was for the runtime-index site only, so they are a distinct defect instance under the evidence rules. They go in a new record, `mos-far-fold-dangling-dbg-sites`, related to `mos-far-index-fold-dangling-dbg`. The near shapes on upstream `06bc967d2668` get their own record, `mos-legalizer-fold-dangling-dbg-upstream`, which is not fixed here.

### Nonblocking items

- **N10:** state the LangRef argument in #320‑3's message and pin the IRTranslator narrowing: `memcpy.p2.p0` with 40000 keeps its length, and 70000 is narrowed.
- **N12:** at #320‑2 a far memop that is not inlined fails to legalize, loudly, instead of calling the near runtime; #320‑3 replaces that with the far runtime call.
- **N13:** on CPUs without long addressing, far loads and stores are made custom for every type, so the diagnostic fires once per access, before any narrowing.
- **N14:** fix the message and the comment. With the allocation gate, far pointer values on other CPUs cannot be allocated, so the text states the actual contract, which is measured.
- **N15:** remove the history tags from #320's tests, and the trailing blank line.
- **N16:** list far `atomicrmw`/`cmpxchg` with the loud unsupported far shapes in the #320 reviewer map.
- **N11:** add an llvm-mos-sdk companion entry for the six far runtime entries to `docs/upstream-contribution-status.md`, as future/blocked.

### What changed while implementing (deviations from the layout above)

1. **#594 has a defect as posted.** With #594 applied, any function with a call that passes stack arguments (a variadic call is enough) aborts in the register coalescer with "Invalid global physical register", in every MOS mode, including default mos6502 code. The cause: RL over a reserved RS pair is not reserved, and LLVM counts a register unit as reserved only when all its super-registers are.
    - It reproduces with #594 alone on upstream `06bc967d2668` (`u594`), and adding only the reservation rule fixes it (`u594-resv`).
    - #594 stays unchanged, and a separate commit (#320‑1b) carries the fix, with a test reduced by llvm-reduce.
    - [Record](../defects/mos-imag32-reserved-pair-units.json); suggested additions to the #594 comment are in [594-comment.md](../pr-preparations/2026-10-01/594-comment.md).
    - The layout is therefore 1a (#594 ×3), 1b (reservation fix), 1c (far address space, allocation gate, calling convention), 1d (spills).
2. **The allocation gate is an empty allocation order, not reservation.** Reserving every quad on other CPUs moved call arguments on mos6502, because `MOSValueAssigner` marks every reserved register and its aliases as used. Twelve MOS tests failed. `Imag32` now has an alternative order that is empty unless `hasAllocatableImag32()`. A strong copy hint outside the order is filtered, because the allocator asserts on it.
3. **Far pointer values need the 65816.** With quads unallocatable elsewhere, a far pointer argument on mos6502 goes to the stack and fails to legalize loudly (the A8 limit). The B3 test no longer claims that passing a far pointer stays legal there.
4. **Far-word patch 9 now precedes patch 5.** Patch 5's own XY16 test asserts in `copyCost` without patch 9's copy costs. This predates the carry; patch 5 had never been built on its own.
5. **B8 sections that need +mos-a16:** the runtime-offset sections of `far-fold-debug.ll` skip plain mosw65816, where the zero-extended s32 offset fails to legalize (A8).

### Second-round verification

1. #320‑1a's changed lines equal #594's except the recorded `bits<32>`; #320‑1b..#320‑4 and the far-word packet round-trip from `06bc967d2668`.

    ```text
    diff of changed lines, 7b80f7e18768 vs the carried commit:
    < +class MOSImagReg32<bits<16> num, string name, list<Register> subregs>
    > +class MOSImagReg32<bits<32> num, string name, list<Register> subregs>
    (a1e2fa5ce11a and d3d346169104: identical changed lines)
    27 patches applied in order to 06bc967d2668; every intermediate tree matches: True; final tree 11f4fcadc11a
    r2-far-word: 36 patches, trees match: True, final 3ca03f1da90c, delta vs original: 48 paths, PASS=187 UNSUPPORTED=1
    ```

    PASS.

2. Every commit builds with assertions, passes MOS CodeGen+MC and adds no MOS warnings.

    ```text
    label       lit                     mos_warnings
    r2-320-1a1  PASS=160 UNSUPPORTED=1  0
    r2-320-1a2  PASS=161 UNSUPPORTED=1  0
    r2-320-1a3  PASS=166 UNSUPPORTED=1  0
    r2-320-1b   PASS=167 UNSUPPORTED=1  0
    r2-320-1c   PASS=168 UNSUPPORTED=1  0
    r2-320-1d   PASS=168 UNSUPPORTED=1  0
    r2-320-2    PASS=174 UNSUPPORTED=1  0
    r2-320-3    PASS=176 UNSUPPORTED=1  0
    r2-320-4    PASS=178 UNSUPPORTED=1  0
    r2-fw-9     PASS=179 UNSUPPORTED=1  0
    r2-fw-5     PASS=180 UNSUPPORTED=1  0     (first order: FAIL far-global-long-x.ll; fixed by moving patch 9)
    r2-fw-6..8  PASS=181, 182, 183          0
    r2-fw-11    PASS=183 UNSUPPORTED=1  0
    r2-fw-14    PASS=187 UNSUPPORTED=1  0
    ```

    PASS.

3. Every added or extended test is red on its parent (and on the reviewed commit where one exists) and green after, including B8's probes and B9's reproducer.

    ```text
    $ bash spec/r2-red-green.sh evidence/r2-red-green.tsv        (170 probes)
        143 green PASS
         27 red FAIL
    $ bash spec/r2-b8-sweep.sh ... c-320-04 c-fw-14 r2-320-4 r2-fw-14
    field, store1, gfield, gidx, argoff, chain, word, qonly: no "cannot be undef" on r2-320-4 or r2-fw-14
    spill (B9): assert=4 on c-320-04 -> none on r2; remaining failures on r2 are plain-mosw65816
      "unable to legalize G_MERGE_VALUES s32" (A8)
    nidx, ngfield, ngidx, nearfield (upstream near shapes): still fail everywhere, as recorded
    ```

    PASS.

4. Default-mode identity per commit versus its parent, with #594's own default-mode effects listed.

    ```text
    r2-320-1a1 vs MC top, 1a2 vs 1a1, 1c vs 1b, 1d vs 1c, 3 vs 2, 4 vs 3, fw-9 vs 4: identical
      (each lists only the trapguard harness artifact: same assertion, hashed stderr line starts with the llc file name)
    r2-320-1a3 vs 1a2: 4 inputs change (vaprintf compiled, now aborts; cgrade_sim, sodo_sim, sodo abort) -- #594's defect
    r2-320-1b vs 1a2: identical (trapguard artifact only)
    r2-320-2 vs 1d: the five far inputs fail with a different error, as in the first round
    ```

    PASS.

5. The far-word packet suites pass; the 58 replay objects are compared with the reviewed packet, and the emulators rerun if any object differs.

    ```text
    second round vs reviewed carried packet: 58 identical, 0 different []
    ```

    PASS: no object changed, so the reviewed packet's MAME/bsnes results stand and the emulators were not rerun.

6. `check-defect-evidence.py` passes with the new records.

    ```text
    $ python3 dev/check-defect-evidence.py --worktree
    Defect evidence: PASS (35 records, worktree)
    ```

    PASS. New records: mos-imag32-reserved-pair-units (fixed in the series), mos-far-fold-dangling-dbg-sites (confirmed; split repair recorded as additional runs; downstream 0002 not repaired), mos-legalizer-fold-dangling-dbg-upstream (confirmed; not fixed; generic salvage fallback proposed). mos-far-index-fold-dangling-dbg gains the second-round runs.

### Second-round measurements by optimization level (lesson 4)

`default-hashes-levels.sh` compiled the fixed default-mode input set (90 inputs, mos6502 and plain mosw65816) with the MC top's `llc` (`p-320-00`) and the new #320‑4 (`r2-320-4`). Levels were O0, O1, O2 and O3, plus O2 with every function forced to `optsize` (Os) or `optsize minsize` (Oz). Errors are hashed from their message, not the `llc` file name.

```text
O0..Oz, mos6502 and mosw65816: 85 of 90 inputs identical (assembly and object) at every level;
the 5 that differ are the far corpus inputs, which fail at the MC top and after #320 (rc 1 -> 1),
with a different error message.
```

The whole #320 group, #594 included, changes no default-mode code at any level. For far code, the second-round changes are debug-location drops (B8) and error paths (N12, N13, the allocation gate). The 58 far-word replay objects (Os, Oz, O2, O3) are byte-identical to the reviewed packet's. No repair in this round changes code for an input that compiled before, so no level gate is needed. [Levels](../pr-preparations/2026-09-30/split-320-321/evidence/r2/levels.txt).

## Third round: N17–N22 and the older open items

Added 2026‑10‑01 after the [third independent review](../pr-preparations/2026-09-30/far-word-rebase/independent-review-3.md) (origin `74e24d94`). The second-round series stays on `split-320-321-r2` and `pkt-r2-far-word` as the reference. The third-round series goes on `split-320-321-r3` (whole split, from `06bc967d2668`) and `pkt-r3-far-word`.

### Prior-work reconciliation for N17

N17 is not a new defect. It is the project's own open upstream PR [#584](https://github.com/llvm-mos/llvm-mos/pull/584) ("[MOS] Fix non-GPR immediate loads in mos-late-opt", `wbniv:mos-late-opt-nongpr-ldimm` @ `7f4c37de6219`, posted 2026‑07‑31, two review rounds), carried downstream as `patches/llvm-mos/0003-late-opt-nongpr-ldimm-dest.patch` and first found in the [138 LZSS far-decode investigation](2026-07-27-138-lzss-far-decode-mos-late-optimization-crash.md). The #320‑2 hunk is #584's guard without its comment change. Upstream `main` is still `06bc967d2668` (fetched 2026‑10‑01), so the defect is live upstream. No `docs/defects/*.json` record exists for it.

Consequences:

- The series carries #584's net diff as its own commit, unchanged (#584's squash, the way upstream merges), with #584's `late-opt-spc700.mir` as the regression test. It goes directly after the MC commits, before #320‑1a, and #320‑2 loses the hunk. The same commit applies to `06bc967d2668` alone, which is how #584 lands.
- The upstream entry is #584's existing row in `docs/upstream-contribution-status.md`, not a new one: a second PR would duplicate a posted fix. The row gains the new evidence (15 of 51 in-tree inputs crash at `mosspc700 -O2` on current `main`) and a prepared, unposted comment for #584 that reports it.
- A new canonical record, `mos-late-opt-nongpr-ldimm-null-tracker.json`, against `06bc967d2668`, with the `prior_work` audit pointing at #584, `0003` and the 138 plan. Its original attribution is the 2026‑07‑31 discovery. It stays `confirmed` until #584 merges.

### Where each item lands

| Item | Fix | Commit |
|---|---|---|
| N17 | #584 as its own commit; hunk removed from #320‑2; default-mode identity over all 14 MOS CPUs | new commit after MC, #320‑2 |
| N19 | 1b message and test comment name both signatures: the reduced test's `Use not jointly dominated by defs.` and `variadic-call.ll`'s `Invalid global physical register` | #320‑1b |
| N20 | on CPUs without the 65816, a far pointer value (stored, passed, returned, converted, compared, selected) stops with a purpose-written error naming the function, before the generic `G_UNMERGE_VALUES` failure; far accesses keep the per-access diagnostic. 1c's message states that `addrspace(2)` changes meaning on every MOS CPU (32-bit `p2`; upstream treated it as a 16-bit pointer). | #320‑2, #320‑1c message |
| N21 | see the soundness check below; salvage only where sound | #320‑2 helper |
| N22 | close `mos-far-fold-dangling-dbg-sites` as fixed with the same-input red and green runs | record |
| N1 | explicit error instead of `llvm_unreachable` for the unlowered X16↔Y16 and A16 copy edges | far-word patch 9 |
| N2 | patch 11 reduced to computing the flag in place and passing it to `handleIdentityCopy`; the X86 characterization test is labelled as such in its header | far-word patch 11 |
| N3 | clang-format of packet patches 5 and 6; of all 16 #321 commits (their own lines) | patches 5, 6; #321 1–16 |
| N4 | history tags removed from #321 lib and test comments, and the broken `(Native widths: )` fixed | #321 1–16 |
| N5 | `-mos-far-loop-range` removed (its `OFF` runs go; the parent-red runs show the same contrast); `-mos-far-word-index=all` honours `optnone` | far-word patches 8, 12, 13 |
| N7 | PR/README list of loud unsupported far shapes: far `null` compare, far `select` at O0, `vector-scalarize.ll` under `+mos-a16` at O2/O3, far `atomicrmw`/`cmpxchg`, far values on plain mosw65816 (A8) that reach memory | docs |
| N8 | sensitivity runner extended to the two boundary tests; tests for a word-store sibling rejecting a group and for XY16 X8 forcing around the word pseudo | far-word patch 13, `check-sensitivity.py` |
| N9 | fetch #593, #601 and #585 read-only, apply each onto the new far-word top, report conflicts, build, run the MOS suites | evidence |
| N18 | not touched (mlund; the comment body is the orchestrator's) | — |

#321 N3/N4 are comment and whitespace changes only. Each #321 commit is rebuilt as its old tree plus tag rewrites plus clang-format over the cumulative `06bc967d2668` diff, so no later commit has to re-resolve a reformatted line by hand. The near-index and 0065 packets are regenerated on the new #321 and gated; their compiled output must be identical.

### N21 soundness check (done)

The concern was the DWARF address size: if it were 2 bytes, `DW_OP_bregN k` or `DW_OP_deref; DW_OP_plus_uconst k` would read a far pointer as a 2-byte generic value and drop the bank byte. Measured instead of assumed: a `-g` object from `r2-320-4` has a compile unit with `addr_size = 0x04`, and a far pointer argument described as `DBG_VALUE %p, DW_OP_plus_uconst 1` is emitted as `DW_OP_bregx RL1+1`. The generic stack is 4 bytes, so the addition covers all 32 bits and keeps a carry into the bank byte. Salvage is sound and is implemented. It stays `$noreg` in three shapes, each for a stated reason: an address below a runtime offset (it would need a variadic `DBG_VALUE_LIST`), a tree that starts at a folded global or constant (no register holds the address after the fold), and indirect or list `DBG_VALUE`s.

### Gates (as in round two, widened)

Per-commit build with assertions and MOS CodeGen+MC; red on parent and green on own and later commits for every added test; patch round trips from `06bc967d2668`; packet regeneration; default-mode identity per commit at O2 over all 14 MOS CPUs, and at O0–O3/Os/Oz on the endpoints; per-level measurement for any codegen change on previously compiling inputs; the far-word replay objects compared, with the emulator replay only if they change.

### What changed while implementing (third round)

1. **N17 is #584.** See the reconciliation above. The commit is #584's squash with its title and description, a carry note and its original co-author line; `late-opt-spc700.mir` is its test. On upstream `06bc967d2668` plus #584 alone, the 31 `mosspc700` inputs of the 90-input set that crash at `-O2` compile, and nothing else changes on any of the 14 MOS CPUs.
2. **N21 lands in #320‑4, not #320‑2.** At #320‑2 every fold that erases adds starts from a global or constant base, so nothing is salvageable there; #320‑4 adds the first folds with a live base. The `offset-field` case of `far-fold-debug.ll` turned out salvageable too: the displacement window keeps the runtime add live, so `q = (base + n) + 1` becomes that add plus 1.
3. **N20 stops with a fatal usage error.** A far pointer value on a CPU without the 65816 has no representation the legalizer could substitute, so "diagnose and continue" is not possible without erasing whole use chains. The error names the function and replaces the generic `unable to legalize … G_UNMERGE_VALUES`; far accesses keep their per-access diagnostic, and a far pointer that only addresses diagnosed accesses is erased with them, so `far-access-non-65816.ll`'s access cases are unchanged. The rules cover every generic opcode that can carry a `p2` operand (constants, globals, casts, compares, selects, pointer adds and masks, PHIs, freezes, and loads and stores of a far value through a near pointer).
4. **N1 is a fatal error with crash diagnostics.** An unlowered native copy is an internal invariant violation, not a user error, so `report_fatal_error` keeps the backtrace; the test uses `not --crash`. It lands in far-word patch 9, which owns the native-index copy edges, so #321 stays a comment and whitespace change.
5. **N8 found an unchecked opcode.** Extending the sensitivity runner to every far access opcode in every function (not only the one word load) showed that `far-word-policy.mir`'s four mixed-order functions never pinned the byte sibling's opcode. Patch 13 now pins it. The runner covers the two boundary tests as well.
6. **N3/N4 in #321.** Every #321 commit was rebuilt from its old tree with the tag rewrites and clang-format over the cumulative `06bc967d2668` diff, so no later commit had to be re-resolved by hand. A comment-stripping token comparison shows each rebuilt commit differs from the old one only in comments and whitespace, plus one sorted `#include` in `MOSTargetMachine.cpp`. The leading "Native widths:" topic labels that an earlier mechanical relabel left were kept where they read as a label; the four places where it broke a sentence were fixed.
7. **Packets on #321.** The near-index recovery patch replays without conflicts; 0065's second patch conflicts with reformatted context in `MOSLegalizerInfo.cpp` and was resolved to the patch's own text. Token comparisons without comments show both packets' trees equal their previous ones except the sorted include.
8. **Two more upstream defects from the all-CPU gate.** #321‑11's opcode-keyed frame-index displacement also fixes an upstream HuC6280 miscompile: `HuCMemcpy`'s destination frame index is followed by the block length, which upstream adds as the destination offset ([record](../defects/mos-huc-blockmove-frameindex-offset.json)). Upstream SPC700 also aborts in the greedy allocator ("Target hint is outside allocation order") on 18 corpus inputs; 1c's strong-hint filter changes that failure but does not fix it ([record](../defects/mos-spc700-hint-outside-order.json)). The #321‑3, #321‑11, #321‑12, 1b, 1c, #320‑2 and far-word patch 11 messages now state their effects on every CPU. **ESCALATE:** whether the HuC6280 part of #321‑11 should be split out and offered upstream on its own, as #584 is, is a series-shape decision for the user.
9. **Patch 11's default-mode cost predates this round.** On the all-CPU set it changes three corpus inputs (+8 bytes in examples_snes_bf-vm on 12 CPUs), identically to the reviewed patch 11; the minimal form changes nothing.

### Third-round verification

1. Every commit builds with assertions and passes MOS CodeGen+MC with no new MOS warnings.

    ```text
    evidence/r3-stages.tsv: 38 rows (37 series commits + #584 alone on 06bc967d2668), gate_rc=0, hash_rc=0 for all
    PASS counts: 584-up 133; #321 134 135 137 139 140 141 142 144 146 148 149 151 152 153 154 155; MC 158 160; #584 161;
    #320 161 162 167 168 169 169 175 177 179; far-word 181 182 183 184 185 185 186 190 190 (1 unsupported each)
    ```

    PASS.

2. Default mode on all 14 MOS CPUs (`llc -mcpu=help`), each commit against its parent at O2.

    ```text
    identical: #321-1,2,4..10,14,15; MC x2; 1a-i, 1a-ii, 1d, #320-3, #320-4; far-word 9,5,6,7,8,12,13,14
    #321-3: 68 object-only (mos65el02, mosw65816)    #321-11: 2 (moshuc6280)    #321-12: 199 (13 CPUs)
    #321-13: 28 (mosw65816)    #321-16: 3 (mosw65816)    #584: 31 fail->pass (mosspc700)
    1a-iii: 21 pass->fail + 35 error changes; 1b: the exact reverse (1a-ii == 1b on all 1,260)
    1c: 18 error changes (mosspc700)    #320-2: 69 error changes (5 far inputs x 13 CPUs, 4 on mossweet16)
    far-word 11: 14 output changes (bf-vm x12, metaball, sodo), as the reviewed patch 11
    p-321-16 vs r3-321-16: same=1260; r2-fw-14 vs r3-fw-14: outputs identical, 26 error changes (N20)
    ```

    PASS. Each effect is stated in its commit message ([table](../pr-preparations/2026-09-30/split-320-321/evidence/r3/default-all-cpus.txt)).

3. Red/green for every added or changed test.

    ```text
         15 green char PASS
        215 green reg PASS
          7 red char PASS
         35 red reg FAIL
    unexpected: (none)
    ```

    PASS ([table](../pr-preparations/2026-09-30/split-320-321/evidence/r3/red-green.tsv)).

4. Round trips and packet regeneration.

    ```text
    split: patches=28 matching=28 mismatching=0 final_tree=b3afcaba1e4a top=36d569637f6a
    r3-near-index: 17 patches, trees match: True, final 0537ca4478fb, PASS=157 UNSUPPORTED=1
    r3-0065: 18 patches, trees match: True, final 04a530515ead, PASS=158 UNSUPPORTED=1
    r3-far-word: 37 patches, trees match: True, final 5d6924925790, PASS=190 UNSUPPORTED=1
    ```

    PASS.

5. Replay objects, sensitivity, N9.

    ```text
    58 configurations: 58 identical to the recorded objects, 0 different, 0 failed
    {'positive_passes': 8, 'functions': 111, 'functions_without_far_opcode': 0, 'mutations': 262, 'rejected': 262}
    n9-601 rc=1 FAIL=2 PASS=189 UNSUPPORTED=1   (a16-byte-store.ll, a16-indirect-byte-store.ll: .cfi_startproc after the label)
    n9-585 rc=0 PASS=191 UNSUPPORTED=1
    n9-593 rc=0 PASS=191 UNSUPPORTED=1
    ```

    PASS, with #601's two test updates noted for whichever lands second.

6. Records.

    ```text
    $ python3 dev/check-defect-evidence.py --worktree
    Defect evidence: PASS (39 records, worktree)
    ```

    PASS. New: mos-late-opt-nongpr-ldimm (confirmed upstream, fix is #584), mos-huc-blockmove-frameindex-offset (confirmed upstream), mos-spc700-hint-outside-order (confirmed upstream). Closed as fixed: mos-far-fold-dangling-dbg-sites.

Levels (lesson 4): no third-round change alters the output of an input that compiled before. The third-round tops produce the same assembly and objects as the second-round tops on every CPU, so the second round's per-level table still applies.


## Fourth round: sequence #584, test the HuC6280 split

Added 2026‑10‑01 after two user decisions (Will, relayed by the coordinator): "sequence, don't carry" for #584, and split the HuC6280 fix out of #321‑11 only if that can be done cleanly.

### A. #584 is sequenced, not carried

- Drop the #584 commit (`5f5d76c59fa9`) from the series; rebase the 18 commits above it onto the MC top `ed90d3aabae7` (`git rebase --onto`, no conflicts expected: nothing later touches `MOSLateOptimization.cpp` since round three). The 16 #321 and 2 MC commits keep their hashes.
- Risk to check before anything else: round one put the guard into #320‑2 because the 138 LZSS far decode crashed the same way on the 65816 (an LDImm into an imaginary register). If any far test segfaults in "MOS Late Optimizations" without #584, the far series depends on #584 and the decision goes back to the user.
- Re-gate the 18 commits as in round three: per-commit build and suites, all-14-CPU default tables, red/green, round trips, packet exports (far-word, near-index, 0065), and the 58 replay objects (expected identical).
- Messages: "Default-mode effect" lines say the fixed set is identical on every MOS CPU except mosspc700, which crashes in MOS Late Optimizations before and after; fixed separately by #584. Commits with their own default-mode effects keep them and add that clause. The README, maps, tracker, record and the prepared #584 comment say #584 is filed first and not carried.

### B. HuC6280: clean split or not

The five criteria from the decision are checked in order: the HuC6280 effect separable from #321‑11's own change; a patch that applies to `06bc967d2668` alone; a HuC6280 test red there and green with the patch; no other change on any of the 14 CPUs; #321‑11 correct and passing without it. The hunk in question is #321‑11's opcode-keyed displacement rule in `eliminateFrameIndex`, which #321‑11 introduced for its own `CmpBrAbsImm16`. The probe for the last criterion is #321‑11 rebuilt without that hunk.

### Fourth-round results

**A. #584.** The risk check passed: without the guard, the series top passes MOS CodeGen+MC (189 pass, 1 unsupported; only `late-opt-spc700.mir` is gone), the 58 replay objects are byte-identical to the reviewed packet's, and the LZSS gallery IR fails the same way in the virtual register rewriter at `+mos-a16` O2 with and without the guard. No far code on the 65816 reaches the crash.

**B. HuC6280: not clean, kept in #321‑11.** The HuC6280 change is not a separate hunk. It is #321‑11's opcode-keyed displacement rule in `eliminateFrameIndex`, the same rule #321‑11 needs for its own `CmpBrAbsImm16`. Reverting the rule at #321‑11 (probe `r4-probe-321-11-nohunk`) still passes the lit suites (149, 1 unsupported), because no lit test covers the rule. But it miscompiles native compares on stack values under `+mos-a16`: in the corpus input `examples_65816_a16frameidx`, every compare operand moves (`.Lcheck_sstk` → `+4`, `+2` → `+3`, `+4` → `+2`, …; [probe](../pr-preparations/2026-09-30/split-320-321/evidence/r4/huc-split-probe.txt)). So criteria 1 and 5 fail. A standalone upstream patch would be possible, as either the same rule or a narrower `HuCMemcpy` exclusion. But #321‑11 would then depend on it being upstream first, and the series could not keep HuC6280 behaviour unchanged without reintroducing the miscompile on purpose. The fix stays in #321‑11, whose message states the HuC6280 effect (round three). One gap remains: #321‑11 has no lit test for the rule; the record's reduced HuC6280 test or an `a16frameidx`-style MIR test would cover it.

### Fourth-round verification

1. Per commit, the 18 rebuilt commits (`r4-*` labels; final hashes in [final-map](../pr-preparations/2026-09-30/split-320-321/evidence/r4/final-map.tsv)).

    ```text
    #320 160 161 166 167 168 168 174 176 178; far-word 180 181 182 183 184 184 185 189 189 (1 unsupported each), gate_rc=0, hash_rc=0, 0 MOS warnings
    ```

    PASS.

2. All 14 CPUs: every step as in round three; against round three only mosspc700 differs.

    ```text
    r3-fw-14 vs r4-fw-14: mosspc700 same=58 pass->fail=31 error=1 (k_mandel_far: far diagnostics, then the late-opt crash); every other CPU same=90
    mosspc700 late-opt crashes: MC top 31, series top 32 (the same 31 + k_mandel_far)
    ```

    PASS as expected by the decision; k_mandel_far stated in #320‑2's message.

3. Red/green: 33 red runs fail, 211 green runs pass, 7 characterization runs pass on their parents, nothing unexpected. PASS.
4. Round trips: split 27 of 27 patches, final tree `dcbb521f6fa6`; far-word 36 patches, final tree `87b0a138ccfe`. PASS.
5. Replay objects 58 of 58 identical; sensitivity 262 of 262. PASS.
6. HuC6280 split probe: #321‑11 without the rule passes lit (149, 1 unsupported) and miscompiles `examples_65816_a16frameidx`. Outcome: not clean; kept in #321‑11.
