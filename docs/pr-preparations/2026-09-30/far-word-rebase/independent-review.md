# Independent review of the rebased far-word series

September 30, 2026. **Do not file this series yet.** The bounded-loop proof (0069, patch 8), the speed-only word-load admission (0070, patches 12–14), the new copy-cost repair (patch 9), the quad spill prerequisite (patch 10) and the generic identity-copy repair (patch 11) held up under source reading and adversarial probes. The rebase itself is faithful. The far/ABI prerequisites that the optimizations depend on (patch 4) are not ready: this review reproduced **three silent-miscompile paths** and **three assertion or verifier failures** from valid IR. The prerequisites also define the same TableGen names as open PR #594 with the opposite allocation decision. Each blocking finding below has a concrete input and a suggested repair.

## Exact scope

| Item | Identity |
|---|---|
| Destination base | `06bc967d2668c7c11c4d6eb43a6aed1f99ad258b` (upstream main after #570, #586, #605) |
| Candidate | `77dc044c39bb303d8984ed5d9eb08c3a3455cad8`, tree `d2d7b62b06a19b362d2b54a210c62e9137c9b5bb`, 14 commits |
| Patch 11 (generic LLVM) | `3d82e37332eccac1d315b7e1c879e780cade7d0e` |
| Source checkout (read only) | `build/far-word-rebase/source` in the main worktree |

Frozen tools, all LLVM 24.0.0git optimized builds with assertions:

```text
d7fde754bb0222b40b514c97e7baa2eb98ca18d626ae8fea49d12f6add17f9cf  build/far-word-rebase/candidate/llc          (patches 1-14)
b86894b7802be95f07c017c5e1766a92bdfb7b25e8c6ae59617cc05c4bb61b9b  build/far-word-rebase/pre0070/llc            (patches 1-11)
7ea5a1f9bbcc785cb14fd8d6a45d5daa3c94d62faa1e9ffc301661423b367e38  build/far-word-rebase/candidate/FileCheck    (same binary in pre0070/)
35a1afd96ad2af273aabbcbc98b3be2beb028babcdb86ff959a679f8c535659e  build/far-word-upstream/allocation-baseline/llc   (preserved copy-cost failure)
b2bdf8352d141d816d04415d83c028aff7373a57719391d4a0fbcc95b90cd5cf  build/far-word-upstream/candidate-without0028/llc (26d7c2c1 series without patch 11)
a2fb79789e8cd6e3c21db4ac952d99a51df4c7ea1771c7d95d03cbb001b45e5f  build/far-word-upstream/pre0070/llc        (26d7c2c1 series, pre-0070)
9b024b51ae3dfbcef8d5aee9d74aaed4d99887e4bec920bb4edf3b342afa6bbe  build/far-word-upstream/candidate/llc      (26d7c2c1 series, candidate)
```

The last four binaries were used only as before-state controls. No LLVM build was performed. Every `llc` invocation ran under `ulimit -c 0`. Commands, exit codes, first diagnostics and all 20 probe inputs are embedded in [the review evidence](evidence/independent-review.json). Scratch files are in `build/far-word-rebase/review/` of the main worktree.

## Coordinator results verified

| Coordinator claim | Independent result |
|---|---|
| Rebased commits carry the same added/removed lines as the 26d7c2c1 series | Confirmed for all 14 patches. The diff bodies of `git format-patch` output compare equal, as sorted `+`/`-` lines, against `upstream-series/patches/`. |
| Candidate MOS CodeGen+MC plus two X86 tests: 163 pass, one unsupported | Confirmed. The mini-runner executes every RUN line with the frozen tools, giving 162 + 1 (`MC/MOS/eflags-ir.ll`) pass and `getchar-regression.ll` unsupported. |
| Pre-0070 fails exactly three files | Confirmed: `far-word-policy.mir`, `far-word-index-integration.ll`, `far-word-index-boundaries.mir`. |
| Sensitivity: 6 positives pass, 228/228 mutations rejected | Confirmed by rerunning `check-sensitivity.py` against the candidate (FileCheck from the frozen directory). It mutates only `far-loop-range.mir` (156) and `far-word-policy.mir` (72). The two new boundary files are not mutation-tested. |
| Legalizer outputs identical to the 26d7c2c1 build apart from ModuleID | Spot-confirmed: four far test files × two modes, 8/8 identical after removing ModuleID/source_filename. |

The coordinator's `candidate-suite.json` records its commands under container paths `/work/build/0029-cross-target-build/bin/llc` and `/work/build/register-exhaustion-src`. On the host, `build/register-exhaustion-src` is an **unrelated dirty checkout** at `742d554b`, and `build/0029-cross-target-build/bin/llc` hashes to `149af7e3…`, not `d7fde754…`. The result reproduces, but the record names the wrong compiler (finding N6).

## Contracts checked

1. **Rebase interactions.**
   - **#605 (experimental SSA register allocation):** its three passes are stubs that `report_fatal_error` on every function, including plain 6502 code. Far/native inputs, therefore, fail loudly under `-mos-experimental-regalloc` for the same reason as any input. No guard or test is needed now. The PR should state that Imag32 quads, `Ac16/Xc16/Yc16` and REP/SEP insertion (`addPreEmitPass`, shared by both pipelines) are not yet described to that allocator.
   - **#570 (G_MERGE_VALUES salvage):** no interaction with patch 11 (disjoint files and phases). Far-pointer merges with `dbg.value` compile verifier-clean at O0–O3. The one debug-info failure found (B4) is reproduced unchanged on the 26d7c2c1-based pre-0070 and candidate binaries, which predate #570, so it is a series defect rather than a rebase interaction.
   - **#586 (BRK signature):** `.td`-only, with no overlap.
2. **Open PR overlap** is covered in B7 and N9.
3. **Patches 4–14:** covered in the findings and the "Held up under review" section.
4. **Listed open contracts:**

| Contract | What the source does | Safe? | What the PR must say |
|---|---|---|---|
| Far-pointer ABI register exhaustion | `CC_MOS` offers `RL1..RL3`. It then falls through to `CCIfPtr`, which can hand an i32 far pointer a 16-bit `RSn`. | **No.** Assertion or verifier failure in assertions builds. Release behaviour is unverified and may be silent (B1). | The fix is to add a stack fallback. |
| Far memory intrinsic lengths > 0xFFFF | Truncated to 16 bits without a check. The IRTranslator also truncates mixed-address-space lengths. | **No: silent** (B2). | Fix it, then state the supported length domain. |
| A8 far-pointer limitation | Without `+mos-a16`, most pointer arithmetic, ptr/int conversion and returns fail with "unable to legalize". Plain runtime loads and stores compile. | Loud on 65816. **Silent on non-65816 CPUs** (B3). | List the A8 and CPU restrictions. |
| Debugger representation of far quads | `RL` has no DWARF number. LLVM composes a location from subregisters. | **No: malformed** (B5). | Fix, or drop locations and say so. |
| Hidden `-mos-far-word-index` switch | `off\|speed\|all`. `all` bypasses optsize/minsize/**optnone** and O0/O1. | Correct, but see N5. | Recommend removing it, or keeping it hidden with `all` still honouring optnone. |

## Independent execution highlights

- **0070 admission matrix** (`probes/w.ll`, 17 functions × {A16, XY16} × O0–O3, legalizer output). At O2/O3 the word pseudo is admitted for word start 254, volatile, 16-bit index masked to 254, scaled index ≤ 254, and mixed groups (byte at +2 / word at 0, max 252). It is rejected for start 255, atomic, escaping address, call between address and access, word-store sibling, sign-extended index, negative displacement, `optsize`, `minsize` and `optnone`. At O0/O1 no runtime word fold occurs. The only word pseudos there come from the pre-existing constant-displacement window (0062), as intended.
- **Y8 contract under XY16.** `LDIndirLongIdx16` has only `MLow`. `requiredXWidth` forces X8 for any memory access that reads X/Y (`MOSInsertREPSEP.cpp`, catch-all near line 267). The word load therefore never runs with a 16-bit Y.
- **Patch 9 before/after.** `native-index-copy-cost.mir` aborts with `Unexpected physical register copy` on the preserved failing compiler (`35a1afd9…`) and passes FileCheck on the candidate.
- **Patch 11 before/after.** `virtregrewriter-x86-undef-high-byte-result.mir` fails ("Using an undefined physical register") without patch 11 and passes with it. `virtregrewriter-x86-copy-contracts.mir` passes both with and without patch 11 (N2).
- **Patch 10.** Three far quads live across calls, plus a recursive variant, compile verifier-clean in A16/XY16 at O0–O3, optsize, and `-mos-far-word-index=all`.
- **Broad sweep.** Every `CodeGen/MOS/*.ll` input plus the probes ran under A16/XY16 at O0/O2/O3: 426 invocations. The non-zero results are the probe findings below, plus `vector-scalarize.ll` (A16 O2/O3: `instruction is not legal: G_IMPLICIT_DEF s16`, N7) and `inline-asm-zp-csr.ll` at O0, which also fails without `+mos-a16`.
- **clang-format.** Running `clang-format-diff.py` on `git diff -U0 06bc967d2668 HEAD` with the container's `/opt/llvm-mos/bin/clang-format` (built from this base) reports 613 lines to rewrite (N3).

## Findings

| # | Severity | Summary | Location |
|---|---|---|---|
| B1 | Blocking | Far-pointer argument exhaustion assigns a 16-bit RS pair to a far pointer | `MOSCallingConv.td:63` |
| B2 | Blocking | Far memset/memcpy/memmove lengths above 65535 silently truncated or deleted | `MOSLegalizerInfo.cpp:3484-3490` |
| B3 | Blocking | Far accesses on non-65816 CPUs emit `[dp]` opcodes that decode as other instructions | `MOSLegalizerInfo.cpp:2772` |
| B4 | Blocking | Far runtime-index fold leaves a dangling DBG_VALUE; `-g -O2` fails the machine verifier | `MOSLegalizerInfo.cpp:3026` |
| B5 | Blocking | Far quad DWARF location is a malformed 46-bit composite | `MOSRegisterInfo.td:213-227`; `DwarfExpression.cpp:200` |
| B6 | Blocking | s32→s16 `G_TRUNC` reaches `selectTrunc` and asserts (far→near cast, ptrtoint+trunc) | `MOSInstructionSelector.cpp:2318` |
| B7 | Blocking (process) | Imag32 names collide with open #594, which makes RL non-allocatable over a linker contiguity concern | `MOSRegisterInfo.td:28-33,213-227,267` |
| N1 | Nonblocking | Patch 9 is correct and complete relative to lowering. X16↔Y16 and A16↔anything COPYs are neither lowered nor costed. | `MOSRegisterInfo.cpp:1388`, `MOSInstrInfo.cpp:692-704` |
| N2 | Nonblocking | Patch 11 is sound. Its diff is mostly a function extraction, and one of its two tests is characterization only. | `VirtRegMap.cpp:621-795` |
| N3 | Nonblocking | 613 clang-format lines in patches 1, 4, 5, 6 and 10; unsorted include | `MOSTargetMachine.cpp:45` et al. |
| N4 | Nonblocking | 52 added lib comment lines carry #320/#321/"Increment"/"Phase" history tags, plus a broken "(Native widths: )" | e.g. `MOSLegalizerInfo.cpp:2284`, `MOSRegisterInfo.td:269` |
| N5 | Nonblocking | Two new hidden options; `all` bypasses optnone | `MOSLegalizerInfo.cpp:2842,2948` |
| N6 | Nonblocking | Coordinator suite record names container-alias paths that resolve to a different host compiler | `build/far-word-rebase/candidate-suite.json` |
| N7 | Nonblocking | Loud unsupported shapes: far `null`, far select at O0, A16 vector insert | see below |
| N8 | Nonblocking | Sensitivity runner does not cover the new boundary tests | `check-sensitivity.py` |
| N9 | Nonblocking | Hunk-level overlaps with #593, #601 and #585 need a rebase check | see below |

### B1 — far-pointer ABI exhaustion (blocking)

`CCIfPtrAddrSpace<2, CCAssignToReg<[RL1, RL2, RL3]>>` has no fallback of its own. When every quad has an allocated alias, the i32 far pointer reaches `CCIfPtr<CCAssignToReg<[RS1..RS7]>>` and takes any free 16-bit pair. Four far arguments (`probes/abi4.ll`) put the fourth in `$rs1`. Results:

- with `-verify-machineinstrs`: `Copy Instruction is illegal with mismatching sizes` (`%3:_(p2) = COPY $rs1`, Def Size 32, Src Size 16);
- without it: `RegisterBankInfo.cpp:569` assertion `Meaningful bits not covered by the mapping`;
- in all three feature modes.

Release-build behaviour was not observable with assertion-only tools; a silent miscompile cannot be excluded. The fallback to the stack does work when no RS pair is free: `probes/abimix.ll` (seven near pointers, then a far pointer) passes four bytes on the soft stack in both caller and callee. **Fix:** add `CCIfPtrAddrSpace<2, CCAssignToStack<4, 1>>` immediately after the RL rule. Add caller and callee tests for four far pointers, and for near/far interleavings that exhaust the quads while leaving RS1 free.

### B2 — memory intrinsic lengths (blocking, silent)

`createFarMemLibcall` truncates any length wider than 16 bits (`buildTrunc(LLT::scalar(16), Len)`, line 3488) with no range check. `probes/farmemlen.ll` at A16 O2:

- `memset.p2.i32(…, 70000)` calls `__memset_far` with **4464** (`ldx #112`, `ldy #17`);
- a runtime i32 length for `memcpy.p2.p2` is passed with its high 16 bits dropped;
- `memcpy.p2.p2(…, 65537)` copies **1** byte;
- `memmove.p2.p0(…, 65536)` is **deleted entirely**. The IRTranslator has already emitted `G_TRUNC` to s16 for the mixed-address-space call, giving length 0.

**Fix:** reject, or split into ≤0xFFFF chunks, any constant length above 0xFFFF. For runtime lengths, admit only lengths whose known-bits maximum is ≤0xFFFF; otherwise fail loudly or call a 32-bit-length entry. Handle the mixed-address-space truncation before `G_MEMMOVE` reaches the legalizer, or reject it. Add regressions for 65535, 65536, 65537 and 70000, and for an unbounded runtime i32 length.

### B3 — far accesses on non-65816 CPUs (blocking, silent)

The `p2:32:8` data layout is triple-wide, and `tryFarIndirectAddressing` (line 2772) does not check `hasW65816()`. Selection does not enforce the `[HasW65816]` predicates on `LDIndirLong`/`STIndirLong`. A runtime far byte load (`probes/rt.ll`) compiles without error at O2 with the verifier on, emitting opcode `$A7`:

| CPU | `llvm-objdump` of the emitted load |
|---|---|
| mos6502 | `a7` `<unknown>` (NMOS LAX zp) |
| mos65c02 | `a7` `<unknown>` |
| mosspc700 | `a7 00` `sbc a,[$0+x]` |
| moshuc6280 | `a7 00` `smb $2,$2000` |

Far global loads on those CPUs fail loudly ("unable to legalize G_MERGE_VALUES"). Runtime loads and stores do not. **Fix:** make every address-space-2 memory operation illegal, with a clear error, unless the subtarget has 65816 long addressing. Also consider rejecting `addrspace(2)` in call lowering for those CPUs. Add a `-mcpu=mos6502` negative test.

### B4 — dangling debug use after the far runtime-index fold (blocking)

When `tryFarRuntimeIndexFold` makes the pointer add dead, `salvageDebugInfo` cannot express `base + zext(off)` and leaves the `DBG_VALUE` naming the dead vreg. DetectDeadLanes then marks it `undef`, and the verifier reports `Generic virtual register use cannot be undef` (`DBG_VALUE undef %5:any, …, !"p"`). Reproducers:

- `probes/dbgbyte.ll`: byte fold, patch 4. Fails on candidate, pre0070 and both 26d7c2c1-based binaries.
- `probes/dbg.ll`: word fold, patch 12. Fails on the candidate only; passes with `-mos-far-word-index=off`.

Without the verifier the location degrades to `$noreg` (seen with `-print-after-all`), so emitted code is unaffected. It still violates this project's `-verify-machineinstrs` bar, and any verifying bot would flag it. **Fix:** when all non-debug uses of the pointer add have folded, set its remaining `DBG_VALUE` operands to `$noreg` before it is erased. A better alternative is to salvage with a `DBG_VALUE_LIST` over base and offset. Add a `-g` regression for both byte and word folds.

### B5 — malformed far-quad DWARF (blocking for any debugger claim)

`llvm-dwarfdump` of `probes/dbg.ll` at O0 shows `DW_AT_location (DW_OP_regx RS2, DW_OP_piece 0x2, DW_OP_bit_piece 0x7 0x0, DW_OP_regx RS3, DW_OP_piece 0x2, DW_OP_bit_piece 0x7 0x0)`. That describes 46 bits for a 32-bit pointer and places the high word at bit 23, so a debugger shows the wrong far pointer. The cause: `RL` has `DwarfNumbers = [-1]`, so `DwarfExpression::addMachineReg` composes pieces from subregisters. Its `CurPos = Offset + Size` (line 200) is updated for every subregister, including the 1-bit `…LSB` subregisters of each byte, and moves backwards. The 1-bit subregister at offset 8 leaves `CurPos = 9`, producing a 7-bit "no DWARF register" gap before `RS3`. **Fix:** either define a DWARF range for 32-bit imaginary registers in the MOS DWARF specification, coordinated with #594 and the merged #608, or suppress quad locations until it exists. The generic `CurPos` bookkeeping should also become monotonic (`max`); that change belongs upstream in LLVM. Add a dwarfdump test.

### B6 — `selectTrunc` assertion on s32→s16 (blocking)

Under `+mos-a16`, `addrspacecast ptr addrspace(2) → ptr` fails at O0 and O2, and `ptrtoint` to i32 followed by `trunc` to i16 fails at O2. Both reach `selectTrunc`, which asserts `getType(From) == LLT::scalar(16)` (`MOSInstructionSelector.cpp:2318`). In a release build the assertion is compiled out and the selector would rewrite an s32 trunc as if it were s16→s1; behaviour was not observed. **Fix:** legalize s32→s16 `G_TRUNC` (unmerge and take the low pair) before selection, or select it explicitly. Add both IR shapes as tests.

### B7 — reconcile with #594 before filing (blocking, process)

#594 (mlund, draft, head `7b80f7e1`) adds the same `sublo16`/`subhi16`, `MOSImagReg32`, `MaxImag32Regs`, `RL#I`, `MOSReg32Class` and `Imag32` definitions. It also adds matching `copyPhysRegImpl`, `copyCost`, `MOSMCInstLower` and zero-page CSR changes. The two designs differ in two ways:

- **Allocation.** #594 is deliberately `isAllocatable = false`, because "linker scripts may place adjacent RS registers apart". It plans an SDK linker contract before allowing allocation. This series allocates RL, puts RL1..RL3 in the **default** calling convention for every MOS CPU, and reads `__rcN..N+2` through `[dp]` with no contiguity check.
- **Register numbers.** #594 derives numbers from `Imag16RegsOffset + MaxImag16Regs`. That formula predates #608; on today's base it would give `0x30080+K`, which is not a DWARF number defined by the specification. This series uses an arbitrary `0x600` that `DwarfNumbers = [-1]` then overrides.

**Recommendation:** adopt #594's definitions verbatim, rebase patch 4 on #594 (or carry #594 unchanged as patch 4a with its author's credit), and keep `DwarfNumbers = [-1]` until B5's numbering decision. Then gate allocatability and the RL calling convention on 65816 plus an explicit contiguity contract. Do not file a competing definition. **This needs a maintainer and author conversation (mlund, mysterymath) that this review cannot settle.**

### Nonblocking findings

- **N1 (patch 9).** `LDX/LDY/STX/STY dp` with a 16-bit index is 2 bytes and 4 cycles at DL = 0. The four arms match exactly the four edges `copyPhysRegImpl` lowers. `copyCost` is reached only for equal-width candidates, and every 16-bit class is a singleton, so no other Imag16 edge can arise unless a lowering is added. X16↔Y16 (`TXY`/`TYX` in X16) and any A16 COPY remain unlowered and uncosted; both paths would stop at `llvm_unreachable`. No input reached them: the 426-invocation sweep and the `probes/xyphi.ll` index-PHI shapes are clean. Consider an explicit diagnostic.
- **N2 (patch 11).** The change is conservative. It computes `CopyHasUndefLanes` only when the source has subranges, and only turns an identity COPY into `KILL`, a shape the rewriter already emits for `undef` sources. That cannot remove a definition or add a use. However:
  - Most of the 299-line diff moves the loop body into `rewriteInstruction`. A minimal patch would compute the flag in place and pass it to the existing `handleIdentityCopy`.
  - `virtregrewriter-x86-copy-contracts.mir` passes without the patch, so it is characterization, not a regression test. Only the undef-high-byte file guards the change.
  - A generic `VirtRegMap.cpp` change also needs an llvm-project upstream path or an explicit llvm-mos carry decision.
- **N3 (format).** Non-conforming lines by commit (blame of the reported hunks, counts include hunk context):

  | Commit | Lines |
  |---|---:|
  | Native foundation (patch 1) | about 1,300 |
  | Patch 4 | 113 |
  | Patch 6 | 65 |
  | Patch 10 | 29 |
  | Patch 5 | 21 |

  Patches 8, 9, 11 and 12 are clean. Patch 12 reformats patch 4 lines (`allUsesAreFoldableFarAccesses`, `tryFarRuntimeIndexFold`), which adds review noise; fold that formatting into patch 4. `#include "MOSInsertREPSEP.h"` is out of order after `MOSInternalize.h`. The comment at `MOSTargetMachine.cpp:348` exceeds 80 columns.
- **N4 (comments, AGENTS.md).** 50 added lines in patch 1 and 11 in patch 4 contain development tags. Examples: `#321 Phase 2 inc 1:`, `#321 Increment 1b:`, "The original Increment-1a behavior", "increment 2's", `B1:`, "our new 16-bit X/Y pseudos". A mechanical substitution left `(Native widths: )` at `MOSLegalizerInfo.cpp:2284`. `dev/check-comment-history.py` does not catch these; the rule does.
- **N5 (options).** Upstream MOS has three `cl::opt`s; the series adds `-mos-far-loop-range` and `-mos-far-word-index`. The loop proof has no size or speed trade-off, so drop `-mos-far-loop-range`. If the word policy switch stays for experiments, keep it hidden and make `all` still honour `optnone`. The default already equals the measured policy.
- **N6 (evidence).** Record host directories and binary hashes in suite records. The container aliases resolve on the host to a different checkout (`742d554b`, dirty) and a different `llc` (`149af7e3…`).
- **N7 (loud limitations to list in the PR).** Under `+mos-a16`:
  - `icmp eq ptr addrspace(2) %p, null` fails ("unable to legalize `G_CONSTANT p2 0`");
  - far `select` fails at O0;
  - `vector-scalarize.ll` fails at O2/O3 with `G_IMPLICIT_DEF s16` not legal. This is a foundation (patch 1) gap; the same file passes without `+mos-a16`.

  All of these are LLVM ERRORs, not silent.
- **N8 (tests).** `far-word-index-boundaries.mir` and `far-loop-range-boundaries.mir` use exact `{{ }}` boundaries, but the sensitivity runner does not mutate them. The integration test checks only one bounded shape. No test covers a word-store sibling rejecting a group, or XY16 X8 forcing around the word pseudo.
- **N9 (other open PRs).**
  - **#593** adds an assertion in `MOSMCInstLower::lowerOperand` that an Imag16 operand never names a CSR pair relocated to the ZP stack. Patch 4 records `CSRZPOffsets` for the quad and both halves, so the invariant should hold. Both edit the same hunk and the `collectCandidates` loop in `MOSZeroPageAlloc.cpp`, so rerun the CSR/far tests after rebasing.
  - **#601** adds CFI to `MOSFrameLowering.cpp` prologue/epilogue and `prologepilog.mir`. Patches 1 and 10 edit both, a textual overlap. Far quads have no DWARF number (B5), so #601's callee-saved CFI covers them only through their byte CSRs.
  - **#603** fixes `STAbsIdx`. The series adds no caller with the same operand mistake; no conflict.
  - **#585** introduces `G_ASHRE` in byte narrowing. The series keeps native s16 `G_ASHR` un-narrowed under A16, so the paths are disjoint apart from textual overlap in the legalizer, selector, `.td` files and `legalizer.mir`.

### Held up under review

- **0069 (patch 8) is sound.** The PHI must be in the access block, with exactly one constant entry and one self backedge. `Next = Reg + 1` in s8. The terminator pair must branch on the **Z** output (operand 4) of `G_SBC Next, End, carry=1`, and `Start < End` holds in the same 8-bit domain. Header values are then exactly `Start..End-1`, and the exit value is `End-1`, so the bound holds at every use of the PHI result. `G_ZEXT` preserves the bound. `G_SHL` refines it only when `Input << Amount` fits the operation width. Rejection falls back to known bits, which cannot admit a wider range.
- **0070 (patch 12) admission is as described.** Only plain `G_LOAD` s16 with a precise 2-byte memory size is admitted. Atomic accesses, escapes, stores of the pointer, non-access users, word stores and calls between address and access are all rejected. A word anywhere in the group forces the Y8 limit, and `Wide` becomes false. The index is `zext/trunc(Off) + ConstOffset` with `ConstOffset ≤ MaxEnd`, so the s8 add cannot wrap. The 24-bit `[dp],y` carry into the next bank is the same carry the unfolded `lda [dp]` word read would perform.
- **Visit order.** A byte sibling legalized after a folded word may take Y16 in XY16. That is individually correct and not a soundness issue.
- **Compile-time cost.** `mayBecomeCall` is a pressure heuristic, not a correctness guard. The whole-function call scan runs once per candidate access; its compile-time cost is still unmeasured.
- **Patch 10.** It splits quads into two Imag16 halves for dynamic slots and four bytes for static slots. It uses fresh vregs with an `undef` first-lane def on reloads and a `KILL` before split stores. All spill probes are verifier-clean.

## Limits

- All tools are assertion builds. For B1 and B6 this review cannot say whether a release build fails loudly or miscompiles.
- No emulator run was made; the separate 58-configuration MAME/bsnes replay was not touched.
- Patches 1–3 were probed through the sweep but not re-reviewed line by line; their earlier review is in `docs/pr-preparations/2026-09-28/0065/independent-review.md`.
- The MOS DWARF specification page returned HTTP 403, so its current register-range table was not consulted.
- GitHub PR contents were read on September 30, 2026 (read only) and may change.
- No commits, stashes or source edits were made. Nothing was written under `build/far-word-rebase/{runtime,build}`.

## Attribution

Independent review, probes and this record: **Claude Code 2.1.285**, running as a T4 subagent of the coordinating session with no inherited conversation context. Model **`claude-opus-5-5` (Opus 5.5)**. Reasoning effort is **unknown**: it is not exposed to the agent process. The harness-provided parent session reference is [session_01HAKZG571yi9zqmAeWQZVtk](https://claude.ai/code/session_01HAKZG571yi9zqmAeWQZVtk); this subagent's own session ID is not visible to it. Earlier authors, extractors and reviewers keep the credits recorded in the patch messages and the September 28 packet.

**Coordinator correction to the attribution above:** the subagent transcript metadata records Claude Code **2.1.283** (not 2.1.285), agent type `t4-opus-high`, model `claude-opus-5-5` and **high** reasoning effort; its session is the coordinating session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`.
