| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/ef4671d) | #321 native s16: fold near-abs global operands into the 16-bit compare (lda abs; cmp abs) |

<!--history-meta v1
ef4671d	author	Will Norris
ef4671d	added	117
ef4671d	deleted	0
ef4671d	files	1
ef4671d	body	A global-vs-global s16 compare (a < gv, a >= gv) materialized BOTH operands into\nImag16 pairs first — lda abs; sta tmp (x2), then lda tmp; cmp tmp — six pre-branch\nops. selectSbc16 now recognizes a single-use near-abs G_LOAD16_ABS operand (new\nfoldableAbsLoad16 helper) and reads it directly: the LHS via lda abs (existing\nLDAbs16), the RHS via cmp abs (existing CMPAbs16). Each compare becomes\nrep; lda abs; cmp abs; sep; bcc/bcs with no Imag16 round-trip and no cmp zp.\n\nThe fold is volatile-safe (1-to-1: exactly one read of each global, in program\norder — the same property selectAlu16AbsLd relies on), so it does NOT gate on\nshouldFoldMemAccess (which rejects volatile). Same-BB only. Signed compares feed\nXOR'd operands so they stay on the Imag16 path; the equality CmpBr*16 branch path\n(a possible CmpBrAbs16) is a separate follow-up.\n\nNew test a16abscmp (all-global unsigned ordering, corpus_result==0x4303): disasm\ngate asserts cmp abs present, zero cmp zp, zero cpx/cpy; MAME + bsnes-jg agree.\nFull a16 suite (23 tests) + corpus 7/7 green on both emulators;\n-verify-machineinstrs clean; patch 0002 round-trips.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
