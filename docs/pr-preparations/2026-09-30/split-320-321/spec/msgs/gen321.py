#!/usr/bin/env python3
"""Write msgs/321-NN.txt. Each paragraph is one physical line (AGENTS.md)."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
FOOT = """Extraction of the monolithic native-width patch: OpenAI Codex CLI 0.158.0 (codex-tui), model gpt-6-astra, xhigh reasoning effort; verified session 01a0e75a-a9ed-7372-9bac-b19b732a46a2. Split into this series: Claude Code 2.1.283 (t4-opus-high agent), model Claude Opus 5.5 (claude-opus-5-5), high reasoning effort.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HAKZG571yi9zqmAeWQZVtk
"""

M = {}

M[1] = ("[MOS] Model 65816 native-width registers and feature gates", """
Add two opt-in subtarget features for the WDC 65816: mos-a16 selects 16-bit accumulator codegen, and mos-xy16 selects 16-bit index registers and implies mos-a16. No CPU implies either feature.

The 65816 widens A to 16 bits when the M status bit is clear and X/Y when the X bit is clear. The high accumulator byte B, and the high index bytes, alias the 8-bit registers the backend already models. Add A16 (A:B), X16 (X:XH) and Y16 (Y:YH) as registers covered by their byte halves, so liveness and allocation see a 16-bit value in A16 as clobbering $a and the reverse. The full registers carry the MOS native-mode DWARF numbers 0x01000000-0x01000002; the internal high bytes have no DWARF number. Single-member classes Ac16, Xc16 and Yc16 give later commits allocation targets, and Ac16 joins the register bank. Nothing selects these registers yet.

Default-mode effect: none (fixed input set identical in mos6502 and mosw65816). Ac16, Xc16 and Yc16 set GeneratePressureSet = 0, so the generated register pressure tables are the parent's. Without it, TableGen derives pressure sets from the new classes (Ac16, Xc16 and Yc16 sets appear and MOSAsmParamRegClass stops being a separate set), and because MachineLICM, MachineSink and the machine scheduler read those tables in every mode, 18 of 54 compiling mos6502 inputs and 33 of 78 mosw65816 inputs in the fixed input set would change (+3,478 and +3,202 bytes). Native values get their pressure modelling where they are first selected.

Tests: native-width-registers.mir checks that both features are recognized and that the Ac16, Xc16 and Yc16 classes and the A16, X16 and Y16 registers parse and verify, with sublo naming the existing byte register. native-width-default-pressure.ll pins default mos6502 and mosw65816 code for a three-way compare whose low-byte subtraction the scheduler moves when the native classes have pressure sets; it passes on the parent and guards this commit.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/native-width-registers.mir llvm/test/CodeGen/MOS/native-width-default-pressure.ll`.
""")

M[2] = ("[MOS] Define 16-bit accumulator instruction forms", """
Define the pseudo instructions that carry a 16-bit value through the accumulator, gated on HasAccum16. The 65816 uses the same opcode bytes for 8- and 16-bit accumulator operations; the width is processor state. Codegen therefore needs distinct pseudos, so that allocation, liveness and a later REP/SEP pass know which width an operation requires. Each pseudo expands to the existing width-agnostic MC instruction.

The forms are word loads and stores (absolute, abs,X, (zp), (zp),Y and Imag16), ADC/SBC/AND/ORA/EOR with absolute, Imag16 and immediate operands, CMP against Imag16, absolute, (zp) and immediate operands, and ASL/LSR/ROR/INC/DEC on the accumulator. Values enter A16 only through word loads and leave only through word stores; there is no COPY between Ac16 and a byte class, which could otherwise coalesce registers of different widths.

MOSLogicalInstr gains the MLow TSFlag at the bit position the MC instruction formats already use, so a pass that runs before MC lowering can read the required accumulator width from a pseudo.

A 16-bit immediate now prints as mos16(value) when the value would fit an 8-bit immediate. The assembler has no M-flag state, so a bare `adc #66` reassembles to the two-byte form; with M clear the processor would then take the next opcode as the immediate's high byte. Values above 255 print unchanged.

Default-mode effect: none in the fixed input set (assembly and objects identical in mos6502 and mosw65816). Default codegen emits no 16-bit immediates.

Tests: a16-accumulator-forms.mir emits a sequence of these pseudos from MIR and checks the expanded instructions, the mos16() printing of small immediates (and bare printing above 255), and the three-byte immediate encodings in the object. a16-immediate-width.ll (in the compare commit) checks the printing on selected code.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/a16-accumulator-forms.mir`.
""")

M[3] = ("[MOS] Define 16-bit index instruction forms and X-width requirements", """
Define the index-width pseudos, gated on HasIndex16: A loads and stores through abs,X and (zp),Y with a 16-bit index (8- and 16-bit data), LDX/LDY/STX/STY/CPX/CPY with absolute, Imag16 and immediate operands, INX/DEX/INY/DEY, the TXA/TAX/TYA/TAY transfers used to stage an index register through A16, and PHA16/PLA16 for preserving A16 around such staging. MOSLogicalInstr gains the XLow and XHigh TSFlags at the MC bit positions.

The existing 8-bit LDX, STX, LDY, STY, CPX and CPY zero-page and absolute forms are marked XHigh: they require 8-bit index registers. A REP/SEP pass needs this to narrow X before them, because with X clear they would read or write two bytes.

Default-mode effect: assembly is unchanged. MOSMCELFStreamer emits $xh mapping symbols from the XHigh flag on W65816 objects, so mosw65816 objects gain $xh symbols before these instructions: 68 of 90 mosw65816 objects in the fixed input set differ, with identical section bytes and relocations (for example 667 to 1,121 $xh symbols in examples_snes_boids). mos6502 objects are identical.

Tests: index-width-mapping-65816.s assembles each XHigh form after a 16-bit `ldx` and checks that each opens its own $xh mapping region. xy16-index-forms.mir emits the index pseudos from MIR and checks the expanded instructions and the three-byte index immediates in the object.

Validate: `build/bin/llvm-lit -v llvm/test/MC/MOS/index-width-mapping-65816.s llvm/test/CodeGen/MOS/xy16-index-forms.mir`.
""")

M[4] = ("[MOS] Insert REP/SEP from M/X width requirements", """
Add MOSInsertREPSEP, which runs in addPreEmitPass before branch relaxation, so relaxation accounts for the inserted instructions. It is a no-op without +mos-a16.

Each instruction's required accumulator and index widths come from the MLow/MHigh/XLow/XHigh TSFlags. A forward dataflow over the CFG propagates M and X state; function entry, calls and returns require the 8-bit ABI state. Width changes are placed at transitions, so a loop body can stay in 16-bit mode, and a combined `rep/sep #$30` is used when both flags change together. Carry initialization is width-agnostic and does not split a bracket. A switch needed on a critical edge is placed at the target block's entry. When narrowing X would destroy a live 16-bit index value, the pass saves X16 on the hardware stack below the bytes the region consumes and restores it after, preserving A and P with an A16 courier. The pass also fuses two adjacent `stz g`/`stz g+1` into one 16-bit `stz g`.

The 65816 executes these instructions correctly only in the width they were emitted for, and the assembler cannot track M/X state, so the compiler must place every REP and SEP.

Default-mode effect: none (the pass returns immediately without +mos-a16; fixed input set identical).

Tests: insert-rep-sep-cloned-kills.mir checks that narrowing X preserves the 16-bit X value itself, without re-executing its writer, when the source was killed or overwritten, the writer is an increment, Y widens before an X reader, a byte definition ends the value, and N/Z are live. insert-rep-sep-stack.mir checks that the saved X word sits below the bytes a region pushes or pulls, for byte and word stack operations and live N/Z, and emits an object.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/insert-rep-sep-stack.mir llvm/test/CodeGen/MOS/insert-rep-sep-cloned-kills.mir`; `build/bin/llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -o - <<< '@g = global i16 1 define void @f() { store i16 0, ptr @g ret void }'` prints `rep #32; stz g; sep #32`.
""")

M[5] = ("[MOS] Preserve status flags across register scavenging", """
Let the register scavenger preserve a live processor status register. On a balanced hard-stack range it saves P with PHP and restores it with PLP. On an unbalanced range, when the target has PHX/PHY and a dead index register exists at both ends, it moves P through that register into the reserved RC17 slot (`php; plx; stx rc17` and `ldx rc17; phx; plp`), each half stack-neutral. The PHP operand is marked undef when no part of P holds a defined value, matching the verifier's rule that any defined sub-register makes the composite defined. Any other case stops with a fatal error.

The scavenger borrows $c, a sub-register of $p, for frame-index carries. Native 16-bit compare and ALU chains keep N, Z or C live across such a materialization, so N and Z cannot be assumed dead at a scavenge point, and the scavenger does not assert it. A and Y keep their existing save paths; P no longer shares them.

Default-mode effect: none in the fixed input set. The P paths apply to every CPU: on mos6502 at -O0, a frame over 255 bytes with carry live across a spill reload no longer stops on the N/Z assertion.

Tests: scavenger-p-undef-6502.ll (reduced from gcc.c-torture strlen-4.c, from the downstream tree's tests) compiles at -O0 on mos6502 through prologue/epilogue insertion with the verifier on, and checks both a `PH undef $p` where no status bit holds a value and a plain `PH $p` where carry is live. The parent commit fails it with the N/Z assertion.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/scavenger-p-undef-6502.ll`.
""")

M[6] = ("[MOS] Spill and copy native-width registers", """
Give each native-width register class explicit copy and spill lowering. Copies between Xc16/Yc16 and an Imag16 pair use `ldx/ldy zp` and `stx/sty zp`. Static-stack spills of Ac16, Xc16 and Yc16 use one word absolute load or store. Soft-stack spills of Ac16 use one word `lda/sta (zp)` through the exact slot pointer; a nonzero offset first forms that pointer in the reserved scratch pair, because (zp) addressing has no index. X16 and Y16 are staged through A16 (`txa; sta (zp)` and `lda (zp); tax`), and the expansion is bracketed by PHA16/PLA16 when the accumulator is live across it. pushPullBalanced counts PHA16/PLA16 as one matched push and pull.

The byte fall-through in both spill paths can represent only 8-bit classes: the high byte of A16, X16 or Y16 has no byte register of its own. Without these cases a spilled 16-bit register would lose its high byte.

Default-mode effect: none (fixed input set identical); the new paths apply only to the native classes.

Tests: native-spill-copy.mir checks A16 soft-stack spills at offset zero and at a formed nonzero-offset pointer, an X16 spill and reload staged through A16 inside PHA16/PLA16 while A16 is live, and X16/Y16 copies to and from Imag16 pairs.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/native-spill-copy.mir`.
""")

M[7] = ("[MOS] Keep call-clobbered imaginary copies out of Imag16 pairs", """
Refuse to coalesce a sub-register copy into an Imag16 pair when one side is a virtual register whose only definition is `COPY $rcN` and that register is live across a call whose regmask clobbers $rcN. The pair would inherit the $rcN allocation hint and could be re-bound to $rcN across the clobbering call, leaving a use with no reaching definition that the machine verifier rejects. Keeping the COPY gives the value its own spillable register.

The guard needs all three conditions, so ordinary coalescing is unaffected. Native s32 values are built from s16 lanes, which makes Imag16 pairs assembled from call results common under +mos-a16.

Default-mode effect: none in the fixed input set. The hook runs for every CPU.

Tests: coalesce-call-clobbered-imag.mir runs the register coalescer on byte COPYs of $rc2/$rc3 that build an Imag16 pair: across a second call they stay separate registers, and without that call they coalesce into the pair. The parent commit folds $rc2/$rc3 into the pair across the call.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/coalesce-call-clobbered-imag.mir`.
""")

M[8] = ("[MOS] Legalize and select native 16-bit loads and stores", """
Under +mos-a16, s16 G_LOAD and G_STORE are legalized before byte narrowing. An absolute address becomes G_LOAD16_ABS/G_STORE16_ABS. An absolute or runtime base with an 8-bit variable index, or a runtime pointer with a constant offset of 1-255, becomes an abs,X or (zp),Y word access. Any other runtime pointer on a 65C02-class CPU becomes G_LOAD16_INDIR/G_STORE16_INDIR. The selector lowers these to the word pseudos and moves the value between A16 and its Imag16 pair; a single-use word load feeding a store is folded straight into the store's accumulator load.

Accesses stay on the byte path where the native form costs more: constant-valued stores, loads whose every use splits the value into bytes, stores of values built from bytes in the same block with no call or inline assembly in between, and indirect stores of an A:X argument. Atomic accesses remain a single operation.

These are the first native values, and Ac16, Xc16 and Yc16 have no generated pressure sets, so MOSRegisterInfo now takes the subtarget and the optimization level and overrides the pressure-set hooks. Under +mos-a16, each native class counts toward its low byte's generated sets (Ac16 toward Ac's). Below -O3, the hooks also append the sets A16, X16 and Y16, each with a limit of 2, charged by the 16-bit register's byte units and by the classes inside it (Ac and Ac16 for A16). The scheduler, MachineLICM and MachineSink then see that an 8-bit value live across a 16-bit one competes for the same register. On the fixed input set at the end of this series, the appended sets save 78 bytes with +mos-a16 and 162 bytes with +mos-a16,+mos-xy16 at -Os, but cost about 0.2% of cycles at -O2 and -O3, so -O3 (CodeGenOptLevel::Aggressive) leaves them out. The choice is made once, when the subtarget is built, because RegisterClassInfo caches set limits per register info. Without +mos-a16 every hook returns the generated tables.

Default-mode effect: none (fixed input set identical).

Tests: a16-load-store.ll checks one rep/sep-bracketed word load and store for absolute, (zp) and (zp),y (runtime and constant index) addresses, and a constant store kept as two byte stores. a16-byte-store.ll and a16-indirect-byte-store.ll, which pin the byte-versus-native store decisions, need native arithmetic results next to the stores and land with it. native-width-pressure-opt-level.ll (assertions builds) checks the scheduler's pressure sets for a word copy: the A16 set at -O2, and only the low byte's sets at -O3.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/a16-load-store.ll llvm/test/CodeGen/MOS/native-width-pressure-opt-level.ll`.
""")

M[10] = ("[MOS] Select native 16-bit arithmetic, logic and constant shifts", """
Under +mos-a16, s16 G_ADD, G_SUB, G_AND, G_OR and G_XOR stay legal, and s16 shifts by a constant 1-7 are left un-narrowed. The selector emits `lda; [clc|sec]; op; sta` on the Imag16 operands. A second operand that is a constant (recovered from a byte-split G_MERGE_VALUES if needed) uses the immediate form. A single-use absolute load in the same block, with no call, unmodeled side effect, ordered store or possibly aliasing store in between, is read directly by `lda abs` or `op abs`. Adding or subtracting one becomes `inc a`/`dec a`. Shifts emit one `asl a` or `lsr a` per bit; arithmetic right shift emits `cmp #$8000; ror a` per bit, because the 65816 has no arithmetic shift right and the compare copies the sign into carry. Shifts by 8 or more keep the byte path, which relabels bytes at no cost.

Each selected operation stores its result to an Imag16 home. After register allocation, MOSLateOptimization removes a `lda rsN` that reloads the home just written by `sta rsN` from A16, when nothing in between writes A16 or the home and no call or inline assembly intervenes; the store goes too when the reload killed the home and nothing else read it, and A16 kill flags in the extended range are cleared. Without this, a chain of word operations stores and reloads every intermediate result. Running after allocation keeps byte values from coalescing into A16.

Default-mode effect: none (fixed input set identical).

Tests: a16-byte-store.ll and a16-indirect-byte-store.ll check the store policy from the load/store commit with native producers present: argument, returned, volatile, byte-built and A:X values keep byte stores in default, +mos-a16 and +mos-a16,+mos-xy16 modes, while a native sum is stored by the word store directly after its `adc`, which needs the residency peephole. The immediate forms are checked by a16-immediate-width.ll in the next commit.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/a16-byte-store.ll llvm/test/CodeGen/MOS/a16-indirect-byte-store.ll`.
""")

M[11] = ("[MOS] Select native 16-bit compares and fused branches", """
Under +mos-a16, s16 unsigned ordering (UGE, and ULT through it) becomes one 16-bit G_SBC whose carry the branch reads, selected as `lda; cmp` with immediate, absolute, (zp) or Imag16 right operands. Signed less-than is rewritten to unsigned less-than on sign-flipped operands, (a ^ 0x8000) <u (b ^ 0x8000). Equality uses the native form when it feeds a branch or when both operands are already in Imag16, come from foldable absolute loads, or pair a foldable load with a nonzero constant; other equality compares keep the byte chain, which is cheaper for register-resident operands. A branch on native equality becomes a fused CmpBr pseudo (Imag16/immediate/absolute operand combinations) that expands after allocation to `lda; cmp; b<cc>`. The 8-bit compare matchers reject 16-bit G_SBC.

Supporting changes: analyzeBranch accepts compare-branches with two memory operands and treats any volatile one as a barrier; eliminateFrameIndex decides where a frame-index displacement lives by opcode, because the operand after CmpBrAbsImm16's address is its compare immediate, not a displacement. A 16-bit arithmetic shift right by whole bytes fills the sign byte with a byte shift instead of a signed compare, so it does not request another native comparison.

Default-mode effect: none (fixed input set identical).

Tests: a16-immediate-width.ll checks `adc #mos16(66)`, `eor #mos16(255)`, the unmarked `adc #43981`, and `cmp #mos16(5)` followed by genuine 8-bit immediates after `sep #32`.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/a16-immediate-width.ll`.
""")

M[9] = ("[MOS] Legalize native s32/s64 lanes and wide any-extensions", """
Under +mos-a16, an s32 value is represented as two s16 lanes and an s64 value as two s32 halves: G_ANYEXT to s32 from s8/s16 and G_TRUNC from s32 to s16 are legal, G_MERGE_VALUES/G_UNMERGE_VALUES between s32 and 2 x s16 and between s64 and 2 x s32 are legal, and the four-piece forms (4 x s8 <-> s32, 4 x s16 <-> s64) are split into those two-level forms, because the selector handles only two-part merges. Extensions to s64 are custom.

In every mode, G_ANYEXT from a source that is not 1, 8, 16 or 32 bits wide now lowers through G_ZEXT instead of being unsupported; an any-extension may zero-fill its high bits.

Default-mode effect: none in the fixed input set. The any-extension rule applies to every CPU, but only to source widths that were previously rejected.

Tests: anyext-wide.mir checks wide extensions at legalization in default, +mos-a16 and +mos-a16,+mos-xy16 modes, including a shift libcall consuming the low bytes. anyext-masked-byte.ll checks that a masked byte store's s8 to s64 extension lowers in all three modes. Both also pass before this commit; they guard the new rules, This commit precedes native arithmetic because, without these rules, native s16 arithmetic leaves an s64 to 4 x s16 G_UNMERGE_VALUES that cannot be legalized (anyext-masked-byte.ll fails under +mos-a16).

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/anyext-wide.mir llvm/test/CodeGen/MOS/anyext-masked-byte.ll`.
""")

M[12] = ("[MOS] Keep byte indexes byte-wide in absolute indexed addressing", """
In absolute indexed addressing, an index that is already s8 (a zero-page pointer offset) is used directly. An s16 index known to fit in 8 bits is truncated for the access, and its other users are rewritten to an explicit G_MERGE_VALUES of the low byte and a zero byte, inserted after the definition (after the PHIs for a PHI), with the legalizer observer notified around each rewrite so GISel CSE stays consistent.

Both lanes of the shared s16 offset stay explicitly defined: under native widths that value can reach a word spill or a word consumer, which reads both bytes.

Default-mode effect: yes, in every mode. legalizer.mir drops a COPY of the s8 index in two zero-page tests, and the high byte of a shared offset becomes a known zero. In the fixed input set 16 of 54 compiling mos6502 inputs and 18 of 78 mosw65816 inputs produce different assembly; code size changes by +243 bytes on mos6502 (12 inputs larger, 3 smaller) and -102 bytes on mosw65816 (17 smaller).

Tests: zp-byte-index.ll checks zero-page indexed loads and stores in mos6502, +mos-a16 and +mos-a16,+mos-xy16 modes; legalizer-indexed-offset-observer.mir checks the rewritten operands and the CSE observer contract (assertions builds); legalizer.mir is updated.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/zp-byte-index.ll llvm/test/CodeGen/MOS/legalizer-indexed-offset-observer.mir llvm/test/CodeGen/MOS/legalizer.mir`.
""")

M[13] = ("[MOS] Require a no-wrap proof before folding near indexes on the 65816", """
On the 65816, indexed addressing adds the index to the 16-bit base with carry into the bank (DBR), while a near G_PTR_ADD wraps at 16 bits. Folding the add into abs,X, abs,Y or (zp),Y is correct only if the unsigned sum cannot wrap. canFoldNearIndex allows the fold when the add is nuw, when it is nusw with a known non-negative offset, or when known bits bound base + offset below 0x10000. Other CPUs are unaffected. The check applies to the native word forms and to the existing byte abs-indexed (except zero page) and indirect-indexed folds.

Default-mode effect: yes, on plain mosw65816 when an index cannot be proven not to wrap; mos6502 is unchanged. In the fixed input set 27 of the 78 mosw65816 inputs that compile before change (26 larger, 1 smaller, +4,620 bytes, 1.6%), because a byte index into a runtime pointer now needs a 16-bit add. One corpus input (examples_snes_sodo) that already fails on the base commit with "Remaining virtual register" during frame lowering compiles after this change; the change avoids that shape rather than repairing it.

Tests: near-index-nowrap.ll checks, on mos6502 and mosw65816, a plain add (folded only on mos6502), nuw and inbounds non-negative adds (folded on both), a global base (folded only on mos6502) and a constant base whose known bits bound the sum (folded on both).

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/near-index-nowrap.ll`.
""")

M[14] = ("[MOS] Select 16-bit index registers under +mos-xy16", """
Under +mos-xy16, s16 index values use 16-bit X and Y. The legalizer keeps an s16 offset as a 16-bit index in the word and byte abs,X and (zp),Y folds (G_LOAD_ABS_IDX16 and related opcodes), and constrains an absolute s16 load to Xc16 when every use can consume X directly: word stores, +/-1, compares, and PHI/COPY chains of those. selectXY16 selects direct LDX/STX/LDY/STY, INX/DEX/INY/DEY, CPX/CPY and the 16-bit-index accesses. A loaded index whose only users are copies is not a genuine index: it is reclassed to Imag16 and loaded through A16, because an unrelated 8-bit-index instruction's `sep #$10` would clear a live X/Y high byte.

A (zp),Y access whose index sits in an Imag16 pair uses a fused pseudo that the assembly printer emits as `ldy zp` immediately followed by the access. Keeping the pair in one instruction until emission prevents spill code from placing a `sep #$10` between them.

Default-mode effect: none (fixed input set identical).

Tests: xy16-near-indir-y.ll checks the fused byte and word (zp),Y loads and stores after instruction selection and in the emitted assembly.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/xy16-near-indir-y.ll`.
""")

M[15] = ("[MOS] Keep small 8-bit adds relocatable under +mos-a16", """
Under +mos-a16, an 8-bit add or subtract of 2 selects as two G_INC/G_DEC steps constrained to Anyi8 instead of `clc; adc #2`, whose operand is pinned to A.

A counter pinned to A that stays live across a 16-bit indexed-load transit (Ac16, which covers A) can deadlock greedy allocation: the counter cannot be recolored off its single register, and the single-instruction Ac16 transit cannot be spilled. An Anyi8 counter can live in X, Y or zero page. The step limit keeps the chain no larger than `clc; adc`. The result is the same modular value.

Default-mode effect: none (gated on +mos-a16; fixed input set identical).

Tests: a16-small-add.ll checks that +2 and -2 become two `inx`/`dex` under +mos-a16, that +3 keeps `adc`, and that the default mode keeps `adc` for all three. It checks the selection, not the allocation failure itself, which needs a larger function.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/a16-small-add.ll`.
""")

M[16] = ("[MOS] Preserve interrupted M/X state in 65816 interrupt handlers", """
A native-mode 65816 interrupt inherits M, X, D and DBR from the interrupted code, and user code may have changed D or DBR with inline assembly. Interrupt handlers on the 65816 now save A, X and Y at a fixed 16-bit width, save DBR and D, and establish the C ABI state before any compiled code runs: `rep #$30; pha; phx; phy; phb; phd; pea 0; pld; phk; plb; sep #$30`. The epilogue restores D, DBR, Y, X and A at 16-bit width in reverse order, and RTI restores the stacked P with the interrupted M/X state. `phk; plb` sets DBR to 0 from PBR, which interrupt entry forces to 0.

Default-mode effect: yes, for functions with the "interrupt" attribute on mosw65816, with or without +mos-a16; other functions and other CPUs are unchanged. In the fixed input set exactly the three tests with interrupt handlers (nonreentrant.ll, static-stack.ll, zp-alloc.ll) change on mosw65816 (+110 bytes in total; each handler gains a 15-byte prologue and a 7-byte epilogue sequence).

Tests: interrupt-width-65816.ll checks the prologue and epilogue on plain mosw65816.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/interrupt-width-65816.ll`.
""")

# Commits that carry the native-width pressure-set change.
PRESSURE = "Native-width pressure sets: Claude Code 2.1.285 (t4-opus-high agent), model Claude Opus 5.5 (claude-opus-5-5), high reasoning effort."
PRESSURE_SESSION = "Claude-Session: https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F\n"

for k, (subj, body) in M.items():
    foot = FOOT
    if k in (1, 8):
        head, trailers = FOOT.split('\n\n', 1)
        foot = head + ' ' + PRESSURE + '\n\n' + trailers + PRESSURE_SESSION
    with open(os.path.join(HERE, f'321-{k:02d}.txt'), 'w') as f:
        f.write(subj + '\n' + body.rstrip('\n') + '\n\n' + foot)
print('wrote', len(M))
