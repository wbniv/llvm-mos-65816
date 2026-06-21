| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/3aa2944) | #320 far-calls follow-ups: plan (a) far fn pointers + (b) mixed-banking |

<!--history-meta v1
3aa2944	author	Will Norris
3aa2944	added	316
3aa2944	deleted	0
3aa2944	files	1
3aa2944	body	Probes reshaped scope before committing the plan:\n- far->far already works (non-leaf JSL/RTL chains); (b) = far->near only.\n- (a) far fn pointers blocked on a front-end: address_space(2) is forbidden on\n  function types (clang Sema), far/long_call attr is MIPS-only, &far_fn yields\n  only 16 bits today. Recommend (b) first (backend-only), then (a) backend, then\n  (a) front-end (F1 builtin / F2 MOS far attr [rec] / F3 far-fn-ptr type).\nDesigns: (b) bank-0 veneer (jsr g; rtl) reached by JSL; (a) __call_indir_far\n(jml [__rc18]) mirroring the near __call_indir.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
