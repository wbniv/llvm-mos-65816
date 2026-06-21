| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/9a7a899) | #321 native s16: fold a constant term into a threaded 16-bit add chain (a+b+c+K) |

<!--history-meta v1
9a7a899	author	Will Norris
9a7a899	added	82
9a7a899	deleted	0
9a7a899	files	1
9a7a899	body	A 16-bit add chain that includes a constant term (g = a+b+c+K, or the multi-use\nt = a+b+c+K) failed to fuse: collectAddChain required every leaf to be a near-abs\nload, so the constant broke the match and the whole chain fell back to the per-add\npath — round-tripping each partial sum through an Imag16 pair.\n\ncollectAddChain now folds constant leaves into one running immediate (ConstSum /\nHasConst out-params). A const leaf is rematerializable, so its use-count is\nirrelevant and it is never erased (the const check precedes the single-use gate that\nloads/adds still require). Both chain combiners fire when\nloads + (HasConst ? 1 : 0) >= 3 — so a+b+c (3 loads) and a+b+K (2 loads + const)\nfuse, while the 2-operand cases (a+b, a+K) stay on the alu16_abs/absld immediate\npath (disjoint). applyAddChain16/Ld append one trailing immediate operand; the\nselectors emit a final `clc; adc #imm` after the adc-abs chain. Threading is\npreserved end to end: lda a; clc; adc b; clc; adc c; clc; adc #K; sta — no\nintermediate round-trips. Covers both the store-rooted and multi-use forms.\n\nNew a16chainimm (store-rooted os = a+b+c+4 and multi-use t = a+b+c+0x105,\ncorpus_result==0x2569): disasm gate asserts adc #imm per chain (const folded in),\nadc abs per global term, and a low sta-zp count (threaded). MAME + bsnes-jg agree;\nthe no-const a16chain/a16chainld stay green. Full a16 suite (30 tests) + corpus 7/7\ngreen; -verify-machineinstrs clean; patch 0002 round-trips.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
