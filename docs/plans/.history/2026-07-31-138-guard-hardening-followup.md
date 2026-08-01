| Date | Change |
|------|--------|
| [2026-07-31](https://github.com/wbniv/llvm-mos-65816/commit/16021b2) | docs(plan): 138 follow-up — record the CI cancel/supersede, the concurrent TA hardening (3ce98fed82de), and the body-regression re-correction |
| [2026-07-31](https://github.com/wbniv/llvm-mos-65816/commit/8334efa) | docs(plan): #138 guard-hardening follow-up — hardened guard shipped (PR #584 @ 7eedb14a2597), overclaimed repro count corrected to measured matrix |

<!--history-meta v1
16021b2	author	Will Norris
16021b2	added	8
16021b2	deleted	0
16021b2	files	1
16021b2	body	Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8334efa	author	Will Norris
8334efa	added	194
8334efa	deleted	0
8334efa	files	1
8334efa	body	Post-hoc review of the #138 fix produced four findings; this plan is the\ncontract + verification record for closing them: (1) combineLdImm guard now\ninvalidates aliased GPR tracking before the skip (behaviour-identical today,\nsurvives future LDImm dest-class widening; 4/4 late-opt lit green on the\nrebuilt toolchain); (2) TA-handler sibling shape noted in the PR, deliberately\nuntouched; (3) vanished Imag32-LDImm producer filed as a T3 TODO item with a\nstanding-scan half; (4) PR body's live-byte claim was measured false both\nhalves (3 live bytes crash at O1+, 2 at -Oz, vs the claimed smallest-8 /\n4-doesn't-crash) — corrected in the PR body, PR doc, and repro comment.\n\nTODO.md edit rides uncommitted on the hot tree (foreign unstaged edits).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
