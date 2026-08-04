| Date | Change |
|------|--------|
| [2026-08-03](https://github.com/wbniv/llvm-mos-65816/commit/5485c41) | docs(round7): withdraw #122 — its "declared gap" was closed months earlier |
| [2026-08-03](https://github.com/wbniv/llvm-mos-65816/commit/44ca95e) | plan(demos): Round 7 (#119-#138) — twenty defect-hunting ROMs targeting unseen bug classes |

<!--history-meta v1
5485c41	author	Will Norris
5485c41	added	59
5485c41	deleted	19
5485c41	files	1
5485c41	body	Round 7 gave #122 unmerge32 the round's only star on the grounds that\nMOSLegalizerInfo marks the direct s32->4xs8 G_UNMERGE_VALUES as\n`unsupported` ("no seed hit it yet"), making it a guaranteed finding\neither way. That premise was already false when the plan was written.\n\nMOSLegalizerInfo.cpp:188 reads\n\n  .legalFor({{S16,S32},{S32,S64}}).customFor({{S8,S32},{S16,S64}})\n\nand {S8,S32} dispatches to legalizeUnmergeS32ToBytes -- which IS the\nsymmetric 2-level rule #122 proposed writing. It landed in cbc31da\n(#320 Inc 3c), was refined by 2bfe4f3, and has been regression-gated\nhermetically by dev/run.sh a16unmerge (frozen Csmith seed-11 IR) since\n2026-07-19. All of it predates this round.\n\nNor is it an untouched corner: an instrumented sweep of all 112 corpus\nslices measured 385 fires across 52 slices -- one of the hottest custom\nrules in the backend.\n\nThe stale text was agent-handoff.md's backend-nav section, which the\nround was written from without re-checking vendor/. Fixed at the source\nhere, so the next round can't inherit it. Lesson recorded in the plan: a\n"known gap" claim only earns a star if re-checked against vendor/ at\nselection time -- one grep would have caught this.\n\nKept from the investigation (the part with value): the measured trigger.\nAll 385 fires are ndefs=4, sourced from G_MERGE_VALUES (208), G_SEXT\n(145), G_ZEXT (32). The node forms only when a narrower value is\nextended to s32, run through arithmetic, then split into bytes -- never\nfrom an already-32-bit source, because the artifact combiner folds\nunmerge-of-load/constant/merge first (28 probe shapes across six -O\nlevels fired zero times).\n\nSpun out as its own TODO item, not a demo: the same sweep measured that\nG_ADD/G_SUB carries no maxScalar, so an s32 add narrows to 4xs8 G_UADDE\nlanes even under +mos-a16 (identical MIR with and without the feature);\nonly the bitwise ops get s16 lanes. Deliberate carry-chain decision or\nmissed 16-bit opportunity is NOT established -- it needs measurement.\n\nNo demo was built and nothing was committed to vendor/; the compiler is\nbyte-identical to main. Round 7 is now nineteen demos, first picks\nre-ranked to lead with #123 nmitally.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
44ca95e	author	Will Norris
44ca95e	added	216
44ca95e	deleted	0
44ca95e	files	1
44ca95e	body	Selection driven by the defect scoreboard's yield pattern: combiner-formed\nopcodes (the G_SCMP mechanism), the declared-unsupported s32->4xs8 unmerge,\nfirst-ever interrupt-CC / inline-asm / mixed-width mode-state coverage, a\nthird far-pointer pass, big frames, volatile/atomic discipline, and the last\nuntouched libcall seams (float<->s64, s64 runtime shifts).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
