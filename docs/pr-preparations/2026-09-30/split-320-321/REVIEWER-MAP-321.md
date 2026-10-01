# Reviewer map: #321 native widths as a 16‑commit series

This series replaces the monolithic patch `340c8ee25d5c` ("Extract opt-in native widths and near-memory prerequisites", 38 files, +5,391). It starts at llvm-mos `06bc967d2668` and ends at the tree of `340c8ee25d5c` plus the [native-width pressure-set change](../../../plans/2026-09-30-native-register-pressure-sets.md#application) (reference commit `0a9dad44a2d9`, tree `778746df6e90`), plus twelve test files the split adds under `llvm/test/` (no other file differs). Patches: [`patches-321/`](patches-321/). Series branch: `split-320-321-r3` in `build/split-320-321/source` (commits `e8441515e009`..`2387a7c83de4`; round five added frame-index-displacement.ll to #321‑11, which changed the hashes from #321‑11 on and no tree outside `llvm/test/`); the third round (2026‑10‑01) rebuilt every commit with review findings N3 and N4 fixed (clang-format of each commit's own C++ lines, history tags removed), which changes only comments and whitespace plus one sorted `#include` ([check](evidence/r3/321-token-equal.txt)). The earlier commits `45bc97d89c6a`..`aa868b952570` stay on branch `split-320-321`.

Attribution: split by Claude Code 2.1.283 (t4-opus-high agent), model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort. The extraction credit of the monolithic patch (OpenAI Codex CLI 0.158.0, model gpt-6-astra, xhigh reasoning effort, session `01a0e75a-a9ed-7372-9bac-b19b732a46a2`) is kept in every commit message.

## How to read and validate

- Every commit builds with assertions and passes `llvm/test/CodeGen/MOS` and `llvm/test/MC/MOS` on its own (per-commit logs: `build/split-320-321/evidence/p-321-NN/`; summaries in [`evidence/`](evidence/)).
- Every commit except 4, 9, 10, 11, 12, 14 and 16, whose tests come from the monolithic patch, carries a test the split adds. Each added test fails on the parent commit and passes on its own commit and every later one ([red/green table](evidence/red-green.tsv)), except `native-width-default-pressure.ll` (commit 1), which pins upstream's default code and so passes on the parent by design.
- Each commit message gives one **Validate** command. Paths are relative to an llvm-mos checkout; `build/bin` is an assertions build of that commit.
- **Default-mode effect** compares the commit with its parent on a fixed input set. The first two rounds used `-mcpu=mos6502` and plain `-mcpu=mosw65816` (no `+mos-a16`/`+mos-xy16`); since the third round every commit is also compared on all 14 MOS CPUs at `-O2` ([table](evidence/r3/default-all-cpus.txt)). That found three effects the two-CPU check missed, now stated in the commit messages: #321‑3 also adds `$xh` mapping symbols to mos65el02 objects, #321‑11 changes two moshuc6280 inputs (it fixes an upstream HuC6280 block-move miscompile as a side effect, [record](../../../defects/mos-huc-blockmove-frameindex-offset.json)), and #321‑12 changes code on 13 of the 14 CPUs. The set is the 38 MOS CodeGen `.ll` tests at `06bc967d2668` plus 52 frozen corpus IRs (every 8th `*.default.ll` of the near-proof replay driver, target attributes stripped). Assembly and object hashes are recorded per commit, not full outputs.

## Dependency diagram

Solid arrows are code dependencies; dotted arrows are test-only dependencies. Commits 5, 7 and 16 use nothing the series adds (they touch only existing registers and instructions), so they could be reviewed or merged ahead of it; they were built only in series order.

```mermaid
flowchart TD
  C1["1 registers + feature gates"] --> C2["2 accumulator forms"]
  C1 --> C3["3 index forms, X-width flags"]
  C2 --> C4["4 REP/SEP insertion"]
  C3 --> C4
  C2 --> C6["6 native spills + copies"]
  C3 --> C6
  C4 --> C8["8 native loads/stores"]
  C6 --> C8
  C1 --> C9["9 s32/s64 lanes, wide anyext"]
  C8 --> C10["10 native ALU/shifts + A16 residency"]
  C9 -.->|anyext-masked-byte.ll| C10
  C10 --> C11["11 native compares, fused branches"]
  C10 -.->|observer test checks an s16 G_ADD kept by commit 10 (reasoned, not built)| C12["12 byte index stays byte-wide"]
  C8 --> C13["13 near-index no-wrap proof"]
  C11 --> C14["14 +mos-xy16 index selection"]
  C13 --> C14
  C10 --> C15["15 relocatable small 8-bit adds"]
  C5["5 status flags across scavenging"]
  C7["7 coalescing guard"]
  C16["16 interrupt M/X/D/DBR protocol"]
```

## Summary

Line counts are added/removed lines from `git diff --numstat`, split into code and tests. "(added)" marks a test the split adds; the others come from the monolithic patch.

| # | Commit | Subject | Code | Tests | Focused tests | Default-mode effect |
|---|---|---|---|---|---|---|
| 1 | `45bc97d89c6a` | Model 65816 native-width registers and feature gates | +66/‑1 | +152 | native-width-registers.mir, native-width-default-pressure.ll (added) | none |
| 2 | `793da9041cd3` | Define 16-bit accumulator instruction forms | +344/‑1 | +66 | a16-accumulator-forms.mir (added) | none |
| 3 | `2d64d3c841ff` | Define 16-bit index instruction forms and X-width requirements | +258/‑14 | +107 | index-width-mapping-65816.s, xy16-index-forms.mir (added) | **objects**: `$xh` mapping symbols |
| 4 | `c5dfebbfbf55` | Insert REP/SEP from M/X width requirements | +847/‑1 | +290 | insert-rep-sep-stack.mir, insert-rep-sep-cloned-kills.mir | none |
| 5 | `8eb8a6534bdf` | Preserve status flags across register scavenging | +155/‑33 | +314 | scavenger-p-undef-6502.ll (added) | none in the set; fixes a mos6502 -O0 assertion |
| 6 | `b86abf199cbb` | Spill and copy native-width registers | +202/‑5 | +69 | native-spill-copy.mir (added) | none |
| 7 | `ba6887cac12d` | Keep call-clobbered imaginary copies out of Imag16 pairs | +51 | +57 | coalesce-call-clobbered-imag.mir (added) | none observed |
| 8 | `c6337b5af878` | Legalize and select native 16-bit loads and stores | +736/‑17 | +119 | a16-load-store.ll, native-width-pressure-opt-level.ll (added) | none |
| 9 | `56e6c7f91e9e` | Legalize native s32/s64 lanes and wide any-extensions | +166/‑15 | +92 | anyext-wide.mir, anyext-masked-byte.ll | none observed |
| 10 | `a520448a2c7f` | Select native 16-bit arithmetic, logic and constant shifts | +467/‑13 | +348 | a16-byte-store.ll, a16-indirect-byte-store.ll | none |
| 11 | `9b471aa8df06` | Select native 16-bit compares and fused branches | +543/‑15 | +65 | a16-immediate-width.ll | none |
| 12 | `497db2760440` | Keep byte indexes byte-wide in absolute indexed addressing | +41/‑1 | +52/‑3 | zp-byte-index.ll, legalizer-indexed-offset-observer.mir, legalizer.mir | **asm changes** (both modes) |
| 13 | `ef1fdd877206` | Require a no-wrap proof before folding near indexes on the 65816 | +24/‑1 | +63 | near-index-nowrap.ll (added) | **asm changes** (mosw65816) |
| 14 | `a6718b6f6560` | Select 16-bit index registers under +mos-xy16 | +578/‑7 | +120 | xy16-near-indir-y.ll | none |
| 15 | `8db2e8118a70` | Keep small 8-bit adds relocatable under +mos-a16 | +42 | +39 | a16-small-add.ll (added) | none |
| 16 | `aa868b952570` | Preserve interrupted M/X state in 65816 interrupt handlers | +44 | +34 | interrupt-width-65816.ll | **asm changes** for mosw65816 interrupt handlers |

## Default-mode evidence

Counts are inputs whose assembly (or only object) differs from the parent commit. Of the 90 inputs per mode, 54 compile in mos6502 and 78 in mosw65816 at the base (79 from commit 13 on); failures are compared by normalized first error line.

| # | mos6502 | mosw65816 | Size (bytes, inputs compiling on both sides) | Explanation |
|---|---|---|---|---|
| 3 | 0 | 68 object-only | 0 | `XHigh` on LDX/STX/LDY/STY/CPX/CPY makes the W65816 ELF streamer emit `$xh` mapping symbols. Section bytes and relocations are identical (`evidence/321-03/objdiff-boids.txt`: 667 → 1,121 `$xh`). |
| 12 | 16 asm | 18 asm | +243 / ‑102 | An s8 index is used directly, and a shared s16 offset gets an explicit zero high byte. mos6502: 12 larger, 3 smaller; mosw65816: 17 smaller. |
| 13 | 0 | 28 (27 asm, 1 newly compiling) | 0 / +4,620 | Byte indexes into runtime pointers need a 16-bit add unless the add is proven not to wrap. `examples_snes_sodo` fails on the base with "Remaining virtual register" in frame lowering and compiles after this commit; the shape is avoided, not repaired. |
| 16 | 0 | 3 asm | 0 / +110 | Exactly the three tests with `"interrupt"` functions (nonreentrant.ll, static-stack.ll, zp-alloc.ll). |
| all others | 0 | 0 | 0 | Assembly and objects identical. |
| **base → 16** | | | **+243 (0.1%) / +4,628 (1.6%)** | Sum of commits 12, 13 and 16. Commit 1 changed default code by +3,478 / +3,202 in the first split, before its native classes were kept out of the generated pressure sets. |

## Commits

Each entry lists the purpose, the key hunks, the tests and what a reviewer should check. The review findings column maps the independent review's N3 (clang-format lines this commit would reformat, `clang-format-diff.py` on the commit's C++ hunks) and N4 (added lib lines carrying history tags such as `#321`, "Increment", "Phase") to commits, so follow-ups can land in the right place.

### 1. Model 65816 native-width registers and feature gates (`e8441515e009`; before the third round `45bc97d89c6a`)

- **Purpose.** Opt-in features `mos-a16` and `mos-xy16` (implies `mos-a16`); registers A16=A:B, X16=X:XH, Y16=Y:YH covered by their byte halves, with native DWARF numbers 0x01000000‑0x01000002; single-member classes Ac16/Xc16/Yc16; Ac16 joins the register bank.
- **Key hunks.** `MOSFeatures.td` (FeatureAccum16, FeatureIndex16); `MOSSubtarget.h` (hasAccum16/hasIndex16); `MOSRegisterInfo.td` (B, A16, XH, YH, X16, Y16; Ac16, Xc16, Yc16 inside `let GeneratePressureSet = 0`); `MOSRegisterBanks.td`.
- **Check.** No CPU implies the features; byte registers alias the wide ones through `CoveredBySubRegs`.
- **Check.** `GeneratePressureSet = 0` keeps the generated pressure tables identical to the parent's: TableGen would otherwise derive sets from the new classes, and MachineLICM, MachineSink and the scheduler read those tables in every mode.
- **Default effect.** None: the fixed input set is identical to the parent in both modes.
- **Tests.** native-width-registers.mir (added): both features are recognized; the Ac16/Xc16/Yc16 classes and A16/X16/Y16 registers parse and verify, and `sublo` names the existing byte register. Red on the parent: unknown register class. native-width-default-pressure.ll (added) pins default mos6502 and mosw65816 code for `llvm.scmp.i16.i32`, which moves when the native classes have pressure sets; it passes on the parent and fails without the flag.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 4, N4 0).

### 2. Define 16-bit accumulator instruction forms (`faece4151665`; before the third round `793da9041cd3`)

- **Purpose.** HasAccum16 predicate; MLow TSFlag on logical pseudos; word pseudos for load/store (abs, abs,X, (zp), (zp),Y, Imag16), ADC/SBC/AND/ORA/EOR, CMP, ASL/LSR/ROR/INC/DEC; `mos16()` printing of small 16-bit immediates.
- **Key hunks.** `MOSInstrFormats.td` (HasAccum16, `imm16` PrintMethod); `MOSInstrLogical.td` (MOSLogicalInstr MLow; LDAbs16 … RORAcc16); `MOSInstPrinter.cpp` (printImm16Operand).
- **Check.** Every pseudo expands to the width-agnostic MC opcode; no Ac16↔byte COPY exists.
- **Tests.** a16-accumulator-forms.mir (added): a sequence of accumulator pseudos emitted from MIR (starting at branch relaxation, so no REP/SEP) checks each expanded instruction, `mos16()` for 66 and 255, bare 43981, and the three-byte immediate encodings in the object. a16-immediate-width.ll (commit 11) checks the printing on selected code.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 0, N4 4).

### 3. Define 16-bit index instruction forms and X-width requirements (`5364ac03a4fc`; before the third round `2d64d3c841ff`)

- **Purpose.** HasIndex16; XLow/XHigh TSFlags; X/Y 16-bit loads, stores, compares, inc/dec, abs,X16 and (zp),Y16 accesses, TXA16/TAX16/TYA16/TAY16, PHA16/PLA16; `XHigh` on the existing 8-bit index-register memory forms.
- **Key hunks.** `MOSInstrFormats.td` (HasIndex16; CC0_Regular `XHigh`); `MOSInstrInfo.td` (`XHigh` on STX/LDX/STY/LDY forms); `MOSInstrLogical.td` (XLow/XHigh bits; LDAbsXIdx … STIndirYIdx16; LDXAbs16 … PLA16).
- **Default effect.** `$xh` mapping symbols in mosw65816 and mos65el02 objects only (68 of 90 objects each; assembly identical on every CPU).
- **Tests.** index-width-mapping-65816.s (added): each of the 15 XHigh forms, assembled after a 16-bit `ldx`, opens its own `$xh` mapping region (red on the parent: no `$xh` symbols). xy16-index-forms.mir (added): the index pseudos expand to the expected instructions and three-byte index immediates.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 0, N4 0).

### 4. Insert REP/SEP from M/X width requirements (`e7943fff59cc`; before the third round `c5dfebbfbf55`)

- **Purpose.** Late pass placing REP/SEP from TSFlags: forward M/X dataflow, 8-bit ABI at entry/calls/returns, width-agnostic carry init, combined `#$30`, critical-edge placement, live X16 preservation across narrowing, STZ pair fusion. No-op without `+mos-a16`.
- **Key hunks.** `MOSInsertREPSEP.cpp` (new, 811 lines: `requiredWidth`/`requiredXWidth`, `runOnMachineFunction`, `placeIntraBlock`, `placeLegacy`, `preserveX`, `getStackDepths`); `MOSTargetMachine.cpp` (`addPreEmitPass` before branch relaxation).
- **Tests.** insert-rep-sep-stack.mir, insert-rep-sep-cloned-kills.mir.
- **Size note.** 847 non-test lines, above the ~600 target; the pass is one algorithm in one new file and is not split further.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 11, N4 4 (for example "The original Increment-1a behavior")).

### 5. Preserve status flags across register scavenging (`ff8b09f53b78`; before the third round `8eb8a6534bdf`)

- **Purpose.** Scavenger can save a live P: PHP/PLP on balanced ranges, a dead-index-register courier through RC17 on unbalanced ones, `undef` PHP when no sub-register of P is defined; removes the N/Z-dead assertion.
- **Key hunks.** `MOSRegisterInfo.cpp`: `computeLiveBefore`, `findDeadIndexReg`, `hasNoAvailableValue`, `saveScavengerRegister` (case P), `canSaveScavengerRegister`.
- **Upstream note.** Target-generic MOS change; it can be reviewed ahead of the feature.
- **Tests.** scavenger-p-undef-6502.ll (added; reduced from gcc.c-torture strlen-4.c, taken from the downstream tree's tests): mos6502 at -O0 with a frame over 255 bytes, through prologue/epilogue insertion with the verifier on. It checks `PH undef $p` where no status bit holds a value and a plain `PH $p` where carry is live. The parent fails it on the N/Z-dead assertion, so this commit also fixes a default-mode (stock 6502) assertion.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 3, N4 0).

### 6. Spill and copy native-width registers (`076489c7de87`; before the third round `b86abf199cbb`)

- **Purpose.** Copies Xc16/Yc16↔Imag16; static-stack spills of Ac16/Xc16/Yc16; soft-stack spills through `(zp)` with an exact slot pointer, X16/Y16 staged through A16 and bracketed by PHA16/PLA16 when A is live.
- **Key hunks.** `MOSInstrInfo.cpp` (`copyPhysRegImpl`, `loadStoreRegStackSlot`); `MOSRegisterInfo.cpp` (`pushPullBalanced`, `accumulatorLiveAcross`, `expandLDSTStk` → `expandLDSTStkImpl`); `MOSRegisterInfo.h`.
- **Ordering.** Placed before any native selection so no selection commit can meet an unlowerable spill.
- **Tests.** native-spill-copy.mir (added): A16 soft-stack spills at offset zero and through a formed nonzero-offset pointer, an X16 spill and reload staged through A16 inside PHA16/PLA16 while A16 is live, and X16/Y16 copies with Imag16 pairs. Red on the parent: the byte spill path asserts on A16.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 48, N4 1).

### 7. Keep call-clobbered imaginary copies out of Imag16 pairs (`25e5dba45c10`; before the third round `ba6887cac12d`)

- **Purpose.** `shouldCoalesce` declines folding `vreg = COPY $rcN` into an Imag16 pair when the vreg lives across a call clobbering `$rcN`.
- **Key hunks.** `MOSRegisterInfo.cpp` (`copiedFromClobberedPhysImag`, `shouldCoalesce`).
- **Upstream note.** Target-generic; a standalone candidate.
- **Tests.** coalesce-call-clobbered-imag.mir (added): after the register coalescer, byte COPYs of `$rc2`/`$rc3` that build an Imag16 pair stay separate when a second call intervenes, and coalesce into the pair when it does not. Red on the parent: the pair absorbs `$rc2`/`$rc3` across the call.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 26, N4 0).

### 8. Legalize and select native 16-bit loads and stores (`6f7d9e07ad75`; before the third round `c6337b5af878`)

- **Purpose.** s16 G_LOAD/G_STORE → `G_LOAD16_ABS`/`_INDIR`/`_ABS_IDX`/`_INDIR_IDX` under `+mos-a16`, with byte-path exceptions (constants, byte-only loads, byte-built stores, A:X indirect stores, atomics); selector word forms.
- **Key hunks.** `MOSInstrGISel.td` (G_LOAD16_* / G_STORE16_*); `MOSLegalizerInfo.cpp` (`legalizeLoadStore16`, `tryIndexedAddressing16`, `legalizeLoad`/`legalizeStore` dispatch, load/store rule); `MOSInstructionSelector.cpp` (`selectMem16Indir`, `selectMem16Abs`, `selectMem16AbsIdx`, `selectMem16IndirIdx`, `loadStoreValueIntoA16`).
- **Interim text.** Until commit 14, `tryIndexedAddressing16` uses 8-bit-index opcode lambdas and the plain `ConstOffset <= 255` condition; commit 14 generalizes both.
- **Native register pressure.** `MOSRegisterInfo` takes the subtarget and the target machine's optimization level (`RegInfo(*this, TM.getOptLevel())`) and overrides the six pressure-set hooks. Under `+mos-a16`, Ac16/Xc16/Yc16 count toward their low byte's generated sets; below `-O3` the hooks also append sets A16, X16 and Y16 (limit 2), charged by each wide register's byte units and by Ac/Ac16, Xc/Xc16, Yc/Yc16. `-O3` (`CodeGenOptLevel::Aggressive`) leaves the appended sets out; the choice is made once per subtarget because `RegisterClassInfo` caches set limits. Without `+mos-a16` every hook returns the generated tables. Measurements: [evidence](../../../defects/evidence/2026-09-30-native-width-pressure-sets/final/README.md).
- **Check.** The constructor comment's claim that the level cannot change after construction (MOS never runs SelectionDAGISel, the only `setOptLevel` caller in codegen); `hasNativePressureSets` read lazily because `RegInfo` is built before the subtarget parses its features.
- **Tests.** a16-load-store.ll (added): absolute, (zp) and (zp),y (runtime and constant index) word copies in one rep/sep bracket, and a constant store kept as two byte stores. Its checks allow the Imag16 home between load and store that commit 10's residency peephole later removes. a16-byte-store.ll and a16-indirect-byte-store.ll land in commit 10: they need native producers and that peephole. native-width-pressure-opt-level.ll (added, `REQUIRES: asserts`): the scheduler's pressure sets for a word copy include A16 at `-O2` and only the low byte's sets at `-O3`; red on the parent, which creates no native values.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 110, N4 13, including the broken comment "(Native widths: )" in `legalizeLoadStore16`).

### 9. Legalize native s32/s64 lanes and wide any-extensions (`9cf29583ac1b`; before the third round `56e6c7f91e9e`)

- **Purpose.** Under `+mos-a16`, s32 = 2 × s16 and s64 = 2 × s32 (ext/trunc/merge/unmerge rules, four-piece split helpers). In every mode, G_ANYEXT from unusual widths lowers through G_ZEXT.
- **Key hunks.** `MOSLegalizerInfo.cpp` (G_ANYEXT/G_TRUNC, G_MERGE_VALUES/G_UNMERGE_VALUES rules, `legalizeMergeS32FromBytes` … `legalizeUnmergeS64ToWords`, `legalizeCustom`); `MOSLegalizerInfo.h`.
- **Ordering.** Precedes native arithmetic: without it anyext-masked-byte.ll fails under `+mos-a16` ("unable to legalize … G_UNMERGE_VALUES s64") once commit 10 lands (seen in the first ordering, `evidence/v1-order/321-09`).
- **Tests.** anyext-wide.mir, anyext-masked-byte.ll.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 76, N4 0).

### 10. Select native 16-bit arithmetic, logic and constant shifts (`812d7b1c4b24`; before the third round `a520448a2c7f`)

- **Purpose.** s16 add/sub/and/or/xor and constant shifts 1‑7 stay native; `selectAlu16Native` (immediate, absolute-operand folds, inc/dec), `selectShift16Native` (asl/lsr; `cmp #$8000; ror` for ASHR); post-RA `threadAccum16` keeps A16 resident across `sta rsN; lda rsN`.
- **Key hunks.** `MOSLegalizerInfo.cpp` (bitwise rules, `legalizeAddSub`, `legalizeShiftRotate` passthrough); `MOSInstructionSelector.cpp` (`select` dispatch, `getI16Const`, `getImm16Operand`, `noClobberBetween`, `foldableAbsLoad16`, `selectAlu16Native`, `selectShift16Native`); `MOSLateOptimization.cpp` (`threadAccum16`).
- **Interim text.** `foldableAbsLoad16` has no Xc16 guard until commit 14.
- **Tests.** a16-byte-store.ll, a16-indirect-byte-store.ll (store policy of commit 8 with native producers present).
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 188, N4 8).

### 11. Select native 16-bit compares and fused branches (`7ef7cfc86eb3`; before the third round `9b471aa8df06`)

- **Purpose.** Native UGE/ULT via one 16-bit G_SBC; SLT via sign flip; profitable native EQ; fused CmpBr16 pseudos and their expansion; opcode-keyed frame-index displacement; byte sign fill for 16-bit ASHR by bytes.
- **Key hunks.** `MOSInstrPseudos.td` (CmpBrImag16 … CmpBrImagAbs16); `MOSInstrInfo.cpp` (`getBranchDestBlock`, `analyzeBranch`, `expandPostRAPseudo`, `expandCmpBr16`); `MOSRegisterInfo.cpp` (`eliminateFrameIndex`); `MOSLegalizerInfo.cpp` (`legalizeICmp`, G_ASHR fill); `MOSInstructionSelector.cpp` (CmpNZ16 matchers, `selectBrCondImm`, `foldableIndirLoad16`, `selectSbc16`).
- **Default effect.** moshuc6280 only, found by the third round's all-CPU check. The opcode-keyed frame-index displacement also changes the HuC6280 `HuCMemcpy` pseudo, whose destination frame index is followed by the block length: upstream used that length as the destination offset (a silent miscompile, [record](../../../defects/mos-huc-blockmove-frameindex-offset.json)), and this commit uses the operand's own offset. Two moshuc6280 inputs of the fixed set change; the other 13 CPUs are identical. The 2026‑06‑19 plan that introduced the change said CmpBrAbsImm16 was the only affected instruction. The HuC6280 part cannot be offered on its own cleanly: it is the same rule this commit needs for CmpBrAbsImm16, and without it the a16frameidx corpus input miscompiles (round four, [probe](evidence/r4/huc-split-probe.txt)). Since round five, frame-index-displacement.ll pins the rule: it fails on #321‑10 and on #321‑11 with the rule reverted, and passes from #321‑11 on ([red/green](evidence/r5/red-green.tsv)).
- **Tests.** a16-immediate-width.ll (also covers commit 2's printing); frame-index-displacement.ll (round five): native compares on a stack array under +mos-a16 read `sstk`, `+2`, `+4`, `+6` (the old rule gave `+4`, `+3`, `+2`, `+1`), and a HuC6280 32-byte constant copy goes to offsets 0 and 16.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 125, N4 14).

### 12. Keep byte indexes byte-wide in absolute indexed addressing (`de6252e3f867`; before the third round `497db2760440`)

- **Purpose.** s8 index used directly; a byte-sized s16 index is truncated and its other users get an explicit `merge(lo, 0)`, with observer notification for CSE.
- **Key hunks.** `MOSLegalizerInfo.cpp` (`tryAbsoluteIndexedAddressing`).
- **Default effect.** Asm changes on 13 of the 14 CPUs (16 inputs on each 6502-family CPU, 18 on mosw65816, mosw65c02 and mos65el02, 1 on mossweet16; mosspc700 identical); legalizer.mir updated.
- **Upstream note.** Changes default output, so it needs its own justification in review.
- **Tests.** zp-byte-index.ll, legalizer-indexed-offset-observer.mir; legalizer.mir updated.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 4, N4 0).

### 13. Require a no-wrap proof before folding near indexes on the 65816 (`bb92d09bc1f4`; before the third round `ef1fdd877206`)

- **Purpose.** `canFoldNearIndex`: on the 65816 an indexed access carries into DBR, so a near G_PTR_ADD folds only with nuw, nusw with a non-negative offset, or a known-bits bound.
- **Key hunks.** `MOSLegalizerInfo.cpp` (`canFoldNearIndex`; calls in `tryIndexedAddressing16`, `tryAbsoluteIndexedAddressing`, `selectIndirectAddressing`).
- **Default effect.** mosw65816 asm changes, +4,620 bytes on the fixed set. The later near-index recovery patches add no-wrap proofs for common shapes; their effect on this set was not measured here.
- **Tests.** near-index-nowrap.ll (added): on mos6502 and mosw65816, a plain add (folded only on mos6502), nuw and inbounds non-negative adds (folded on both), a global base (folded only on mos6502) and a constant base bounded by known bits (folded on both).
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 0, N4 0).

### 14. Select 16-bit index registers under +mos-xy16 (`fe09b1b43fc7`; before the third round `a6718b6f6560`)

- **Purpose.** s16 offsets as 16-bit X/Y indexes (B2), Xc16 classification of loads whose users can take X (B1), `selectXY16`, fused `ldy zp; lda/sta (zp),y` pseudos emitted by the assembly printer.
- **Key hunks.** `MOSInstrGISel.td` (G_*_IDX16); `MOSInstrLogical.td` (LDIndirYIdxFused …); `MOSAsmPrinter.cpp` (`emitInstruction`); `MOSLegalizerInfo.cpp` (`allUsesAreXY16Compatible`, B1/B2 hunks); `MOSInstructionSelector.cpp` (`isXc16Reg`, `isYc16Reg`, `selectXY16`, dispatch).
- **Tests.** xy16-near-indir-y.ll.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 134, N4 7).

### 15. Keep small 8-bit adds relocatable under +mos-a16 (`fca866fa6f75`; before the third round `8db2e8118a70`)

- **Purpose.** ±2 on an s8 under `+mos-a16` becomes two INC/DEC on Anyi8, avoiding an A-pinned counter that deadlocks allocation around Ac16 transits.
- **Key hunks.** `MOSInstructionSelector.cpp` (`selectAddSub`).
- **Tests.** a16-small-add.ll (added): +2 and -2 become `inx; inx` and `dex; dex` under +mos-a16, +3 keeps `adc`, and the default mode keeps `adc` for all three. The allocation failure that motivates the change needs a larger function and is not reproduced by this test.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 22, N4 1).

### 16. Preserve interrupted M/X state in 65816 interrupt handlers (`2387a7c83de4`; before the third round `aa868b952570`)

- **Purpose.** 65816 interrupt prologue/epilogue saves A/X/Y at 16 bits plus DBR and D, establishes M8/X8, D=0, DBR=0; RTI restores P.
- **Key hunks.** `MOSFrameLowering.cpp` (`emitPrologue`, `emitEpilogue`).
- **Default effect.** Applies to plain mosw65816 interrupt handlers.
- **Upstream note.** Depends on nothing else in the series; the blueprint asks to present it with the feature narrative rather than as an unrelated fix.
- **Tests.** interrupt-width-65816.ll.
- **Findings.** N3 and N4 fixed in the third round: 0 clang-format lines and 0 history tags (before: N3 2, N4 0).

## Gaps a reviewer will notice

- **Tests the split adds:** commits 1, 2, 3, 5, 6, 7, 8, 13 and 15 carry tests that the monolithic patch did not have; the series ends at the monolithic tree plus the pressure-set change plus these twelve files. None has been copied into downstream `0002`: applying the pressure-set change downstream is held for a user decision ([plan](../../../plans/2026-09-30-native-register-pressure-sets.md#application)).
- **Default code size:** commits 12 and 13 grow default code on the fixed set (+0.1% mos6502, +1.6% mosw65816 end to end).
- **Commit 8 size:** with the pressure hooks it has 736 code lines, above the 600-line guide.
- **#320 residue:** none in code. One test (xy16-near-indir-y.ll) carries a data layout string with `p2:32:8-p3:24:8`.
