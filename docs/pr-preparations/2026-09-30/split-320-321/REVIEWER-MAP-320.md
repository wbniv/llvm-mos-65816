# Reviewer map: #320 far data as a 4‑commit series

This series replaces the monolithic patch `11044c53d5fc` ("Extract far data addressing and bounded runtime indexing", 23 files, +1,660). It applies after the #321 series ([map](REVIEWER-MAP-321.md)) and the two unchanged MC address-width commits ([`patches-mc/`](patches-mc/)), and ends at the tree of `11044c53d5fc` plus the [native-width pressure-set change](../../../plans/2026-09-30-native-register-pressure-sets.md#application) (reference commit `fa1928c8b9ca`, tree `deb630c2d43f`), plus the test files the split adds under `llvm/test/` (twelve in #321, six here). On 2026‑10‑01 the far-prerequisite repairs B1–B4, the missing B6 trunc pattern and the review's N3/N4 cleanups were carried into the commits whose code they correct ([plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md)). The end tree is now that reference plus [`spec/carry-320.diff`](spec/carry-320.diff) (11 library files and 5 added tests); no other file differs ([name-status](evidence/carry/320.invariant.txt)). The #320 commits do not touch the pressure-set change. Patches: [`patches-320/`](patches-320/). Series branch: `split-320-321-carry` in `build/split-320-321/source` (commits `abfb29168fca`..`59d98c37ab77`); the pre-carry commits `42785c3bef21`..`1a616f08ea67` remain on branch `split-320-321`.

Attribution: split by Claude Code 2.1.283 (t4-opus-high agent), model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort. The rebase-preparation credit of the monolithic patch (OpenAI Codex CLI 0.157.1, model gpt-6-astra, xhigh reasoning effort, session `01a0e67f-298f-7a21-80af-06f867085f84`) and its provenance pointer are kept in every commit message.

Validation and default-mode evidence follow the method in the [#321 map](REVIEWER-MAP-321.md#how-to-read-and-validate). Per-commit logs: `build/split-320-321/evidence/c-320-NN/` for the carried commits (build, suites and default-mode hashes; summary in [`evidence/carry/stages.tsv`](evidence/carry/stages.tsv)), `p-320-NN/` for the pre-carry commits, and `t-320-NN/`, `320-NN/` for the first split; the parent of commit 1 (`25c40909b44a`, the second MC commit) is `p-320-00`.

## Dependency diagram

```mermaid
flowchart TD
  N["#321 series (16 commits)"] --> M1["MC: explicit address widths for constants"]
  M1 --> M2["MC: long address widths in printed assembly"]
  M2 --> F1["1 far address space + Imag32 quads"]
  F1 --> F2["2 far pointer values + long/[dp] accesses"]
  N -.->|s32 as 2 x s16 lanes, commit 9| F2
  F2 --> F3["3 far memory intrinsics"]
  F2 --> F4["4 bounded [dp],Y indexing"]
  N -.->|X16/Y16, selectXY16, fused Y pattern, commit 14| F4
```

All four far tests run with `+mos-a16`: far pointers are s32 values, and s32 merges and unmerges are legal only with the #321 lane rules. Without `+mos-a16` far code fails to legalize (see commit 2's default-mode note and the independent review's N7).

## Summary

| # | Commit | Subject | Code | Tests | Focused tests | Default-mode effect |
|---|---|---|---|---|---|---|
| 1 | `abfb29168fca` | Add the far address space and 32-bit imaginary pointer quads | +141/‑6 | +25 | imag32-copy.mir (added) | data layout string only |
| 2 | `3576ad627b5b` | Legalize and select far pointer values and memory accesses | +417/‑27 | +299 | far-addressing.ll, far-phi.ll, far-ptr-arg-exhaustion.ll, far-access-non-65816.ll, far-ptr-trunc.ll (last three added) | none for compiling inputs; non-65816 far accesses diagnosed |
| 3 | `eab4edb9dc32` | Route far memory intrinsics to the far runtime | +125 | +149/‑4 | far-memset.ll, far-memop-length.ll (added), far-access-non-65816.ll (extended) | none |
| 4 | `59d98c37ab77` | Select bounded runtime [dp],Y indexing for far byte accesses | +402/‑1 | +569 | far-indir-indexed.ll, far-index-fold-debug.ll (added) | none |

Default-mode evidence (fixed input set, commit vs parent): commits 1, 3 and 4 give identical assembly and objects in mos6502 and mosw65816. Commit 2 gives identical output for every input that compiles; the five corpus inputs that use address space 2 fail in both default modes before and after it, with a different message (a p2 G_LOAD before; an s32 G_MERGE_VALUES or G_UNMERGE_VALUES after, and on mos6502 for three of them the far-access diagnostic). Commit 1's comparison with `p-320-00` lists one "asm differ" per mode: `trapguard` aborts with the same LoopStrengthReduce assertion on both, and its hashed first stderr line begins with the `llc` file name (`p-320-00:` against `c-320-01:`); the output does not differ.

## Commits

### 1. Add the far address space and 32-bit imaginary pointer quads (`abfb29168fca`)

- **Purpose.** `p2:32:8` data layout and `AS_Far`; RLk quads over RS(2k):RS(2k+1) with `sublo16`/`subhi16`; Imag32 class and bank membership; quad naming, reservation, copies, copy cost, MC operand lowering and zero-page CSR placement.
- **Key hunks.** `TargetDataLayout.cpp`, `MOSTargetMachine.cpp` (data layout); `MOSInstrInfo.h` (`AS_Far`); `MOSRegisterInfo.td` (`sublo16`, `subhi16`, `MOSImagReg32`, `RL#K`, `MOSReg32Class`, `Imag32`); `MOSRegisterBanks.td`; `MOSRegisterInfo.cpp` (constructor naming, `getReservedRegs`, `copyCost`); `MOSInstrInfo.cpp` (`copyPhysRegImpl`); `MOSMCInstLower.cpp` (`lowerOperand`); `MOSZeroPageAlloc.cpp` (`runOnModule`, `collectCandidates`).
- **Tests.** imag32-copy.mir (added): a quad copy lowers to four byte copies in address order, with RL1 and RL2 naming `__rc4`–`__rc7` and `__rc8`–`__rc11`. Red on the parent: unknown register `rl2`. Nothing produces address-space-2 values until commit 2.
- **#594 reconciliation (blocking before submission).** Open upstream PR #594 (mlund, draft, head `7b80f7e1`) defines the same `sublo16`/`subhi16`, `MOSImagReg32`, `MaxImag32Regs`, `RL#K`, `MOSReg32Class` and `Imag32` family, with matching `copyPhysRegImpl`, `copyCost`, `MOSMCInstLower` and zero-page CSR changes. It differs in the register-number offset (this commit uses `Imag32RegsOffset = 0x600`; #594 derives numbers from `Imag16RegsOffset + MaxImag16Regs`) and in allocation policy (#594 keeps RL non-allocatable pending a linker contiguity contract). **This commit is the one a #594-based rebase replaces**: carry #594 unchanged in its place and move only this commit's remaining differences (data layout, `AS_Far`, bank membership, reservation, allocatability) into a follow-up. Its register definitions are unchanged here: aligning with #594 is escalated for a decision (see the [carry plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md#594-reconciliation-b7)). The carry applied only N3 formatting and restored #321‑1's "Native widths:" comment, which the pre-carry commit rewrote to a history tag.

### 2. Legalize and select far pointer values and memory accesses (`3576ad627b5b`)

- **Purpose.** Far pointer arguments in RL1‑RL3 (i32 calling-convention type); p2 legality for globals, casts, pointer adds with bank carry, PHIs (via s32) and near→far casts; byte loads and stores through absolute-long (`lda $xxxxxx`) and `[dp]`; far symbol addresses from ADDR24 relocation modifiers; Imag32 REG_SEQUENCE merges and word unmerges.
- **Key hunks.** `MOSCallingConv.td` (`CCIfPtrAddrSpace<2, …RL1..RL3>`); `MOSISelLowering.cpp`; `MOSCallLowering.cpp`; `MOSInstrGISel.td` (G_LOAD/STORE_FAR_ABS, G_LOAD/STORE_FAR_INDIR); `MOSInstrLogical.td` (LDAbsLong, STAbsLong, LDIndirLong, STIndirLong); `MOSInstrInfo.h` (MO_ADDR24_*); `MOSLegalizerInfo.cpp` (PF rules, `legalizePhi`, `legalizePtrAdd`, `legalizeAddrSpaceCast`, `selectAddressingMode` case 32, `tryFarAbsoluteAddressing`, `tryFarIndirectAddressing`); `MOSInstructionSelector.cpp` (`getRegClassForType`, `isFarSymbol`, `buildFarAddrWords`, `selectAddr`, `selectAddrLoHi`, `selectMergeValues`, `selectUnMergeValues`, `selectGeneric` Imag32 pin); `MOSMCInstLower.cpp` (LDCImm, ADDR24 symbol flags); `MOSRegisterInfo.cpp` (`getRegAllocationHints` width filter); `MOSLateOptimization.cpp` (`combineLdImm` GPR guard).
- **Carried repairs.** B1: `CCIfPtrAddrSpace<2, CCAssignToStack<4, 1>>` directly after the RL rule, so a fourth far pointer takes a 4-byte stack slot instead of a 16-bit RS pair. B3: `rejectFarAccessWithoutLong` diagnoses far loads, extending loads and stores on CPUs without 65816 long addressing. B6: `Pat<(i16 (trunc Imag32:$s)), (EXTRACT_SUBREG Imag32:$s, sublo16)>` under `HasAccum16`.
- **Interim text.** The `selectGeneric` pin condition lists only the two non-indexed far opcodes until commit 4 adds the indexed ones.
- **Tests.** far-addressing.ll, far-phi.ll; added far-ptr-arg-exhaustion.ll (B1), far-access-non-65816.ll (B3) and far-ptr-trunc.ll (B6).
- **Plan deviation.** The plan's commits 2 (legalize) and 3 (select) are one commit here: far-phi.ll's legalizer checks name the selected-form opcode G_LOAD_FAR_INDIR, and far-addressing.ll checks assembly and object bytes, so legalization alone has no observable test.

### 3. Route far memory intrinsics to the far runtime (`eab4edb9dc32`)

- **Purpose.** Non-inlined G_MEMSET/G_MEMCPY/G_MEMMOVE with any far pointer call the far runtime, widening near pointers to far. A provably 16-bit length calls `__memset_far`/`__memcpy_far`/`__memmove_far` with a size_t; any other length calls the `…_far32` entries with a uint32_t (B2), so no length is truncated. Far memory intrinsics on non-65816 CPUs are diagnosed (B3).
- **Key hunks.** `MOSLegalizerInfo.cpp` (`anyFarPointerOperand`, `createFarMemLibcall` with the length domain, `legalizeMemOp` hook and diagnostic; `llvm/IR/CallingConv.h` include).
- **Tests.** far-memset.ll; added far-memop-length.ll (B2); far-access-non-65816.ll extended with a far memset (B3).

### 4. Select bounded runtime [dp],Y indexing for far byte accesses (`59d98c37ab77`)

- **Purpose.** Fold constant displacements 1‑3 and range-proven runtime offsets from a runtime far pointer into `lda/sta [dp],y`; 16-bit Y under `+mos-xy16` with a fused `ldy zp` + access pseudo.
- **Key hunks.** `MOSInstrGISel.td` (G_*_FAR_INDIR_IDX, G_*_FAR_INDIR_IDX16); `MOSInstrLogical.td` (LDIndirLongIdx, STIndirLongIdx, LDIndirLongYIdx, STIndirLongYIdx); `MOSAsmPrinter.cpp`; `MOSLegalizerInfo.cpp` (`kMaxFarIndirIdxDisp`, `mayBecomeCall`, `noCallBetween`, `allUsesAreFoldableFarAccesses`, `tryFarRuntimeIndexFold`, `tryFarIndirectIndexedAddressing`); `MOSLegalizerInfo.h`; `MOSInstructionSelector.cpp` (dispatch, `selectXY16` far case, `selectGeneric` cases and pin).
- **Carried repair.** B4: once the last access folds, `tryFarRuntimeIndexFold` sets the remaining DBG_VALUEs of the dead pointer adds to `$noreg`. The far-word 0070 word fold uses the same function, so far-word patch 12 needs no code change; it extends the test with the word fold.
- **Tests.** far-indir-indexed.ll (26 functions, assembly, object bytes and post-selection MIR in two modes); added far-index-fold-debug.ll (B4, byte fold).

## Where the independent review's findings land

From [the far-word independent review](../far-word-rebase/independent-review.md). On 2026‑10‑01 each #320 fix was folded into the commit that introduces the code it changes ([plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md)); red/green evidence: [`evidence/carry/red-green.tsv`](evidence/carry/red-green.tsv).

| Finding | Summary | Status |
|---|---|---|
| B1 | Far-pointer argument exhaustion falls through to a 16-bit RS pair | Fixed in #320‑2 `3576ad627b5b`, test far-ptr-arg-exhaustion.ll |
| B2 | Far memory intrinsic lengths above 65535 truncated or deleted | Fixed in #320‑3 `eab4edb9dc32`, test far-memop-length.ll |
| B3 | Far accesses on non-65816 CPUs emit `[dp]` opcodes | Fixed in #320‑2 (loads and stores) and #320‑3 (memory intrinsics), test far-access-non-65816.ll |
| B4 | Undef DBG_VALUE after the far runtime-index fold | Fixed in #320‑4 `59d98c37ab77`, test far-index-fold-debug.ll; far-word patch 12 adds the word-fold case |
| B5 | Far quad DWARF is a malformed composite | Open: tied to the #594 numbering decision (escalated) |
| B6 | Missing `Pat<(i16 (trunc Imag32:$s)), (EXTRACT_SUBREG Imag32:$s, sublo16)>`; s32→s16 G_TRUNC asserts in `selectTrunc` | Fixed in #320‑2, test far-ptr-trunc.ll |
| B7 | Imag32 collides with open #594 | Open: escalated for a decision; #320‑1 is the commit a #594 alignment replaces |
| N3 | clang-format lines (per commit, C++ hunks) | #320: 0 in each of commits 1–4 after the carry (was 19, 16, 11, 60; [counts](evidence/carry/format-320.txt)). #321 is not changed: 1: 4, 4: 11, 5: 3, 6: 48, 7: 26, 8: 110, 9: 76, 10: 188, 11: 125, 12: 4, 14: 134, 15: 22, 16: 2 (others 0). The review's `MOSTargetMachine.cpp` include order and long comment are in #321‑4 `c5dfebbfbf55`. |
| N4 | History-tag comment lines (`#321`, "Increment", "Phase", `B1:`) | #320: none after the carry (was #320‑1: 1, #320‑4: 7). #321 is not changed: ‑2: 4, ‑4: 4, ‑6: 1, ‑8: 13, ‑10: 8, ‑11: 14, ‑14: 7, ‑15: 1; the broken "(Native widths: )" comment is in #321‑8 `c6337b5af878` (`legalizeLoadStore16`). Line list: `build/split-320-321/evidence/history-tag-lines.txt`. |

N3 counts come from `clang-format-diff.py` with the container's `/opt/llvm-mos/bin/clang-format` on each commit's C++ hunks (`build/split-320-321/spec/format-count.sh`); they count reformatted output lines, so they are comparable across commits but not identical to the review's per-patch blame totals.
