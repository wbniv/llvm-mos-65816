| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/718ccd9) | #321 globals.c RA fix DECISION (ii): keep XFAIL, reevaluate at M2 wrap-up |
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/3eeab5d) | #321 globals.c RA failure: record root cause across investigation + plan + docs |
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/9fc5cf2) | #321 ZP-pressure measurement: baseline + globals.c +mos-a16 -Os RA-failure finding |

<!--history-meta v1
718ccd9	author	Will Norris
718ccd9	added	6
718ccd9	deleted	5
718ccd9	files	1
718ccd9	body	The isolated asserts root-cause (50a59b5) proved there is NO targeted fix —\nonly the general Phase-3 Ac16-residency rework, which is high-risk to the common\na16 path (un-threads the Phase-1 wins / reopens the 1d crash) and low-reward for a\npathological bug (the ZP measurement shows real code is slack). So per option (ii):\nkeep the XFAIL; do NOT do a risky rework for a pathological edge case now.\n\nRecorded across:\n- TODO.md: bug bullet decision + a Watch item "Reevaluate ... at M2 wrap-up"\n  (a16regpress.c is the ready acceptance case if Phase-3 residency is ever taken on).\n- A16-threading plan (Phase 3): asserts-done, keep-XFAIL, reevaluate flag.\n- ZP-pressure plan (FINDING follow-up): same.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3eeab5d	author	Will Norris
3eeab5d	added	22
3eeab5d	deleted	15
3eeab5d	files	1
3eeab5d	body	Root-caused the +mos-a16 -O1/-Os "ran out of registers" crash (no fix yet — it's\nthe A16-threading Phase 3 hard core, deferred). Captured in three places:\n\n- investigation (NEW) docs/investigations/65816-a16-regalloc-pressure-failure.md:\n  the full record. It's -Os OVER-COALESCING, not raw value count — pre-RA MIR shows\n  -Os makes FEWER but longer-lived Ac16 vregs (8) than the passing -O2 (14); the\n  coalesced long ranges all need the single A16 and can't be split/spilled, so RA\n  gives up. -O0/-O2 clean. Documents the fix locus (shouldCoalesce / Ac16 residency),\n  the two regression risks (un-threading the Phase-1 wins; reopening the 1d crash),\n  and why a correct fix needs an asserts build (release hides the culprit vreg).\n\n- plan: A16-threading Phase 3 — record a16regpress.c as a concrete *correctness*\n  trigger (a function that crashes today, not just suboptimal) + tighten the\n  acceptance gate (a16regpress.c must compile; no A16-threading size regression).\n\n- docs: zp-pressure plan FINDING — refined with the -O2-works / over-coalescing\n  evidence + follow-up status (root-cause done; fix folded into Phase 3).\n\n- TODO bullet updated to match (root-caused; fix deferred to Phase 3; pathological).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
9fc5cf2	author	Will Norris
9fc5cf2	added	95
9fc5cf2	deleted	0
9fc5cf2	files	1
9fc5cf2	body	Investigation on a throwaway branch (CC-frame DP-window revival trigger + the\nmulti-value-register-pressure Phase 0 scan, in one host-only measurement).\n\ndev/measure-zp-pressure.sh (standalone): per-function distinct allocatable __rc<N>\nin +mos-a16 -Os -S (live-range reuse => distinct names ~ peak imaginary-register\npressure), excluding reserved __rc0/1 (soft-SP) + __rc16/17 (scavenger), vs the\n14-pair/28-byte usable pool.\n\nBaseline:\n  - Real code (6 kernels + 5/6 corpus, 13 fns): max 10 bytes (~5 of 14 pairs,\n    k_bits:main), mean 5.6. Zero functions near/over the budget.\n  - Synthetic ladder validates the metric: monotonic 0->2->8->22, and the ~20-live\n    shape fragments into 13 rep/sep brackets (matches the prior session).\n  Verdicts: CC-frame DP-window (a) = SHELVE with evidence (ZP is slack). Multi-value\n  fragmentation Phase 0 = DEFER confirmed (no real function exhausts the pool).\n\nFINDING (new defect): globals.c:main fails RA under +mos-a16 -Os ("ran out of\nregisters") while DEFAULT -Os and +mos-a16 -O0 both succeed. The corpus is built\ndefault 8-bit, so this was never exercised under +mos-a16; the fuzzer doesn't generate\nthis shape. A hard crash (not fragmentation) in the F3/spill-coverage family. Promoted\nto a separate follow-up (file + repro + fuzzer coverage + fix); NOT fixed here.\n\nNo codegen change (vendor/ untouched, 0002 not regenerated).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
