| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/25fd083) | docs: loopfold root-cause narrowing + provisional UPSTREAM classification |
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/a0498d7) | reduce: cvise-minimize the DEFAULT-8bit 65816 matrix-fold-LOOP miscompile (43-line repro + X-indexed-load root-cause lead) |

<!--history-meta v1
25fd083	author	Will Norris
25fd083	added	9
25fd083	deleted	0
25fd083	files	1
25fd083	body	Asm structural diff (loop vs unroll, minimal repro, default-8bit):\n- loop:   .size .Lmain_zp_stk,16 — m[] materialized at +0..+7, fold via X-indexed\n          ldy/eor mos8(.Lmain_zp_stk{,+1}),x\n- unroll: .size .Lmain_zp_stk,2  — m[] kept in registers, no array, no indexed loads\nSo the loop form's bug is in materializing m[] into the ZP soft-stack and indexing it under\nthe surrounding pressure — machinery the unroll form avoids. Two sub-hypotheses refuted on the\nasm: the index ZP slots __rc5/__rc6 are NOT clobbered by the inner CRC bit-loops, and m[] at\n+0..+7 is NOT overwritten between store and fold — so it's not a simple index clobber.\n\nProvisional upstream-vs-fork: default-8bit ZP soft-stack + regalloc + indexed addressing are\nupstream llvm-mos; 0002's loadStoreRegStackSlot/copyPhysRegImpl hunks are +mos-a16-gated and\na16 tested clean, so the buggy default path doesn't run 0002's additions -> LIKELY UPSTREAM.\nDefinitive confirmation deferred to a pristine no-0002 reproduce.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
a0498d7	author	Will Norris
a0498d7	added	78
a0498d7	deleted	0
a0498d7	files	1
a0498d7	body	Ran the cvise reduction the plan called for. Held zoom.h FIXED (host and target must\ncompile the SAME fold so the host==target ZOOM differential isolates codegen) and reduced\nonly the pressure CONTEXT in mandel-zoom.c. Interestingness predicate = the loop-vs-unroll\ncontrol on each candidate: loop-build ZOOM FAIL (host=0xF56C rom=0xE60E) AND unroll-build\nZOOM PASS (0xF56C) — which rejects any cvise edit that introduces UB or collapses the\nwrong-X trigger, pinning cvise to the genuine loop-fold codegen bug.\n\nResult: 151 -> 51 lines raw (84 accepted reductions, ~26 min), hand-cleaned/de-UB'd to a\n43-line repro (docs/plans/spikes/2026-06-25-loopfold-min.c). Minimal by ablation: removing\nANY one of its four pressure sources (snes_ppu_reset_blank, the inline palette REG_CGDATA\nloop, apply_zoom's REG_CGDATA loop, the img_hash16 boot loop) collapses the bug — exactly\nwhy the earlier standalone-minimization attempts failed.\n\nRoot-cause lead CONFIRMED (finding #3): the post-LTO --lto-emit-asm diff shows the loop form\nsources m[i] via X-indexed stack loads (ldy mos8(.Lmain_zp_stk+1),x ; eor mos8(.Lmain_zp_stk),x)\nthe unroll form never emits, then immediately reuses X as the inner CRC bit-counter (ldx #8).\nA wrong/stale X folds the wrong m[] byte -> wrong CRC.\n\nDurable artifacts: dev/reduce-loopfold.sh (setup|interesting|reduce; reproduces the whole run),\nthe 43-line min repro, plan RESULT + Verification (steps 1-2 PASS; 3-6 = next phase: a\nself-contained mos6502-retargetable repro for upstream-vs-fork classification, then root-cause\nthe wrong-X + fix), investigation + TODO updated.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
