| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/cbc31da) | #320 Inc 3c: far-pointer arithmetic (fp++ / G_PTR_ADD on AS2) — Inc 3 complete |

<!--history-meta v1
cbc31da	author	Will Norris
cbc31da	added	206
cbc31da	deleted	0
cbc31da	files	1
cbc31da	body	The last deferred Inc 3 item. `fp++` on an address_space(2) far pointer now\nlowers and executes end-to-end (3a deref + 3b cast already shipped).\n\nMechanism: G_PTR_ADD {PF,S32} skips the G_INC fast-path (32-bit base) and\nlowers via ptrtoint/add/inttoptr; the s32 +-1 add (legalizeAddSub) splits the\nvalue with buildUnmerge(S8, s32) = a 4x s8 <- s32 G_UNMERGE_VALUES that was\nunsupported() — the one gap blocking 3c.\n\nFix (in 0002, hasAccum16-gated): legalizeUnmergeS32ToBytes, the exact mirror of\nthe existing legalizeMergeS32FromBytes — customFor({{S8,S32}}) rewrites the\n4x s8 <- s32 unmerge into the legal 2-level form (s32 -> 2x s16, then each\ns16 -> 2x s8), reusing the four original byte defs. Builds only unmerges, so no\nmerge<->unmerge artifact-combine loop. Default 8-bit codegen untouched.\n\nAlso closes a latent a16 bug: a uint32_t shift-by->=8 (legalizeShiftRotate)\nemitted the same unsupported unmerge; no test had hit it yet.\n\nGate: examples/65816/far_arith.c + dev/far_arith.sh + xcheck row (bank $00,\nfp++ then lda [dp], arr[1]=0xA9 ^ 0x5A = 0xF3).\n\nVerified (clang-23 rebuilt):\n- far_arith: disasm "2a: a7 00 lda [$0]"; MAME 0xF3; bsnes-jg 0xF3\n- no regression: far_indir/far_cast/far-run/far-bank1 PASS; a16incdec/add/sub\n  PASS both emulators; Csmith 27/30 (0 mismatch, 0 crash, 0 error)\n- 0002 regen round-trips; only the legalizeUnmergeS32ToBytes hunk (0 foreign,\n  0001 untouched)\n\n#320 Inc 3 (3a+3b+3c) complete; far-pointer CC + far calls remain Inc 4\n(upstream-gated).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
