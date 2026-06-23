| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/25ea71c) | #321 native-s16: knock out the surface-consolidation close-out (TODO finalization) |

<!--history-meta v1
25ea71c	author	Will Norris
25ea71c	added	86
25ea71c	deleted	0
25ea71c	files	1
25ea71c	body	The consolidation measurement, roll-up script, and ROADMAP/upstream cascade\nalready landed (95d65df/866d530/a584a78). This finishes the TODO finalization\nthe plan deferred:\n\n- Promote the consolidation item to Done (Phase 0 measured-complete; its stated\n  "Remaining doc touches" — ROADMAP §5 + upstream paragraph — already landed).\n  The Done entry records the honest MIXED a16-vs-default step-5 result\n  (sustained-16-bit class wins -22%/-220 B aggregate; interleave stress kernels\n  regress by-design → confirms opt-in/per-op gating) and the single shared\n  deferred core.\n- Collapse the three scattered deferrals into one: A16-threading Phase 3,\n  ALU-chain >14-live, and the globals.c -Os RA-crash each now carry the same\n  "shared core (RA-level 16-bit residency under pressure), one trigger, one\n  B0->B1->B2 spike" clause cross-referencing the close-out.\n\nNo drift: re-ran dev/measure-native-s16-surface.sh — step-5 table and 0/13\npool-exhaust reproduce; MEASURED-COMPLETE, nothing to build. Corpus unchanged\nby construction (TODO-only; no codegen touched). Adds the migrated close-out\nplan referenced by the Done entry.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
