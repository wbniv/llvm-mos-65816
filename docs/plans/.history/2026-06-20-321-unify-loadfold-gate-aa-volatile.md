| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/8acc183) | #321 plan: unify the a16 load-fold gate (AA-precise + single-use-volatile) — measurement-gated |

<!--history-meta v1
8acc183	author	Will Norris
8acc183	added	162
8acc183	deleted	0
8acc183	files	1
8acc183	body	Spin the load-fold-call-hazard audit's §Deferred bullet into a standalone,\nmeasurement-gated plan. Today two gates split two capabilities:\nshouldFoldMemAccess is AA-precise (folds across a provably non-aliasing store)\nbut bails on all volatile; noStoreBetween is single-use-volatile-tolerant but\nbails on any intervening store. Plan = merge into one helper holding both —\ndrop the blanket volatile bail for a single-use clamp (Volatile && NumUsers!=1\n-> bail), and thread AA into foldableAbsLoad16/foldableIndirLoad16 for the\nmayAlias check. Symmetry: AA-precision recovers 16-bit-side folds, the\nvolatile-drop 8-bit-side folds (+ fixes today's compare-vs-store asymmetry).\n\nPhase 1 is a throwaway instrument-and-count (compile-only) over the a16 corpus\n+ c-torture + Csmith; both recoverable counts ~0 => DEFER-confirm. Correctness\nanalysis (1-access-preserving, ordering-safe, AA composes) shows zero\nregression risk. shouldFoldMemAccess is upstream MOS => the volatile relaxation\nis flagged an upstream-contribution candidate. TODO M2 bullet added.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
