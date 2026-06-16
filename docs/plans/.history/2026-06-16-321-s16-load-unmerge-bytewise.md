| Date | Change |
|------|--------|
| [2026-06-16](https://github.com/wbniv/llvm-mos-65816/commit/8bce630) | #321 s16-load-unmerge: record verification PASS + triage the deferral Inbox |
| [2026-06-16](https://github.com/wbniv/llvm-mos-65816/commit/7c0fe56) | #321 native s16: load consumed only as bytes stays byte-wise (EQ-as-value prologue fix) |

<!--history-meta v1
8bce630	author	Will Norris
8bce630	added	10
8bce630	deleted	5
8bce630	files	1
8bce630	body	Record the all-PASS verification results into the plan (the audit hook flagged the\nVerification section as unrecorded): operands load byte-wise (no rep prologue) +\nverify clean; a16eqval 0x0101 host==default==a16 on MAME+bsnes; suite 42/42, corpus\n7/7, fuzz 50/50; 0002 round-trips.\n\nTriage the six auto-captured Inbox deferrals — all already live in curated M2 items\n(the full-native-EQ + indirect-load follow-ups in the EQ-as-value bullet; the three\nsoft-stack-coverage notes in the soft-stack bullet) — and clear the Inbox.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
7c0fe56	author	Will Norris
7c0fe56	added	59
7c0fe56	deleted	0
7c0fe56	files	1
7c0fe56	body	Investigating M2 item (c) (native s16 equality-as-value, `b = (a == c)`) surfaced\na +mos-a16 REGRESSION: the s16 operand loads were emitted as native 16-bit\nG_LOAD16_ABS (`lda abs -> A16; sta imag16`) and then the 8-bit-narrowed compare\nG_UNMERGEd them straight back into bytes — a wasteful 16-bit-load -> spill ->\nre-read round-trip the default build never does (it loads the bytes directly).\nSo +mos-a16 EQ-as-value was strictly worse than default.\n\nFix (MOSLegalizerInfo::legalizeLoadStore16): when every use of an s16 LOAD is\nG_UNMERGE (the value is only ever split into bytes), skip the native 16-bit\nG_LOAD16_ABS and fall back to the existing byte-wise narrowScalar — exactly the\ndefault codegen. A value used only byte-wise should be loaded byte-wise. Stores\nare unaffected; the indirect-load variant is left native (a TODO follow-up).\n\nResult: `b = (a == c)` now loads its operands with direct 8-bit ldx/lda + cmp/cpx\n(no rep-bracketed prologue before the compare) — back to parity with default. The\nfull native equality-as-value (one rep/lda/cmp/sep + materialize Z->0/1) needs a\nfused compare-SELECT mechanism the backend lacks (every flag-as-value path is\ncarry-based; N/Z are only branch-fused) and stays deferred — recorded as a\ndedicated M2 TODO with the CmpSelImag16 design sketch.\n\nRegression test: examples/65816/a16spill... examples/65816/a16eqval.c +\ndev/a16eqval.sh — corpus_result == 0x0101 host == default == +mos-a16 on MAME +\nbsnes-jg, plus a no-prologue disasm gate (the first 8-bit compare must precede any\nrep #$20, proving byte-wise operand loads).\n\nVerification (quiet box): repro disasm byte-wise + verify clean; a16 suite 42/42\n+ a16eqval; corpus 7/7; fuzz 50 1 -> 50/50, 0 xfail; 0002 round-trips.\n\nAlso carries the soft-stack-spill-coverage follow-up docs (TODO item + plan)\ndocumenting the fuzzer-coverage gap the earlier F3 soft-stack fix exposed\n(gen_funcs emits only leaf functions, so the fuzzer never reaches a soft-stack\nAc16 spill) — deferred work, not implemented here.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
