#!/usr/bin/env python3
"""Write msgs/320-NN.txt. Each paragraph is one physical line (AGENTS.md)."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
FOOT = """Rebase preparation of the monolithic far-data patch: OpenAI Codex CLI 0.157.1 (session source vscode), model gpt-6-astra, xhigh reasoning effort; verified session 01a0e67f-298f-7a21-80af-06f867085f84. Implementation provenance remains in the source patches and investigations at wbniv/llvm-mos-65816 c3a53aecbc48. Split into this series: Claude Code 2.1.283 (t4-opus-high agent), model Claude Opus 5.5 (claude-opus-5-5), high reasoning effort.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HAKZG571yi9zqmAeWQZVtk
"""

M = {}

M[1] = ("[MOS] Add the far address space and 32-bit imaginary pointer quads", """
Add address space 2 for far data pointers: `p2:32:8` in the MOS data layout (TargetDataLayout and MOSTargetMachine) and AS_Far in MOS::AddressSpace. A far pointer is a 32-bit value whose low three bytes are the 65816 long address; 32 bits keep it a simple MVT, since there is no MVT::i24.

A runtime far pointer lives in an imaginary quad: RLk covers the Imag16 pairs RS(2k) and RS(2k+1), four consecutive zero-page bytes, through the new sublo16/subhi16 indices. The Imag32 class joins the register bank. A quad is named by its lowest __rc byte, which is where `[dp]` reads the address; it is reserved whenever either of its pairs is reserved (stack pointer, scavenger slot, frame pointer, or pairs outside the imaginary window); it copies as two Imag16 copies and costs four byte copies; and zero-page CSR allocation places all four bytes as one consecutive unit and records offsets for the quad, both pairs and all four bytes, so a relocated `[dp]` operand stays consistent with its byte definitions. Quads have no DWARF number; their byte and pair subregisters keep the existing mappings.

This commit defines the same register family (sublo16/subhi16, MOSImagReg32, RL#K, MOSReg32Class, Imag32) as open upstream PR #594 with a different register-number offset (0x600 here) and allocation policy (#594 keeps RL non-allocatable). It must be reconciled with #594 before submission; a #594-based rebase replaces this commit.

Default-mode effect: the data layout string gains p2:32:8 for every MOS CPU. Generated code for the fixed input set is identical in mos6502 and mosw65816 (assembly and objects).

Tests: imag32-copy.mir checks that a quad copy lowers to four byte copies in address order, with RL1 and RL2 naming __rc4-__rc7 and __rc8-__rc11. Nothing produces address space 2 values until the next commit.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/imag32-copy.mir`.
""")

M[2] = ("[MOS] Legalize and select far pointer values and memory accesses", """
Pass, legalize and select address-space-2 pointers and the byte loads and stores through them.

Calls: a far pointer argument is assigned to RL1-RL3 and its calling-convention type is i32; incoming 32-bit values are accepted. Legalization: p2 is legal for G_GLOBAL_VALUE, G_FRAME_INDEX and G_BLOCK_ADDR, converts to and from s32 with G_PTRTOINT/G_INTTOPTR, and takes s32 offsets in G_PTR_ADD, which always use the integer carry chain so the add carries into the bank byte. A p2 G_PHI becomes an s32 PHI, with casts placed before each predecessor's terminator and after the block's PHIs. Casting a near pointer to far zero-extends it (bank $00) without the zero-page bias used for direct-page pointers. A byte load or store through a constant or global far address becomes G_LOAD_FAR_ABS/G_STORE_FAR_ABS (absolute long, `lda $xxxxxx`); through a runtime far pointer it becomes G_LOAD_FAR_INDIR/G_STORE_FAR_INDIR (`lda [dp]`).

Selection: s32 register values use Imag32; a 2 x s16 merge composes an Imag32 with REG_SEQUENCE and an s32 unmerge splits it by word; the far address of a symbol (by address space, including aliases, not by section name) is built from MO_ADDR24_SEG_LO/_SEG_HI/_BANK immediates, which lower to the ADDR24 relocation modifiers; the far access pseudos pin their pointer operand to Imag32 so the cast chain coalesces into the quad `[dp]` reads. Allocation hints skip candidates whose width differs from the copy's other side. MOSLateOptimization's LDImm combining tracks only immediate loads into A, X or Y, and LDCImm treats any nonzero immediate as a set carry.

The 65816 reaches data outside bank DBR only through long addressing; a 16-bit pointer cannot name it.

Default-mode effect: none for code that compiled before: assembly and objects are identical in mos6502 and mosw65816. Five corpus inputs that use address space 2 fail in both default modes before and after this commit, with a different legalization error: without +mos-a16, the s32 merges and unmerges that far pointers need are not legal.

Tests: far-addressing.ll checks absolute-long and `[dp]` loads and stores in assembly and object bytes ($af/$8f/$a7/$87), and that a near symbol placed in a far section stays near. far-phi.ll checks the p2 PHI legalization and a `[dp]` load in the emitted loop.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/far-addressing.ll llvm/test/CodeGen/MOS/far-phi.ll`.
""")

M[3] = ("[MOS] Route far memory intrinsics to the far runtime", """
A G_MEMSET, G_MEMCPY or G_MEMMOVE with any address-space-2 pointer operand that is not expanded inline now calls __memset_far, __memcpy_far or __memmove_far. Near and direct-page pointer arguments are cast to far (bank $00 under the DBR=0 contract), so both pointers use the far-pointer ABI. The length argument is 16 bits: wider lengths are truncated and narrower ones zero-extended. The supported length domain is therefore 0-65535; longer lengths are not diagnosed.

The generic memory libcall would pass the far pointer to the near runtime and drop the bank byte, silently accessing the wrong bank.

Default-mode effect: none; only calls with far pointer operands change.

Tests: far-memset.ll checks a far constant fill over the inline limit and a variable-length far fill calling __memset_far, and a near variable fill still calling __memset.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/far-memset.ll`.
""")

M[4] = ("[MOS] Select bounded runtime [dp],Y indexing for far byte accesses", """
Fold an offset from a runtime far pointer into the 65816's `lda/sta [dp],y`, which adds Y to the full 24-bit address with carry into the bank. A constant displacement of 1-3 becomes an 8-bit Y constant. A runtime offset folds when its known-bits maximum plus the last accessed byte fits Y (8 bits, or 16 bits under +mos-xy16), every user of the pointer add is a non-atomic byte access or a constant non-negative displacement leading only to such accesses (so the 32-bit add disappears), the base is not an absolute address, no call can separate the add from its accesses, and a function with calls has only one such access. The offset keeps its own integer arithmetic; an 8-bit Y is preferred when the users fit it.

With a 16-bit Y, the index stays in an Imag16 pair until emission: LDIndirLongYIdx/STIndirLongYIdx are emitted as `ldy zp` directly followed by the access, so no spill code can insert a `sep #$10` that clears Y's high byte.

Default-mode effect: none; only far byte accesses change.

Tests: far-indir-indexed.ll covers 16-bit reads through a runtime far pointer and a far array subscript; constant displacements 1 and 3 (and 0 and 4, which are not folded); runtime byte offsets for loads, stores and a blit, with 8-bit and 16-bit (+mos-xy16) Y, masked, sign-extended and 16-bit-wrapping offsets; and the declining cases: unbounded 32-bit offsets, absolute bases, escaping pointers, calls between the add and its accesses, multiple accesses in a function with calls, and a sibling access out of range. It checks assembly and object bytes ($a7/$b7/$97) in +mos-a16 and +mos-a16,+mos-xy16 modes, and the fused pseudos after instruction selection.

Validate: `build/bin/llvm-lit -v llvm/test/CodeGen/MOS/far-indir-indexed.ll`.
""")

for k, (subj, body) in M.items():
    with open(os.path.join(HERE, f'320-{k:02d}.txt'), 'w') as f:
        f.write(subj + '\n' + body.rstrip('\n') + '\n\n' + FOOT)
print('wrote', len(M))
