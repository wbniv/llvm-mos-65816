| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/3d5a989) | #321 record the ZP-pressure baseline verdict across CC + multi-value items |
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/e30f01c) | #321 CC frame decision RESOLVED (phased): record across docs |

<!--history-meta v1
3d5a989	author	Will Norris
3d5a989	added	8
3d5a989	deleted	0
3d5a989	files	1
3d5a989	body	Cross-reference the measured baseline (9fc5cf2, dev/measure-zp-pressure.sh) into\nthe two decisions it was the trigger for:\n\n- CC frame decision record + TODO bullet: the DP-window (a) revival trigger\n  RAN -> ZP is SLACK (13 real functions, max ~5 of 14 pairs) -> (a) shelved with\n  evidence, not built. (c) the soft static stack stands.\n- multi-value-register-pressure plan Phase 0 + TODO bullet: scan RAN -> 0 of 13\n  real functions exhaust the pool -> DEFER confirmed with data.\n\nBoth note the separate +mos-a16 -Os RA crash on globals.c surfaced by the scan\n(tracked in its own bullet, fd4d474).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
e30f01c	author	Will Norris
e30f01c	added	70
e30f01c	deleted	0
e30f01c	files	1
e30f01c	body	The 65816 calling-convention frame fork — the last hard sub-decision gating\nM2's hardware-stack ABI — was steered by the project lead on 2026-06-18:\nPHASE IT.\n\n  - First-pass ABI keeps the soft static stack (c) — llvm-mos's actual edge;\n    already done, stable, non-recursive code touches no hardware stack.\n  - The TCD direct-page window (a) is DEFERRED behind a zero-page-pressure\n    measurement (the swing vote: build it only if the imaginary-register file\n    proves tight on real corpus+kernel code). Host-only measurement, not run\n    here — named as the revival trigger.\n  - Pure hardware-stack-relative (b) is RULED OUT (dominated: limited ,S\n    instruction coverage -> slower; more MC work than (a)).\n\nThe other three sub-decisions were already settled: return = A low / X high\n(LOCKED 2026-06-17); args = keep imaginary-register (adopted for first pass);\nrecursion = the hardened soft static stack (stays the fallback under any frame).\nSo the frame no longer blocks the first-pass ABI.\n\nDocs-only, no codegen change (vendor/ untouched, 0002 not regenerated):\n  - NEW docs/plans/2026-06-18-321-cc-frame-phased-decision.md (durable record).\n  - docs/investigations/65816-calling-convention-decision.md: frame marked\n    RESOLVED (phased); open-question 1 (goal) answered.\n  - TODO.md M2 bullet + docs/ROADMAP.md: reframed open->resolved-phased.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
