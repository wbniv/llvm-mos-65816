| Date | Change |
|------|--------|
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/c09912a) | docs(upstream): retract LTO+a16 bitmask early-exit issue as a misdiagnosis |

<!--history-meta v1
c09912a	author	Will Norris
c09912a	added	179
c09912a	deleted	0
c09912a	files	1
c09912a	body	The drafted upstream issue (2c31f1c) claimed an LTO + +mos-a16 miscompile:\nthat _fact_emit's loop over (uint32_t)1u<<r generates `cmp r,#16; jmp rts`\nand skips rows 16-27. A controlled rebuild + disassembly experiment proves\nthis is a MISDIAGNOSIS.\n\nThe `cmp #$10` is the loop's SECOND guard, `q->n < UPQ_MAX_JOBS`, where\nUPQ_MAX_JOBS = 16 = 0x10. Decisive test: the macro is #ifndef-guarded, so\noverride it — compiling factorial.c with -DUPQ_MAX_JOBS=20 moves the\nconstant to `cmp #$14` (it TRACKS the macro), proving the compared value is\nq->n (upload-queue depth), not the shift counter r. The real r<28 bound\n(`cpy #$1c`) is present and correct. The `jmp rts` is the intended\nper-vblank DMA-budget exit (<=16 jobs/frame; 28 rows flush over 2 frames),\nnot a row-skipping miscompile. The original disasm annotation labeling ZP\nslot $2c as "loop counter r" was the error — it held q->n.\n\n- Banner-retract the issue body (preserved verbatim below the banner); DO\n  NOT POST.\n- Mark item 11 retracted in upstream-contribution-status.md.\n- TODO: close the post-the-bug item, open a follow-up to root-cause the\n  *real* factorial stall (possible 32-bit ==0 miscompile under LTO, or\n  frame ordering — still unverified; blocked on a runnable LTO build by the\n  unrelated __memset_far far-memops crash).\n- Add the verification plan with full raw evidence.\n\nToolchain rebuilt from scratch for this (no warm build/ existed); SDK build\nitself crashed on the unrelated snes-far __memset_far G_PTR_ADD(p2,s16)\nlegalization gap, worked around by a direct object-compile + disasm.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
