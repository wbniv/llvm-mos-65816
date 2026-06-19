| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/50a59b5) | #321 globals.c RA crash: pin the exact mechanism via an isolated asserts build |
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/3eeab5d) | #321 globals.c RA failure: record root cause across investigation + plan + docs |

<!--history-meta v1
50a59b5	author	Will Norris
50a59b5	added	27
50a59b5	deleted	0
50a59b5	files	1
50a59b5	body	Per the rigorous (option A) path: an isolated Release+ASSERTIONS toolchain build\n(22 min, separate dir + shared ccache; shared toolchain untouched) + -debug-only=\nregalloc pinpointed the failure and RULED OUT the easy fix:\n\n- The unspillable vregs are the Ac16 TRANSITS (e.g. %122 = LDAbsIdx16 @B,%idx then\n  STAImag16 %122) — 1-instruction load->store ranges are weight:INF (unspillable),\n  so they must hold $a16 for that instant. Same for the LDAImag16->ADCImag16->\n  STAImag16 accumulation transits.\n- The deadlock is hard-register (A/X/Y) exhaustion in the indexed-accumulation loop:\n  LDAbsIdx16 ties up A16(=A:B)+X, the other 16-bit accumulator cycles A16 too, so the\n  8-bit loop values are stuck in $a (A16's low alias) and the allocator can't free A16\n  for the unspillable transit. Eviction + live-range splitting of the 8-bit squatter\n  all return to $a (X/Y taken).\n- Coalescing RULED OUT (zero 8-bit<->A16 joins) -> the plan's named Phase-3 candidate\n  (reject 8-bit->Ac16 coalescing, which fixes the 1d LDImm crash) does NOT apply here.\n\nImplication recorded in the investigation: no clean targeted one-liner; the real fix\nis the general Phase-3 Ac16-residency work (reduce simultaneous Ac16 transits pre-RA),\nwhich is substantial + regression-sensitive. a16regpress.c stays the acceptance case.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3eeab5d	author	Will Norris
3eeab5d	added	99
3eeab5d	deleted	0
3eeab5d	files	1
3eeab5d	body	Root-caused the +mos-a16 -O1/-Os "ran out of registers" crash (no fix yet — it's\nthe A16-threading Phase 3 hard core, deferred). Captured in three places:\n\n- investigation (NEW) docs/investigations/65816-a16-regalloc-pressure-failure.md:\n  the full record. It's -Os OVER-COALESCING, not raw value count — pre-RA MIR shows\n  -Os makes FEWER but longer-lived Ac16 vregs (8) than the passing -O2 (14); the\n  coalesced long ranges all need the single A16 and can't be split/spilled, so RA\n  gives up. -O0/-O2 clean. Documents the fix locus (shouldCoalesce / Ac16 residency),\n  the two regression risks (un-threading the Phase-1 wins; reopening the 1d crash),\n  and why a correct fix needs an asserts build (release hides the culprit vreg).\n\n- plan: A16-threading Phase 3 — record a16regpress.c as a concrete *correctness*\n  trigger (a function that crashes today, not just suboptimal) + tighten the\n  acceptance gate (a16regpress.c must compile; no A16-threading size regression).\n\n- docs: zp-pressure plan FINDING — refined with the -O2-works / over-coalescing\n  evidence + follow-up status (root-cause done; fix folded into Phase 3).\n\n- TODO bullet updated to match (root-caused; fix deferred to Phase 3; pathological).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
