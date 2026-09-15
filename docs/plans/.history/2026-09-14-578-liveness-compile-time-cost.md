| Date | Change |
|------|--------|
| [2026-09-14](https://github.com/wbniv/llvm-mos-65816/commit/1f01018) | docs(578): pre-publish review of b4749221bf37 + compile-time cost measurement |

<!--history-meta v1
1f01018	author	Will Norris
1f01018	added	154
1f01018	deleted	0
1f01018	files	1
1f01018	body	Review: fresh rebuild at the publication head; chain tests (2- and 3-block,\nMIR + ASM) and loop test (both prefixes) pass; CodeGen/MOS 80 pass / 1\nunsupported. Red check with MOSCopyOpt.cpp reverted to the submitted head:\nthe loop test fails on both prefixes (the real regression); the chain tests\npass on the pre-fix compiler too, which is correct -- they guard the\nper-block recompute against removal, not the fix itself -- and the body\nalready frames them that way. Live thread unchanged since 2026-08-22.\n\nCompile-time cost of fullyRecomputeLiveIns, previously unquantified:\nretired user instructions (perf stat in a --privileged container, since the\nhost was at load ~18 from a concurrent investigation), two llc binaries\ndiffering only in the one hunk, 176 corpus files at -O2 interleaved A/B:\n+0.79% corpus-wide, per-file median +0.17%, worst +2.4% (k_trig16); on-CPU\ntime ratio 0.9989. Not measurable in practice. One sentence added to the\nPR body's Validation line; plan doc carries method + raw numbers.\n\nCo-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa
-->
