| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/bbb44e5) | #321 xy16: classify known-issue crashes under +mos-xy16 too (symmetric XFAIL) |

<!--history-meta v1
bbb44e5	author	Will Norris
bbb44e5	added	131
bbb44e5	deleted	0
bbb44e5	files	1
bbb44e5	body	tools/a16_fuzz.py evaluate() runs the -verify-machineinstrs crash gate under\nboth +mos-a16 and +mos-xy16 (xy16 implies a16), but only the a16 leg ran\nclassify_known() -> XFAIL. The xy16 leg unconditionally returned CRASH, so a\nknown, already-diagnosed deferred defect that trips the xy16 verify was\nmis-reported as a hard FAIL instead of a tracked XFAIL.\n\nFix: mirror the a16 leg in the xy16 leg -- classify_known(vlog_xy) -> XFAIL\nahead of the CRASH fallthrough. An unmatched xy16 crash still hard-FAILs, so\nthe leg keeps its X-lattice regression-guard purpose. Change is confined to the\n`if not ok_xy:` branch, so no program that passes (or cleanly fails) the xy16\nverify can change behavior.\n\nThe two known repros a16regpress.c (regalloc-out-of-registers) and a16scavnz.c\n(scavenger-p-not-gpr) fail MIR-verify under BOTH modes with identical\nsignatures (measured host-side). Both crash the a16 leg first, so via `check`\nthey already XFAIL'd at the short-circuit -- this is latent-gap closure: it\nmatters when a16 verifies clean but xy16 doesn't, or a sweep reaches the xy16\nleg directly. Python-only tool change (not vendor/) -> no 0002 patch regen.\n\nVerified: host MIR-verify signatures match KNOWN_ISSUES under both modes;\n`check` still PASS (known issue) for both; direct unit exercise proves the xy16\nleg now returns XFAIL (was CRASH); dev/run.sh xy16ops PASS + corpus-a16 5/6\nPASS with globals XFAIL (no row flip).\n\nPlan: docs/plans/2026-06-21-321-xy16-verify-leg-classify-known.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01MfznzHZwGwQHUDg7yjrJ8u
-->
