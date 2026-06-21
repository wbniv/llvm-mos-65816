| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/866d530) | #321 native-s16 Phase 0: surface roll-up + measured-complete verdict |
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/95d65df) | #321 native-s16: plan the surface consolidation & close-out |

<!--history-meta v1
866d530	author	Will Norris
866d530	added	90
866d530	deleted	2
866d530	files	1
866d530	body	Execute Phase 0 of the consolidation plan on main's host toolchain (no vendor/\nchange). Ship dev/measure-native-s16-surface.sh: drives the three existing\nharnesses (compare-surface, a16-threading, zp-pressure) and adds the missing\nROADMAP step-5 acceptance table.\n\nResults (CONFIRMED measured-complete, nothing built):\n- 0a: all three harnesses reproduce. Compares native except register-resident\n  EQ-as-value (optimal byte-wise); threading roundtrips=0 (post-peephole\n  optimum); ZP max 10/28 B, 0/13 real fns exhaust the pool. globals.c +\n  a16regpress.c crash +mos-a16 -Os = the shared deferred core, live.\n- 0b: ROADMAP step-5 a16-vs-default is honestly MIXED. Sustained-16-bit class\n  wins (chain -63%, multivalue -65%, k_isort -39%; aggregate -22%/-220 B,\n  corpus 7/7); 8/16-interleave stress kernels regress (k_prng +60%, k_crc16\n  +27%) -- on-design (lessons #1/#2, verified no libcall asymmetry, pure\n  rep/sep+Imag16 cost). Confirms why +mos-a16 is opt-in/per-op-gated.\n- 0c: A16-threading Phase 3 and the >14-live ALU-chain residual are the SAME\n  deferred core (RA-level 16-bit residency under pressure) -> one trigger, one\n  B0->B1->B2 recipe.\n- New candidate routed, not built: >=8-shift bracket fragmentation (amount>=8\n  byte-relabel does the byte-move in 8-bit mode, splitting the M16 run); bounded\n  + uncertain net -> future measurement-gated spike, below the GO bar.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
95d65df	author	Will Norris
95d65df	added	348
95d65df	deleted	0
95d65df	files	1
95d65df	body	Roll up the three open M2 native-s16 tracks (16-bit compares/branches,\nA16-threading, ALU-chain extensions) into one measure-and-close plan, the\n#321 analogue of the #320 zero-bank close. All three are already at their\nmeasured state (compares CLOSED; threading Phases 0/1/1.5 done + Phase 3\ndeferred; ALU-chains shipped + multi-value pressure characterized-deferred),\nso the deliverable is a durable surface map: a dev/measure-native-s16-surface.sh\nroll-up over the three existing harnesses + the missing ROADMAP step-5\nacceptance table, the recorded verdict, and the upstream "stage-1 native-s16\nmeasured-complete" paragraph.\n\nThe plan's one contribution: A16-threading Phase 3 and the >14-live ALU-chain\nresidual are the SAME deferred core (RA-level 16-bit residency under register\npressure, the globals.c -Os RA-crash class) -> one frontier, one trigger, one\nB0->B1->B2 spike recipe. Host-only measurement, no vendor/ change expected.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
