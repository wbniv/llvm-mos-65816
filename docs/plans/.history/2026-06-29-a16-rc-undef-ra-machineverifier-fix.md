| Date | Change |
|------|--------|
| [2026-09-13](https://github.com/wbniv/llvm-mos-65816/commit/88fbcaef) | docs(rc-undef): decide cause #2 — no downstream fix, escalate upstream |
| [2026-07-01](https://github.com/wbniv/llvm-mos-65816/commit/b9407d6d) | docs(rc-undef): record #69/#71 as new Cause-#2 witnesses |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/7e3e3c8f) | docs(rc-undef): durable two-cause investigation report + plan pointer |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/3337c8b7) | docs(rc-undef): cause #2 SplitKit/global-undef attempt — close but needs subreg-lane math (reverted) |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/d4622002) | docs(rc-undef): cause #2 fix attempt (rewriter readsUndefSubreg tracer) — loop-PHI blocks it |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/ee19429d) | docs(rc-undef): cause #2 pinned to the rewriter — split-COPY propagates the undef lane |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/06694f9f) | docs(rc-undef): cause #2 fully root-caused (dead read of undef Imag16 sub-lane) + upstream issue |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/d2542038) | docs(plan): rc-undef cause #1 shipped (f1af264, biohack v1.0.146); cause #2 now in progress |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/f1af264f) | fix(mos): rc-undef coalescer cause #1 — refuse $rcN-copy fold into a pair across a clobber |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/7226480c) | docs(plan): rc-undef pinned to the REGISTER COALESCER (low-risk fix) |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/680cb920) | docs(plan): a16 rc-undef MachineVerifier fix — root-cause + fix plan (2nd witness) |

<!--history-meta v1
88fbcaef	author	Will Norris
88fbcaef	added	8
88fbcaef	deleted	2
88fbcaef	files	1
88fbcaef	body	Resolves the [T5] residual on the rc-undef cause #2 item. Re-verified the\nseqvm repro (same two verifier errors at 736B/1480B). New pre-RA evidence:\nthe original vreg has an undef-lane partial def at 480B, a high-lane def\nat 784B on one path only, and a full use at 3472B; every vreg in the\nfailing chain is greedy-created, and SplitKit only copies lanes the\noriginal's subranges report live, so the full-pair copy at 716B means\nLiveIntervals reports the lane live across the undef def. Suspect layer\nis LiveRangeCalc/updateSSA subrange extension, not SplitKit or the\nrewriter. Issue body updated (READY TO POST, user-triggered); plan status\nand status row 13 updated; TODO item moved to Done.\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa
b9407d6d	author	Will Norris
b9407d6d	added	15
b9407d6d	deleted	0
b9407d6d	files	1
b9407d6d	body	The Round-4 demos #69 (Gouraud, per-pixel barycentric divide) and #71\n(marching-squares, per-pixel edge-crossing divide) both reproduce the deferred\na16-rc-undef-ra-pure-virtual known issue: -verify-machineinstrs crashes at\n-O1/-Os under +mos-a16 AND +mos-xy16 ('Using an undefined physical register'),\nwhile -O0 is clean and the full 5-way differential is green (code bit-exact\ncorrect — 0xC5E9 / 0x86A7 on bsnes-jg).\n\nMeasured all opt levels; added them to the witness tables in both the fix plan\nand the durable two-causes write-up. Significance: they broaden the known\ntrigger population — before Round 4 the deferred-Cause-#2 witnesses were an\nL-system + soft-float slices; #69/#71 show ordinary high-register-pressure\nint32-divide graphics kernels hit it too. No new action (same deferred\ngeneric-LLVM RA fix); recorded as XFAIL witnesses.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
7e3e3c8f	author	Will Norris
7e3e3c8f	added	3
7e3e3c8f	deleted	0
7e3e3c8f	files	1
7e3e3c8f	body	New docs/investigations/2026-06-30-65816-a16-rc-undef-two-causes.md — the standalone\nwrite-up of the whole arc: one verifier symptom = two distinct defects. Cause #1\n(coalescer copy-hint) FIXED+shipped+upstream-ready; cause #2 (RA undef sub-lane)\nroot-caused with three reverted fix attempts and deferred upstream (a generic-LLVM\npath-sensitive/loop-aware/subreg-lane-precise undef-propagation feature). Plan links\nto it.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3337c8b7	author	Will Norris
3337c8b7	added	20
3337c8b7	deleted	3
3337c8b7	files	1
3337c8b7	body	Second/third fix attempts on the worktree: a laneGloballyUndef tracer scanning all\na subrange's value numbers (PHIs as forwarders) to sidestep the loop-PHI block.\nInstrumented bail logging shows the failing values bail CONSERVATIVELY (a subreg\nCOPY def, and a valid-slot/no-instruction VNInfo) — not genuine real-defs — so the\nfix is close, but finishing it safely needs intricate subreg lane-mask composition\nwhere a wrong lane is a silent miscompile. Wrong trade for a verifier-only defect.\nReverted; isolated to the worktree vendor (generic VirtRegMap.cpp, no fork patch);\nshipped toolchain untouched. Confirms a genuine generic-LLVM RA feature -> upstream.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d4622002	author	Will Norris
d4622002	added	12
d4622002	deleted	2
d4622002	files	1
d4622002	body	Attempted candidate (b): a bounded VirtRegRewriter::lanesUndefAt that traces a\nspuriously-live lane back through full-register split COPYs to an undef origin\n(correctness-safe — only proves more lanes undef). Did NOT clear the witnesses:\nboth lsystem main and newton_gate_crc are loop-carried, so the subhi subrange's\nreaching value at the read is a PHI-def at the loop header; the tracer bails on\nisPHIDef(). Proving PHI undef-origin needs recursion across all predecessors incl.\nthe loop back-edge — materially larger/riskier. Reverted (isolated to the throwaway\nworktree's vendor; shipped Release toolchain never carried it). The fix belongs in\nSplitKit/InlineSpiller (carry the lane's undef-ness through the inserted COPY) and\nis a genuine generic-LLVM RA undertaking → upstream issue (item 13).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
ee19429d	author	Will Norris
ee19429d	added	16
ee19429d	deleted	6
ee19429d	files	1
ee19429d	body	Deeper root cause: MOS enables sub-register liveness and VirtRegRewriter already\nmarks undef sub-register reads (readsUndefSubreg -> setIsUndef), but a live-range-\nsplit full-pair COPY (%1759 = COPY %x, both lanes at one def) propagates the undef\nsubhi lane as a LIVE value, so readsUndefSubreg finds the lane "live" at the read\nand won't mark it undef. The split/spill copy doesn't carry the lane's undef-ness.\nCandidate fixes refined: (1) carry undef through the split COPY (SplitKit/Inline-\nSpiller), (2) trace undef origin in readsUndefSubreg, (3) DCE the dead pair-extract.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
06694f9f	author	Will Norris
06694f9f	added	26
06694f9f	deleted	12
06694f9f	files	1
06694f9f	body	Cause #2 (lsystem_sim.c main, newton_gate_crc -O1) is NOT a coalescer issue: a\n16-bit __mulsi3 arg built with the `undef %N.sublo:imag16 = COPY` idiom (high lane\nundef) is RA-assigned a $rc pair; the undef high lane is tracked live to a DEAD\nfull-pair read ($x = COPY $rcN, $x immediately overwritten), but lowering the\nvirtual sub-register read to the physical $rcN loses the undef flag -> verifier\nrejects the dead read. Code-correct (0x79C3 / 0x4D8B).\n\nThis is generic-LLVM RA / sub-register-undef-liveness (the undef %N.sublo idiom is\npervasive); candidate fixes (propagate undef onto the physreg read, or DCE the dead\nextract) are toolchain-wide and risk regressing the shipping compiler for a\ncode-correct latent defect — filed as a focused upstream issue\n(upstream-rc-undef-ra-pure-virtual-issue.md) rather than patched blindly. lsystem\nkeeps its KNOWN_ISSUES XFAIL pending that fix.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d2542038	author	Will Norris
d2542038	added	9
d2542038	deleted	6
d2542038	files	1
d2542038	body	Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
f1af264f	author	Will Norris
f1af264f	added	38
f1af264f	deleted	5
f1af264f	files	1
f1af264f	body	The long-standing a16/xy16 "Using an undefined physical register" verifier\nfailure (a16-newton-step-rc-undef) is TWO distinct defects sharing one symptom.\n\nCAUSE #1 (fixed here): the register coalescer folds a value read straight out of\na call-clobbered imaginary register ($rcN, `vreg = COPY $rcN`) into an Imag16\npair (a sub-register copy) that outlives the clobbering call; the pair inherits\nthe physical-$rcN allocation hint and the allocator re-binds it to $rcN across\nthe clobber, leaving a disconnected `$x = COPY $rcN` def->use. Pinned with an\nasserts toolchain (-debug-only=regalloc join trace) on a lifted minimal repro.\n\nFix: MOSRegisterInfo::shouldCoalesce refuses the join when NewRC==Imag16, the\ncopy is a sub-register copy, and an operand's unique def is `COPY $rcN` (physical\nImag8) live across a call clobbering $rcN (LiveIntervals::checkRegMaskInterference).\nCorrectness-safe by construction (only ever keeps a COPY) and tightly gated: 4/34\ncorpus programs change (all -verify clean + differential green), 30 byte-identical.\n\nValidation: rcundef.c (lifted newton_step) + newton_step verify clean -O0/-O1/-Os\n(a16+xy16); newton demo value unchanged 0x4D8B (MAME+bsnes-jg); corpus differential\ngreen. Drops the newton_sim.c KNOWN_ISSUES XFAIL (now XPASSes at -Os, the battery's\nverify level). New gate: dev/run.sh rcundef. Lit test: 0015 (coalesce-rc-undef.mir).\n\nCAUSE #2 (deferred, documented): the register *allocator* binds a PURE-VIRTUAL\nImag16 value (no $rcN copy hint to key on) to a clobbered $rc pair — lsystem_sim.c\n(all -O) and newton_sim.c at -O1. Not addressable in shouldCoalesce (the only\ncoalescer rule that masks it perturbs 22-25/34 corpus programs). Re-registered as\nKNOWN_ISSUES["a16-rc-undef-ra-pure-virtual"] (lsystem keeps its XFAIL); the genuine\nfix is RA-interference-level. See the plan + upstream-coalesce-rc-undef-pr.md.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
7226480c	author	Will Norris
7226480c	added	47
7226480c	deleted	1
7226480c	files	1
7226480c	body	-join-liveintervals=false makes newton_sim -verify clean -> the disconnected\ndef->use is created by the register coalescer, not the core RA. Fix goes in\nMOSRegisterInfo::shouldCoalesce (refusing a coalesce is always safe; corpus-byte-\nidentical is the safety net) — same hook/risk as 0010-coalesce-rotate-ac. The bad\njoin: a value live across a $rcN-clobbering libcall (JSR __mulsi3 implicit-def\n$rc3) coalesced INTO that $rcN. Next: asserts build -> -debug-only=regalloc join\ntrace -> narrow shouldCoalesce rule -> re-verify + drop both XFAILs.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
680cb920	author	Will Norris
680cb920	added	87
680cb920	deleted	0
680cb920	files	1
680cb920	body	Plan to fix the a16-newton-step-rc-undef "$x = COPY $rcN" undefined-physical-\nregister MachineVerifier false-positive at -O1/-Os (a16/xy16), now reproduced by\na SECOND independent demo (#23 L-System) — confirming it is not newton-specific.\nDiagnosed to the Virtual Register Rewriter materialising a COPY of a zero-page\nimaginary pair whose def the verifier doesn't see (code runs correctly: both\ndemos' 5-way differential is exact). Plan: minimal repro + -verify gate, pin the\nmissing-def site, fix the sub-register-liveness/def-tracking gap at the root on a\ncompiler worktree, then DROP both rc-undef XFAILs (stress the compiler, don't work\naround it). Timeboxed: fall back to the documented XFAIL if it's a large RA rework.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
