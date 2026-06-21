| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/7e05e1c) | #321 native s16: cross-block REP/SEP mode-tracking (hoist rep/sep out of loops) |

<!--history-meta v1
7e05e1c	author	Will Norris
7e05e1c	added	162
7e05e1c	deleted	0
7e05e1c	files	1
7e05e1c	body	MOSInsertREPSEP was per-block and 8-bit-anchored — every block began in 8-bit\nmode and was forced back before its terminator — so a loop with a 16-bit body\nre-ran `rep #$20 … sep #$20` every iteration. Replace the per-block placement\nwith a forward dataflow that propagates the M (accumulator-width) mode across the\nCFG and inserts switches only at genuine transitions.\n\n- requiredWidth() classifies each instruction: MLow ⇒ M16; isReturn/isCall ⇒ M8\n  (the 65816 ABI boundary — 8-bit at every call and return); isBranch and\n  carry-init ⇒ agnostic (no constraint, mode set by dataflow); else M8.\n- Per-block First/Last facts feed a fixpoint over a {None, M8, M16, Conflict}\n  lattice. Entry is pinned M8 (ABI); a non-passthrough block's In is pinned to its\n  First (entering edges, not an in-block switch, deliver the width); passthrough\n  blocks meet their preds.\n- Switches land inside a block (seeded with In, no forced 8-bit at exit) and on\n  edges P→B where Out[P]≠In[B] (end-of-P if P has one successor, else start-of-B\n  if B has one predecessor). v1 bails the whole function to the legacy per-block\n  anchoring on any switch that would hit a true critical edge — always correct,\n  just leaves the old churn there. The STZ store-of-zero fusion is unchanged.\n\nMust-win lands: a 16-bit loop body holds 16-bit mode across iterations — rep\nhoists to the preheader, sep sinks to the exit, none in the body (a16loop reads\n0x2340); a call inside a 16-bit region executes 8-bit (a16call reads 0x4456).\nBoth on MAME + bsnes-jg. New dev/regen-patch.sh captures the isolated-worktree\npatch-regen method. Non-breaking: corpus 7/7, all 13 a16* tests green, patch 0002\nround-trips.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
