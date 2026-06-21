| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/1ccd2f0) | #321 A16-threading Phase 3: formalize the deferral + record the gated spike recipe |

<!--history-meta v1
1ccd2f0	author	Will Norris
1ccd2f0	added	139
1ccd2f0	deleted	0
1ccd2f0	files	1
1ccd2f0	body	Phase 3 (RA-level Ac16 residency) is the last open M2 A16-threading slice.\nRe-examining at M2 wrap-up surfaced a documented inconsistency + a vague\ntrigger:\n\n- The A16-threading plan named Phase 3 as a `shouldCoalesce` barrier (the\n  fix). But the asserts root-cause (50a59b5) RULED COALESCING OUT as the\n  a16regpress.c / globals.c crash cause — zero 8-bit<->A16/Ac16 joins. So the\n  barrier is a SAFETY COMPANION (it enforces the 1d invariant once a value\n  lives across ops), not the fix. The actual lever is pre-RA Ac16 residency\n  at selectAlu16Native (collapse the INF single-instruction transits that\n  exhaust the allocator).\n- Reward is already banked (Phases 1/1.5 -> ~1 non-adjacent reload); the only\n  gain is one pathological -Os/-O1 crash on slack code; risk is high and on\n  the common path -> keep the XFAIL (lesson #3).\n\nCorrect the framing in the plan doc (the "lever already exists" bullet),\nreplace the one-line verification step 5 with the gated B0->B1->B2 throwaway-\nworktree spike recipe, and replace the vague "reevaluate at M2 wrap-up" with\na concrete re-open trigger (a 2nd independent regalloc/ZP-overflow from\nrealistic code, or a real function crossing ~10 of 14 Imag16 pairs).\n\nDocs-only: no vendor/ change, no 0002 regen, no toolchain rebuild. The\nTODO.md half of this work was swept into a concurrent agent's commit 455df83.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
