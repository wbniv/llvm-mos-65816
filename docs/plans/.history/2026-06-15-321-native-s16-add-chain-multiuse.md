| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/609c6c4) | #321 native s16: thread multi-use 16-bit add chains through A16 (add_chain16_ld) |

<!--history-meta v1
609c6c4	author	Will Norris
609c6c4	added	81
609c6c4	deleted	0
609c6c4	files	1
609c6c4	body	A >=3-term 16-bit add chain of near-abs globals whose result is REUSED\n(t = a+b+c+d; g=t; h=t; corpus_result=t) couldn't be reached by add_chain16,\nwhich is rooted at a G_STORE and requires every node (incl. the chain result)\nsingle-use. So the multi-use chain folded each global per-add (adc abs, via the\nearlier load-fold) but round-tripped the running sum through an Imag16 pair between\nevery add (... adc abs b; sta tmp; lda tmp; clc; adc abs c; ...) — N-2 wasted\nsta/lda pairs.\n\nNew add_chain16_ld combiner (rooted on G_ADD) handles the multi-use register\nresult, mirroring how alu16_absld extended alu16_abs: fire on a G_ADD whose s16\nresult is multi-use, collect the chain via the existing collectAddChain over the\nroot's two operands (single-use interior + leaves; only the root may be multi-use),\n>=3 terms. Disjoint from add_chain16 (single-store result) and alu16_absld\n(2-operand: a >=3 chain root has an interior-G_ADD operand). Produces a new\nG_ADDCHAIN16_ABSLD pseudo (register result, no store); selectAddChain16Ld threads\nthe sum through A16 (lda t0; clc; adc t1; ...; sta dst-Imag16) — no intermediate\nround-trips. Completes all load-fold follow-ups (a/b/c).\n\nNew a16chainld (4-term chain, result stored 3x, corpus_result==0x1234): disasm gate\nasserts adc abs per term and that the sum stays in A16 (sta zp count 1, not 3).\nMAME + bsnes-jg agree. Full a16 suite (29 tests) + corpus 7/7 green;\n-verify-machineinstrs clean; patch 0002 round-trips.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
