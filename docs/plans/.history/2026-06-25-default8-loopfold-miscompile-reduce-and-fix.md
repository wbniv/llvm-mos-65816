| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/a0498d7) | reduce: cvise-minimize the DEFAULT-8bit 65816 matrix-fold-LOOP miscompile (43-line repro + X-indexed-load root-cause lead) |
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/ad4d6ae) | plan: reduce + fix the DEFAULT-8bit 65816 matrix-fold-LOOP miscompile (+ fast repro) |

<!--history-meta v1
a0498d7	author	Will Norris
a0498d7	added	65
a0498d7	deleted	7
a0498d7	files	1
a0498d7	body	Ran the cvise reduction the plan called for. Held zoom.h FIXED (host and target must\ncompile the SAME fold so the host==target ZOOM differential isolates codegen) and reduced\nonly the pressure CONTEXT in mandel-zoom.c. Interestingness predicate = the loop-vs-unroll\ncontrol on each candidate: loop-build ZOOM FAIL (host=0xF56C rom=0xE60E) AND unroll-build\nZOOM PASS (0xF56C) — which rejects any cvise edit that introduces UB or collapses the\nwrong-X trigger, pinning cvise to the genuine loop-fold codegen bug.\n\nResult: 151 -> 51 lines raw (84 accepted reductions, ~26 min), hand-cleaned/de-UB'd to a\n43-line repro (docs/plans/spikes/2026-06-25-loopfold-min.c). Minimal by ablation: removing\nANY one of its four pressure sources (snes_ppu_reset_blank, the inline palette REG_CGDATA\nloop, apply_zoom's REG_CGDATA loop, the img_hash16 boot loop) collapses the bug — exactly\nwhy the earlier standalone-minimization attempts failed.\n\nRoot-cause lead CONFIRMED (finding #3): the post-LTO --lto-emit-asm diff shows the loop form\nsources m[i] via X-indexed stack loads (ldy mos8(.Lmain_zp_stk+1),x ; eor mos8(.Lmain_zp_stk),x)\nthe unroll form never emits, then immediately reuses X as the inner CRC bit-counter (ldx #8).\nA wrong/stale X folds the wrong m[] byte -> wrong CRC.\n\nDurable artifacts: dev/reduce-loopfold.sh (setup|interesting|reduce; reproduces the whole run),\nthe 43-line min repro, plan RESULT + Verification (steps 1-2 PASS; 3-6 = next phase: a\nself-contained mos6502-retargetable repro for upstream-vs-fork classification, then root-cause\nthe wrong-X + fix), investigation + TODO updated.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
ad4d6ae	author	Will Norris
ad4d6ae	added	115
ad4d6ae	deleted	0
ad4d6ae	files	1
ad4d6ae	body	Adds docs/plans/2026-06-25-default8-loopfold-miscompile-reduce-and-fix.md and the\nself-contained host-side repro dev/loopfold-repro.sh.\n\nBreakthrough: the default-8bit fold-loop miscompile (loop form of zoom_fold computes a\nwrong CRC vs the unrolled form) reproduces in SD mode entirely host-side in ~10 s — the\nprior note believed it needed the full hd multi-bank demo in Docker. dev/loopfold-repro.sh\nloop -> ZOOM: FAIL (rom 0xE60E != host 0xF56C); unroll -> ZOOM: PASS. This makes cvise\nreduction tractable.\n\nFindings captured in the plan: it's a post-LTO backend bug (IR is correct; SNES build is\nLTO); the i<4 loop is compiler-unrolled in BOTH forms; the loop form sources an m[] byte\nvia an X-indexed stack load (eor ...,x) -> likely a wrong/clobbered X under register\npressure. Plan: creduce via the fast repro -> minimal .c/.ll, classify mosw65816-only vs\nmos6502 (possibly upstream), root-cause the wrong-X, fix + regression test. TODO item\nupdated to point at both.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
