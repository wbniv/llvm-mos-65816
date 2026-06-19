| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/09dee52) | #321 docs: split the scavenger N/Z-liveness crash into its own XFAIL row |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/dcbd5de) | #321 docs: fix the dangling "(1)" in deferred/rejected-items intro |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/8006801) | #321 docs: add plan index + deferred/rejected-items investigation tables |

<!--history-meta v1
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
