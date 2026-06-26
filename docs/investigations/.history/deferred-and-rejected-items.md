| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/5bea574) | docs: sync living refs with patch 0009 (globals.c +mos-a16 RA crash FIXED) |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/f9a33d6) | #321 docs: reflect c-torture Phases 0+1 across the index docs |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/cfef277) | #321 docs: correct stale "corpus is 8-bit" claim on the scavenger XFAIL |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/09dee52) | #321 docs: split the scavenger N/Z-liveness crash into its own XFAIL row |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/dcbd5de) | #321 docs: fix the dangling "(1)" in deferred/rejected-items intro |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/8006801) | #321 docs: add plan index + deferred/rejected-items investigation tables |

<!--history-meta v1
5bea574	author	Will Norris
5bea574	added	3
5bea574	deleted	3
5bea574	files	1
5bea574	body	Patch 0009 (ad506ed) landed on main 2026-06-25 and fixed the +mos-a16\n-O1/-Os "ran out of registers" regalloc deadlock on real code\n(globals.c / a16regpress.c) via an orthogonal i8-loop-counter de-pin\n({A}-pinned ADCImm -> relocatable G_INC/G_DEC), NOT the deferred Phase-3\nAc16-residency rework. The dated plan/investigation files already record\nthis; this brings the living reference docs into sync:\n\n- TODO.md: move the globals.c RA-failure bullet to Done (0009 detail);\n  refocus the Watch item on the remaining deferred s16-pressure core\n  (scavenger-N/Z + pr15296 ZP-overflow); update the shared-core framing\n  in the A16-threading + ALU-chain bullets (globals.c crash left the\n  frontier); bump the forward-looking upstream patch count to 0001-0009.\n- implementation-status.md: flip the RA-failure row to FIXED(0009);\n  add it to the #321 TL;DR; correct the XPASS-guard row (only a16scavnz\n  remains asserted-to-crash); header date -> 2026-06-25.\n- 65816-patch-series-review-guide.md: nine patches, add the 0009 row,\n  fix the deferred-core statement + "nine patches" count.\n- ROADMAP.md + agent-handoff.md: patch count 0001-0009; ROADMAP\n  shared-core face list updated.\n- deferred-and-rejected-items.md: globals.c row -> FIXED(0009), keep\n  pr15296 ZP-overflow as the still-deferred sibling.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01LRTvYvtgA5tTtrFDw9ih6Z
f9a33d6	author	Will Norris
f9a33d6	added	1
f9a33d6	deleted	1
f9a33d6	files	1
f9a33d6	body	- plan-index.md: c-torture row -> Phases 0+1 done (pilot 102/17/1, the\n  pr15296 ZP-pressure finding); add the e9e3de6 + 15542ff commits.\n- deferred-and-rejected-items.md: note the a16-zp-pressure-overflow as a\n  sibling symptom on the globals.c XFAIL row (same Phase-3 fix).\n- agent-handoff.md: the emulator differential gate is live —\n  dev/run.sh torture, oracle-gated SKIP/FAIL/XFAIL.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
cfef277	author	Will Norris
cfef277	added	1
cfef277	deleted	1
cfef277	files	1
cfef277	body	We now have a 16-bit corpus (corpus-a16 differential gate, c998d7f,\n2026-06-19). The reason the corpus doesn't catch the scavenger N/Z crash\nis not that the corpus is 8-bit — it's that the crash is a fuzzer-found\nshape (8/500 seeds), not a corpus program. The corpus's one +mos-a16\ncasualty is the separate globals.c RA failure. Reword the Why clause.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
09dee52	author	Will Norris
09dee52	added	2
09dee52	deleted	2
09dee52	files	1
09dee52	body	The "$p-spill compiler crash" row was mislabeled DEFERRED and described\nas a generic spill-path fix. It is the register-scavenger N/Z-liveness\ncrash: saveScavengerRegister asserts N/Z dead at every frame-vreg spill\npoint, but +mos-a16 -O1/-Os pressure scavenges while N/Z is live -> PH $p\ninvalid MIR. Pristine-upstream bug; default 8-bit & +mos-a16 -O0 compile\nclean; the corpus is 8-bit so it never saw it. Re-probe 229662a found no\nnarrow fix. Reclassified XFAIL, moved into the XFAIL band, and linked the\nproper investigation (65816-a16-scavenger-nz-liveness.md) instead of the\ncritical-edge plan. Distinct from the globals.c "ran out of registers" RA\nfailure (also XFAIL) — two different bugs, both -O1/-Os-pressure-gated.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
dcbd5de	author	Will Norris
dcbd5de	added	7
dcbd5de	deleted	5
dcbd5de	files	1
dcbd5de	body	The intro said "Three governing lessons" but listed only (2) and (3).\nAdd (1) measure-don't-assume — the load-bearing one here, since every\nrejection is a measured regression (worktree spike / corpus trigger\ncheck), not a prediction.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8006801	author	Will Norris
8006801	added	69
8006801	deleted	0
8006801	files	1
8006801	body	Two new reading-map docs under docs/investigations/:\n\n- plan-index.md — every plan under docs/plans/ (73 rows), one per plan,\n  sorted oldest→newest by creation commit, with a one-line summary, the\n  git-log --follow commit set, and a category. The table of contents over\n  the M0→M1→M2 arc.\n\n- deferred-and-rejected-items.md — the negative-space companion: 19 paths\n  that were NOT carried to completion (DEFERRED / XFAIL / PARKED / REJECTED\n  / WON'T-DO / REVERTED), each with the reason, the revisit trigger, and the\n  disposition record. Leads with the live DEFERRED work, trails the settled\n  dead-ends. Sourced from plan status headers, TODO §Watch/§Parked, the\n  triaged Inbox deferral ledger, and in-plan Deferred/Out-of-scope sections.\n\nDocs-only; no vendor/ or 0002 change.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
