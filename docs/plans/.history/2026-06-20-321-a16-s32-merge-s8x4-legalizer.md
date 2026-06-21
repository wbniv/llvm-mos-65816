| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/031cc6a) | #321 fix: a16 G_MERGE_VALUES 4xs8->s32 legalizer gap (Csmith seed 113) |

<!--history-meta v1
031cc6a	author	Will Norris
031cc6a	added	69
031cc6a	deleted	0
031cc6a	files	1
031cc6a	body	Csmith Phase-4 sweep (seeds 101-300) found a +mos-a16 LTO codegen crash:\n  LLVM ERROR: unable to legalize %_(s32) = G_MERGE_VALUES s8,s8,s8,s8 (in main)\n\nExtends the prior s32 work ([321-a16-unmerge-s32], which made s32<->s16 legal):\nunder a16 s32 is represented as 2x s16, so 2x s16 -> s32 merge is legal, but a\ndirect 4x s8 -> s32 merge (e.g. an i8->i32 sext the artifact combiner couldn't\nfold) hit B.unsupported(). selectMergeValues only handles a 2-source merge, so\nthe fix is in the legalizer, not the selector.\n\nFix: custom action legalizeMergeS32FromBytes (gated customFor({{S32,S8}}) under\nhasAccum16()) rewrites the 4x s8 merge into the legal 2-level form\n  merge(merge(a,b)->s16, merge(c,d)->s16)->s32\nwhich the artifact combiner folds against feeding unmerges. Both halves are\nalready legal ({S16,S8} cartesian; {S32,S16}). No selector change; default\ncodegen untouched (gated on hasAccum16).\n\nRepro is the deterministic Csmith seed (the merge is an LTO-only artifact;\nminimal C / per-TU IR don't reproduce, and a whole-module frozen .ll\nover-triggers by compiling runtime fns like __adddf3 with +mos-a16) -> no\nhermetic .ll; the differential is the gate.\n\nVerified (clang-23 rebuilt): dev/run.sh fuzz --gen csmith 1 113 -> 0x21B1\nall-agree, 0 crash (was crash); a16unmerge (s32<->s16 gate) still PASS;\na16cmpaudit 0x5EE0; 0002 round-trips (legalizeMergeS32FromBytes only).\n\nAlso from the same sweep: seed 247 is a +mos-xy16-only runtime mismatch (a16\ncorrect) -> handed off to wt/321-xy16 (handoff doc + open TODO item); not this\nfix.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
