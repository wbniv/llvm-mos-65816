| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/ad4d6ae) | plan: reduce + fix the DEFAULT-8bit 65816 matrix-fold-LOOP miscompile (+ fast repro) |

<!--history-meta v1
ad4d6ae	author	Will Norris
ad4d6ae	added	115
ad4d6ae	deleted	0
ad4d6ae	files	1
ad4d6ae	body	Adds docs/plans/2026-06-25-default8-loopfold-miscompile-reduce-and-fix.md and the\nself-contained host-side repro dev/loopfold-repro.sh.\n\nBreakthrough: the default-8bit fold-loop miscompile (loop form of zoom_fold computes a\nwrong CRC vs the unrolled form) reproduces in SD mode entirely host-side in ~10 s — the\nprior note believed it needed the full hd multi-bank demo in Docker. dev/loopfold-repro.sh\nloop -> ZOOM: FAIL (rom 0xE60E != host 0xF56C); unroll -> ZOOM: PASS. This makes cvise\nreduction tractable.\n\nFindings captured in the plan: it's a post-LTO backend bug (IR is correct; SNES build is\nLTO); the i<4 loop is compiler-unrolled in BOTH forms; the loop form sources an m[] byte\nvia an X-indexed stack load (eor ...,x) -> likely a wrong/clobbered X under register\npressure. Plan: creduce via the fast repro -> minimal .c/.ll, classify mosw65816-only vs\nmos6502 (possibly upstream), root-cause the wrong-X, fix + regression test. TODO item\nupdated to point at both.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
