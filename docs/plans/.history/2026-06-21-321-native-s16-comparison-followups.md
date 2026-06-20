| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/e1f77a8) | #321 native s16 compare follow-ups: Phase 0 step 3 byte-diff -> GO (+3..6 B/site) |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/1142a49) | #321 native s16 comparison follow-ups: plan + Phase 0 step-1 audit |

<!--history-meta v1
e1f77a8	author	Will Norris
e1f77a8	added	26
e1f77a8	deleted	2
e1f77a8	files	1
e1f77a8	body	Ordering-as-value materializes as a CFG diamond (zext(i1 sbc-carry) -> G_SELECT\n-> MOSLowerSelect). Branchless rol-tail measured 25->19 B (UGE, -6) / 25->22 B\n(ULT +eor, -3): clean per-site win, broad (all ordering-value cells), modest\naggregate (value form rarer than branch). Implementation (legalizer rewrite of\nzext(sbc-carry) -> G_UADDE(0,0,carry)) unblocked.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
1142a49	author	Will Norris
1142a49	added	191
1142a49	deleted	0
1142a49	files	1
1142a49	body	The compare surface measured ~complete (dev/measure-compare-surface.sh, the full\npredicate × operand-shape × value/branch matrix at +mos-a16 -Os): every ordering\nvalue cell + equality-vs-memory/computed/imm is NATIVE rep/lda/cmp; only\nregister-resident equality stays byte-wise (cpx;cmp, measured-optimal). The one\nunexplored lever is the ordering-as-VALUE materialization — a select-diamond today;\ncandidate: a branchless G_UADDE(0,0,carry) -> `lda #0; adc #0` tail, distinct from\nthe rejected EQ rol-tail because `cmp` yields the carry directly (no compute-the-\nvalue cost). Phase 0 steps 2 (frequency) + 3 (byte-diff go/no-go spike, needs a\nworktree) pending. Measurement-gated close-out, not a big feature.\n\nPlan: docs/plans/2026-06-21-321-native-s16-comparison-followups.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
