| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/dda6209) | #321 native s16: thread 16-bit AND/OR/XOR chains through A16 (bit_chain16) |

<!--history-meta v1
dda6209	author	Will Norris
dda6209	added	86
dda6209	deleted	0
dda6209	files	1
dda6209	body	A homogeneous >=3-term bitwise chain of near-abs globals (g = a & b & c, | , ^)\nfolded each operand per-op (and abs, via the load-fold) but round-tripped the\nrunning value through an Imag16 pair between every op. The add-chain machinery\n(Increment 1c + add_chain16_ld + the immediate-term fold) generalizes to the\nbitwise ops, which — unlike ADD — need no carry-init.\n\ncollectAddChain is generalized to collectAluChain(R, RootOpc, ...), parameterized\nby the chain operator with a per-op constant fold (combineChainConst). The working\nADD path is otherwise untouched (its callers pass G_ADD), so a bug in the new\nbitwise code can't affect add chains. New bit_chain16 (store-rooted) /\nbit_chain16_ld (multi-use, rooted on G_AND/G_OR/G_XOR) combiners build new\nopcode-parameterized pseudos G_BITCHAIN16_ABS / G_BITCHAIN16_ABSLD (op0 =\nstore-global/result, op1 = the bitwise opcode, then term globals + optional trailing\nconst). selectBitChain16 reads the opcode, maps to ANDAbs16/ORAAbs16/EORAbs16 (+ imm\nforms), and threads the value through A16 (lda t0; and|ora|eor t1; ...; sta) with no\nclc. SUB chains stay moot (the optimizer reassociates a-b-c to a-(b+c)).\n\nNew a16bitchain (store-rooted AND + XOR chains, multi-use OR chain,\ncorpus_result==0x6261): disasm gate asserts and/ora/eor abs per chain (globals read\ndirectly) and a low sta-zp count (threaded, no round-trip). MAME + bsnes-jg agree;\nthe add chains (a16chain/chainld/chainimm) stay green through the collectAluChain\ngeneralization. Full a16 suite (31 tests) + corpus 7/7 green; -verify-machineinstrs\nclean; patch 0002 round-trips.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
