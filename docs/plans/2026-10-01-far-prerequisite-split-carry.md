# Carry the far-prerequisite repairs into the #320 split commits

Status: implemented (2026‑10‑01); all six verification steps pass, and the #594/B5 decision is escalated. Verification output is recorded below. This plan carries the downstream B1–B4 repairs ([far-prerequisite plan](2026-09-30-far-prerequisite-defects.md), commit `664b877a`), the B6 extraction gap, and the independent review's N3/N4 cleanups into the #320 commits of the [#320/#321 split](2026-09-30-split-320-321-series.md). It then re-verifies the split and the far-word 0069/0070 packet for a second independent review. It belongs to the two TODO items "Prepare native-word speed policy 0070 for upstream review" and "Prepare the bounded Farblit range proof for upstream review", whose shared blocker is these defects. The user approved the work on 2026‑09‑30 ("go ahead on 0069 and 0070 when it doesn't conflict with work in-flight"); the conflicting pressure-set change landed on origin as `b145a581`.

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

That is a design choice between incompatible options that needs the user, and #594's author and maintainers. It is escalated rather than decided here. #320‑1 is carried with its register definitions unchanged; only N3/N4 are applied to it. Every repair above is independent of that choice.

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
