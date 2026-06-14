| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/95df784) | #321 Inc 1d core: GISel-native 16-bit ADD — the allocator carries an s16 value |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/2eef05c) | #321 Inc 1d: core started + de-risked; turnkey continuation mapped |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/3e00947) | #321 Inc 1d: de-risk the GISel-native core (design + mechanism map) |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/0169001) | #321 Inc 1d step 1: Anyi16 register class (A16 + Imag16), the s16 sum type |

<!--history-meta v1
95df784	author	Will Norris
95df784	added	9
95df784	deleted	1
95df784	files	1
95df784	body	Beyond the fixed peephole shapes: under +mos-a16 the legalizer keeps an\ns16 G_ADD un-narrowed (gated on hasAccum16, so the corpus's 8-bit path is\nuntouched), and selectAdd16Native lowers it to ONE 16-bit adc on an\nImag16 pair. The s16 value lives in zero-page Imag16, A16 is transient,\nand copyPhysReg moves between them via new LDAImag16/STAImag16 (the\n16-bit analog of LD/STImag8, modeling the imaginary reg as the def). A\nmulti-use local intermediate — t = a+b; g=t; h=t; — which no peephole can\nfuse (result not single-use) compiles to a native 16-bit adc and reads\ncorpus_result == 0x1122 on BOTH MAME and bsnes-jg.\n\nPieces: Anyi16 (A16+Imag16) sum-type class (foundation, prior commit);\nLDAImag16/STAImag16/ADCImag16 zero-page 16-bit ops; the legalizer gate;\ncopyPhysReg Ac16<->Imag16; the selectAdd16Native dispatch+impl.\n\nNon-breaking: corpus 7/7, all six peephole tests (add/sub/bit/imm/chain +\n1a) green — the native and peephole paths coexist; SDK builds. Finding:\na MachineLICM getRegClassWeight crash traced to the result vreg landing\nin the unconstrained 'any' regbank class — fixed by constraining it to\nImag16. New dev/run.sh a16local + examples/65816/a16local.c. Patch 0002\nregenerated (round-trip verified).\n\nThis is the first codegen where the GISel allocator manages a 16-bit\nvalue across code, not a fixed peephole shape — the general path works.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
2eef05c	author	Will Norris
2eef05c	added	26
2eef05c	deleted	5
2eef05c	files	1
2eef05c	body	Went deep into the GISel-native core and confirmed: (1) it's tractable —\nthe copyPhysReg B-register fear dissolves because one 16-bit lda/sta zp\nmoves both bytes of A16=B:A atomically (A16<->Imag16 = LDAImag16/STAImag16,\nthe 16-bit analog of LD/STImag8); (2) it's corpus-safe — gated on\nSTI.hasAccum16() so default builds keep the 8-bit narrowing. Reverted the\npartial WIP to keep the tree green (a half-built big-bang would leave\n+mos-a16 adds that escape the peephole unselectable). The plan now lists\nthe exact remaining pieces (new transfer instrs + their MC lowering,\nlegalizer gate, copyPhysReg Ac16<->Imag16, selectAdd16Native) as a\nturnkey continuation.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3e00947	author	Will Norris
3e00947	added	37
3e00947	deleted	0
3e00947	files	1
3e00947	body	Record the key design decision from investigating copyPhysReg: keep s16\nVALUES in Imag16 (zero-page pairs, already fully supported) and use A16\nonly transiently within each selected op (lda zp; adc zp; sta zp) — this\nsidesteps the B-register problem (A16's high byte isn't independently\naddressable). Map the cohesive core to exact files/functions: the\nlegalizer must keep s16 G_LOAD/G_STORE/G_ADD un-narrowed together, and\nselectAddSub's load-folding (m_FoldedLdAbs/...) gets s16 mirrors\n(ADCAbs16 + a new ADCImag16). Flag the corpus as the non-negotiable\nguard since this re-routes ALL s16 codegen (unsigned short is s16\neverywhere), making the core a big-bang.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
0169001	author	Will Norris
0169001	added	61
0169001	deleted	0
0169001	files	1
0169001	body	Start the GISel-native 16-bit phase: add Anyi16 = A16 (the 16-bit\naccumulator) + Imag16 (zero-page pointer pairs) as the sum type of all\n16-bit storage — the s16 analog of Anyi8 = Imag8 + GPR. A generic s16\nvalue will live here: in A16 while it is the ALU operand/result, spilled\nto an Imag16 pair otherwise (there is only one A16).\n\nInert until the s16-native legalizer/selector emit Anyi16 vregs. Verified\nnon-breaking — the key guard for this phase since A16 aliases the 8-bit A:\ncorpus 7/7, SDK builds. Plan + decomposition in\ndocs/plans/2026-06-14-321-increment-1d-gisel-native-s16.md.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
