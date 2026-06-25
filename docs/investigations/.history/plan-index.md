| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/ff3694c) | #320 far->near thunk tail folds (-1 B); fix stale far-tail status + regen STACK |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/9ac3917) | docs(plan-index): index the #321 a16 Phase-3 trigger-check-pass plan (145 rows) |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/f59a5d5) | docs(plan-index): index trig Phase 2 (144 rows); triage the DONE Inbox false-positive |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/840f640) | docs(plan-index): add the far-data->2-banks gate-formalization plan row |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/56f5d80) | docs: record scavenger-fix verification + sweep "deferred scavenger" framing (0011/0012) |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/cf30a73) | docs(plan-index): add the 2026-06-26 scavenger live-$p fix plan (→ 142) |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/f791491) | docs(plan-index): add the shared plan-index tooling plan row (→ 141) |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/40d93f0) | docs(plan-index): add the 10 plans created since the 2026-06-25 refresh (→ 140) |
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/840fc17) | docs: Phase 2 zoom-pyramid verification + HD montage; Findings 2/3; TODO/handoff/index |
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/52acebc) | docs+todo: triage the auto-captured Csmith deferral + log the closeout commit in plan-index |
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/c613037) | docs: Phase 1 zoom-pyramid verification results, montage, Phase 2 probe + findings |
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/fe1a52d) | docs(plan-index): register the interactive Mandelbrot (Mode 7 fly-around) plan |
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/d21da90) | docs: finalize the Mandelbrot plan + register it in the indexes |
| [2026-06-24](https://github.com/wbniv/llvm-mos-65816/commit/8c14a3a) | docs: refresh plan-index — 74→127 plans, regenerate from git |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/0d76bfc) | #321 c-torture Phase 2 (-O1): 16 confirmed NEW a16/xy16 runtime miscompiles |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/f9a33d6) | #321 docs: reflect c-torture Phases 0+1 across the index docs |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/3be4584) | #321 docs: add the c-torture differential-suite plan to the plan index |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/8006801) | #321 docs: add plan index + deferred/rejected-items investigation tables |

<!--history-meta v1
ff3694c	author	Will Norris
ff3694c	added	1
ff3694c	deleted	0
ff3694c	files	1
ff3694c	body	The implementation-status row for "Far tail calls" was stale: it still said\n"tail peephole keys on JSR, so a JSL is never tail-converted" while the same\ndoc (:53-54) records the direct far->far fold landing in 4adda8b (2026-06-23).\nThis implements the next deferred case and reconciles the docs.\n\nPhase A (DONE) - far->near thunk tail. Broaden MOSLateOptimization::tailJMP's\nfar arm so `JSL __call_near_from_far; RTL` also folds to TailJML ($5C long\njump). The far->near mixed-banking thunk is ChangeToES'd to an EXTERNAL symbol\n(isGlobal() == false), so it's matched by exact name (isSymbol() && name ==\n"__call_near_from_far"), mirroring how MOSCallLowering special-cases the same\nsymbol - conservative, any other JSL is left alone. Stack-safe: the thunk's\n`pea .Lback-1; jmp (__rc18); .Lback: rtl` is a net-0 near frame above the\n3-byte far return, so its terminal RTL pops the ORIGINAL caller's return (the\nfolded JSL's own 3-byte return is exactly what the long jump elides).\n\n  - vendor MOSLateOptimization.cpp: +StringRef include, two named predicates\n    (DirectFarGlobal | NearFromFarThunk) -> regenerated into 0001 (round-trips\n    0001..0012; diff vs main's 0001 = only the far-arm broadening).\n  - dev/far_near_call.sh: flip the negative gate -> positive (assert far_caller\n    folds to a long jmp __call_near_from_far + R_MOS_ADDR24, no jsl/rtl).\n  - dev/regen-patch-0001.sh: STACK was stale (stopped at 0009); append\n    0010/0011/0012 so the round-trip verify matches live vendor, + sync the\n    0001..0007 -> 0001..0012 echo/comment strings.\n\nVerified (wt/320-far-tail-thunks): far_near_call folds + 0xE0 on MAME AND\nbsnes-jg; far_tail still 0xCB; corpus 7/7; csmith 50 0-mismatch; +mos-a16\nverify clean; 0001 round-trips.\n\nPhase B (BLOCKED, not deferred) - far-indirect thunk tail. `JSL\n__call_indir_far; RTL` would fold the same way, but a far-indirect *call*\ndoesn't link on main: its runtime stub (call-indir-far.s + __mos_far_target)\nwas never landed into tracked platforms/snes/ or the SDK (only WIP 7ee5f6f/\n1ea7507). Proven via `ld.lld: error: undefined symbol: __call_indir_far` from a\nminimal far-attribute call. So its tail-opt is premature; the IndirFarThunk arm\nwas intentionally not added. This also surfaces that the far-fn-pointer (a) row\noverclaims a far-indirect CALL as "done + landed" - flagged in the status doc;\nlanding the stub + a far-indirect-call e2e is the recommended follow-up.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_015YJUgtypfgz96EBm1NnoUh\n\n# Conflicts:\n# TODO.md\n# docs/investigations/plan-index.md\n\n# Please enter the commit message for your changes. Lines starting\n# with '#' will be kept; you may remove them yourself if you want to.\n# An empty message aborts the commit.\n#\n# interactive rebase in progress; onto eb12857\n# Last command done (1 command done):\n#    pick 773f0a2 # #320 far->near thunk tail folds (-1 B); fix stale far-tail status + regen STACK\n# No commands remaining.\n# You are currently rebasing branch 'wt/320-far-tail-thunks' on 'eb12857'.\n#\n# Changes to be committed:\n# modified:   TODO.md\n# modified:   dev/far_near_call.sh\n# modified:   dev/regen-patch-0001.sh\n# modified:   docs/implementation-status.md\n# modified:   docs/investigations/plan-index.md\n# modified:   docs/plans/2026-06-22-320-far-tail-calls.md\n# new file:   docs/plans/2026-06-26-320-thunk-tail-calls.md\n# modified:   patches/llvm-mos/0001-320-far-addrspace.patch\n#\n\n# Conflicts:\n# TODO.md\n# docs/investigations/plan-index.md\n\n# Please enter the commit message for your changes. Lines starting\n# with '#' will be kept; you may remove them yourself if you want to.\n# An empty message aborts the commit.\n#\n# interactive rebase in progress; onto c37660f\n# Last command done (1 command done):\n#    pick 13ee04c # #320 far->near thunk tail folds (-1 B); fix stale far-tail status + regen STACK\n# No commands remaining.\n# You are currently rebasing branch 'wt/320-far-tail-thunks' on 'c37660f'.\n#\n# Changes to be committed:\n# modified:   TODO.md\n# modified:   dev/far_near_call.sh\n# modified:   dev/regen-patch-0001.sh\n# modified:   docs/implementation-status.md\n# modified:   docs/investigations/plan-index.md\n# modified:   docs/plans/2026-06-22-320-far-tail-calls.md\n# new file:   docs/plans/2026-06-26-320-thunk-tail-calls.md\n# modified:   patches/llvm-mos/0001-320-far-addrspace.patch\n#\n\n# Conflicts:\n# docs/investigations/plan-index.md\n\n# Please enter the commit message for your changes. Lines starting\n# with '#' will be kept; you may remove them yourself if you want to.\n# An empty message aborts the commit.\n#\n# interactive rebase in progress; onto 9ac3917\n# Last command done (1 command done):\n#    pick 88f95b3 # #320 far->near thunk tail folds (-1 B); fix stale far-tail status + regen STACK\n# No commands remaining.\n# You are currently rebasing branch 'wt/320-far-tail-thunks' on '9ac3917'.\n#\n# Changes to be committed:\n# modified:   TODO.md\n# modified:   dev/far_near_call.sh\n# modified:   dev/regen-patch-0001.sh\n# modified:   docs/implementation-status.md\n# modified:   docs/investigations/plan-index.md\n# modified:   docs/plans/2026-06-22-320-far-tail-calls.md\n# new file:   docs/plans/2026-06-26-320-thunk-tail-calls.md\n# modified:   patches/llvm-mos/0001-320-far-addrspace.patch\n#
9ac3917	author	Will Norris
9ac3917	added	4
9ac3917	deleted	1
9ac3917	files	1
9ac3917	body	Row for docs/plans/2026-06-26-321-a16-threading-phase-3-trigger-check-pass-re-op.md\n(Investigation; commit e7e2270), footer 144 -> 145.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
f59a5d5	author	Will Norris
f59a5d5	added	3
f59a5d5	deleted	1
f59a5d5	files	1
f59a5d5	body	The audit-plan-deferrals hook captured the struck-through "Phase 2 — 16-bit CORDIC"\nDONE marker (under the master plan's Deferred header) as if it were a new deferral;\nit isn't — Phase 2 landed in 4626ddd and is a curated Done entry. Replaced the Inbox\nbullet with a triaged note carrying its fingerprint so the ledger suppresses it.\nAdded the plan-index row for the Phase 2 plan (commit 4626ddd, Fuzz / corpus).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
840f640	author	Will Norris
840f640	added	3
840f640	deleted	1
840f640	files	1
840f640	body	Index row for docs/plans/2026-06-26-formalize-far-data-2-banks-into-a-dedicated-passin.md\n(#320 far-pointer; dev/run.sh farindex, a9601e5); bump footer 142 -> 143.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011tDRoGK3T4gSGAHGBXk88B
56f5d80	author	Will Norris
56f5d80	added	2
56f5d80	deleted	2
56f5d80	files	1
56f5d80	body	Plan 2026-06-26-321-scavenger-nz-live-p-save-fix: flip status to DONE and paste\nthe raw verification evidence (PASS/FAIL) under each of the 8 numbered steps —\nrelease + asserts repro clean, 121/121 differential fuzz incl. the formerly-XFAIL\n169/173/196, corpus 7/7, a16sub gate, torture 58/0-fail, known-issues 0/0,\n0011/0012 round-trip.\n\nSweep the docs that still described the register-scavenger crash as a deferred,\nupstream-territory, no-fork-patch XFAIL — now that it is FIXED (0011) and the\nLDCImm MC-lowering bug it surfaced is FIXED (0012):\n- README: "two deferred RA/scavenger crashes" -> one (the pr15296 ZP-overflow);\n  ten-patch -> twelve-patch series.\n- ROADMAP §5 + TODO (deferred-core equivalence, the "two pathological XFAILs"\n  Watch item, the next-instrument item): the scavenger-N/Z crash had an\n  orthogonal targeted fix (0011), like globals.c did (0009) — it left the\n  deferred residency core; only the ZP-overflow XFAIL remains.\n- review guide: new §3.11 (0011) + §3.12 (0012) deep-dives; fix §3.9's stale\n  "scavenger XFAIL stays" line.\n- upstream-contribution-status: summary-table row 4 -> fix PR, add row 10 (0012).\n- plan-index: annotate the superseded scavenger-spike / pressure-handoff rows.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
cf30a73	author	Will Norris
cf30a73	added	3
cf30a73	deleted	1
cf30a73	files	1
cf30a73	body	Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
f791491	author	Will Norris
f791491	added	3
f791491	deleted	1
f791491	files	1
f791491	body	Closes the drift the post-commit hook flagged when 2026-06-26-shared-plan-index-\ntooling.md was committed (63daf1f). Demonstrates the loop: commit a plan → hook\nemits a paste-ready stub → fill summary/category → in sync.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
40d93f0	author	Will Norris
40d93f0	added	18
40d93f0	deleted	3
40d93f0	files	1
40d93f0	body	Slot into chronological-by-creation-commit order: s32-long verification,\nthe reviewer patch-series presentation, Blossom Phase 1, the SNES\nhardware-reference HAL split, interim cross-platform toolchain builds, the\npublished-compiler clean-room test gate, the 0009 a16 register-pressure fix,\nthe trig-as-differential-test + its HiROM/sin-LUT follow-up (clang far-index\nmiscompile fix in 0001), and the 0010 default-8bit coalescer-miscompile fix.\nRefresh the footer count/date. Verified: every docs/plans/*.md now has a row\n(140 indexed == 140 on disk).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
840fc17	author	Will Norris
840fc17	added	1
840fc17	deleted	1
840fc17	files	1
840fc17	body	Plan updated: Phase 2 section -> DONE+green (multi-bank snes-zoom, 128x128 x 8, 256 KiB);\na Phase 2 verification-results section (ROMFILE + per-level/VRAM hash + ZOOM, both builds,\nraw output); the HD increasing-detail montage (host 128x128 levels 0/2/4/5/6/7 + the\nbsnes-jg deep far-bank shot + MAME boot); Finding 2 (multi-bank far-DMA works, no far\npointer -> builds both) and Finding 3 (the vblank limit: a 16 KiB swap DMA overruns vblank\n-> force-blank the large swap; the VRAM gate caught it). Merge-back: Phase 2 checked off.\n\nTODO: zoom-pyramid Done entry now covers both phases; the [wip] item retired (the\ndefault-8bit miscompile follow-up stays open). agent-handoff worktree row + plan-index row\nupdated to Phases 1+2 done.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
52acebc	author	Will Norris
52acebc	added	1
52acebc	deleted	1
52acebc	files	1
52acebc	body	The audit-plan-deferrals hook flagged the struck-through "add the matching\nTODO.md entry" plan bullet as a deferral — a false positive: that action is\nexactly what 2cfd375 completed (the [321-csmith-fuzzer] Done entry). Triaged\nin place (dated note + fingerprint, so the ledger won't re-add it). Also\nappend 2cfd375 to the Csmith plan's row in plan-index.md.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01UFzfnhDq55ttkAyXt724ZX
c613037	author	Will Norris
c613037	added	1
c613037	deleted	0
c613037	files	1
c613037	body	Plan docs/plans/2026-06-25-321-mandelbrot-zoom-pyramid.md updated with the Phase 1\nimplementation outcome + per-step verification results (all PASS, raw output pasted),\nthe increasing-detail screenshot montage (host per-level renders + bsnes-jg deep dive +\nMAME boot), and the Findings (the default-8bit matrix-fold-loop miscompile; the Phase 2\nmulti-bank far-DMA feasibility proof). Phase 2 section rewritten with the de-risked,\nevidence-backed remaining-steps list.\n\nSpike docs/plans/spikes/2026-06-25-321-mandel-zoom-phase2-bank-dma-probe.c — the recorded\nmeasurement + verdict proving a DMA can source chr from a high ROM bank via the far-symbol\nbank:addr16 (the Phase 2 crux): linker places .far_rodata at $018000, (uint16_t)&far_sym =\n$8000, A1B0=$01 DMA lands bank-$01 bytes in VRAM (verified, bsnes-jg).\n\nTODO.md: Phase 1 -> Done; Phase 2 follow-up (feasibility proven) + a new baseline-bug\nfollow-up (cvise the default-8bit miscompile -> backend fix). agent-handoff worktree row +\nplan-index row.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
fe1a52d	author	Will Norris
fe1a52d	added	1
fe1a52d	deleted	0
fe1a52d	files	1
fe1a52d	body	Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d21da90	author	Will Norris
d21da90	added	3
d21da90	deleted	1
d21da90	files	1
d21da90	body	- plan: merge-back checklist marked done (artifacts committed, TODO->Done, run.sh/task\n  targets, indexes) — only the user-triggered merge to main remains.\n- plan-index.md: add the beefy SNES Mandelbrot demo row (Platform), refresh 127->128.\n- agent-handoff.md: register wt/321-mandelbrot in Active worktrees (all 4 stages green\n  on the branch; retained until merge per policy).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8c14a3a	author	Will Norris
8c14a3a	added	63
8c14a3a	deleted	8
8c14a3a	files	1
8c14a3a	body	Bring docs/investigations/plan-index.md current: it had stopped at the\n2026-06-19 c-torture row (74 rows) while 53 more plans landed through\n2026-06-23. Regenerated per the index's own documented derivation:\n\n- Order + every Commit(s) column rebuilt from `git log --follow` (the\n  canonical sort reproduces the prior 74-row order exactly; 8 older rows\n  also picked up commits that touched them after the last refresh — one\n  prior row even listed a commit, e9e3de6, that never touched its file).\n- 53 new rows authored in-house from each plan's TL;DR / verdict, slotted\n  into chronological-by-creation-commit position (not just appended — e.g.\n  the pre-public-polish plan, filename-dated 06-14 but committed late,\n  correctly lands mid-table).\n- Existing 74 summaries/titles/categories preserved byte-for-byte.\n\nValidated: 127 rows, 1:1 with docs/plans/*.md on disk, no duplicate or\nbroken links, every row well-formed (5 cells), 314 commit links.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
0d76bfc	author	Will Norris
0d76bfc	added	1
0d76bfc	deleted	1
0d76bfc	files	1
0d76bfc	body	Full -O1 differential pass over all 1253 in-scope tests:\n1098 PASS, 136 SKIP, 3 known-XFAIL (a16-zp-pressure-overflow) + 16 FAIL.\n\nAll 16 FAILs re-run in isolation on a quiet box with bsnes-jg REPRODUCED\n(zero flakes); every a16 case agrees on both MAME and bsnes-jg. They are\nNEW runtime wrong-value miscompiles (default self-checks PASS, a16/xy16\nwrites 0xDEAD) — not the known register-pressure family — and diverse\n(packed structs, nested struct/arrays, memset, varargs, signed left-shift,\ncomputed-goto, counted loops at INT limits) => likely several distinct\na16/xy16 codegen bugs. This is the payoff of the external suite: real bugs\nthe home-grown tests never hit.\n\nRecorded in examples/65816/torture/xfails.tsv (expected-fail manifest);\ntorture_run.py now reports a listed test as XFAIL (and a fixed one as\nXPASS -> "remove the row"), so the gate is green-modulo-known. Per-defect\nroot-cause is the open backlog (new TODO item). No vendor/llvm-mos change.\n\nNote: the -Os pass didn't run (the runner left orphan MAME children that\nhung teardown after -O1, and set -e stopped the chained pass); the 16 are\nunaffected (confirmed isolated). -Os rerun + orphan-reaping are follow-ups.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
f9a33d6	author	Will Norris
f9a33d6	added	1
f9a33d6	deleted	1
f9a33d6	files	1
f9a33d6	body	- plan-index.md: c-torture row -> Phases 0+1 done (pilot 102/17/1, the\n  pr15296 ZP-pressure finding); add the e9e3de6 + 15542ff commits.\n- deferred-and-rejected-items.md: note the a16-zp-pressure-overflow as a\n  sibling symptom on the globals.c XFAIL row (same Phase-3 fix).\n- agent-handoff.md: the emulator differential gate is live —\n  dev/run.sh torture, oracle-gated SKIP/FAIL/XFAIL.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3be4584	author	Will Norris
3be4584	added	1
3be4584	deleted	0
3be4584	files	1
3be4584	body	New row for 2026-06-19-321-c-torture-execute-differential-suite.md\n(Phase 0 landed). Index now covers all 74 plans.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8006801	author	Will Norris
8006801	added	102
8006801	deleted	0
8006801	files	1
8006801	body	Two new reading-map docs under docs/investigations/:\n\n- plan-index.md — every plan under docs/plans/ (73 rows), one per plan,\n  sorted oldest→newest by creation commit, with a one-line summary, the\n  git-log --follow commit set, and a category. The table of contents over\n  the M0→M1→M2 arc.\n\n- deferred-and-rejected-items.md — the negative-space companion: 19 paths\n  that were NOT carried to completion (DEFERRED / XFAIL / PARKED / REJECTED\n  / WON'T-DO / REVERTED), each with the reason, the revisit trigger, and the\n  disposition record. Leads with the live DEFERRED work, trails the settled\n  dead-ends. Sourced from plan status headers, TODO §Watch/§Parked, the\n  triaged Inbox deferral ledger, and in-plan Deferred/Out-of-scope sections.\n\nDocs-only; no vendor/ or 0002 change.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
