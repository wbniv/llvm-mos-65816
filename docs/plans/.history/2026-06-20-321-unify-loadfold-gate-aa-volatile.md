| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/3aa6908) | #321 loadfold-unify Phase 1: instrument-and-count says PROCEED (both probes fire) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/8acc183) | #321 plan: unify the a16 load-fold gate (AA-precise + single-use-volatile) — measurement-gated |

<!--history-meta v1
3aa6908	author	Will Norris
3aa6908	added	55
3aa6908	deleted	1
3aa6908	files	1
3aa6908	body	Ran the plan's Phase-1 gate on a throwaway worktree (throwaway/loadfold-unify-\nmeasure): an instrumented mos-clang whose two probes log-and-bail (codegen\nunchanged) over 53 a16 micro-tests + 1228 in-scope c-torture = 2615 compiles,\ncompile-only.\n\nResult — both probes fire, confirming the plan's predicted symmetry exactly:\n  Probe A (AA-precision recovers a 16-bit fold): 7 distinct sites, all\n    G_LOAD16_ABS; 5 are real c-torture programs (990128-1, packed-1, pr43236,\n    pr85529-1, zero-struct-1) — a non-aliasing store between an abs 16-bit load\n    and its use that noStoreBetween drops but mayAlias would keep.\n  Probe B (single-use-volatile recovers a fold): 43 distinct sites —\n    G_LOAD_ABS 8-bit x30 (the volatile-MMIO idiom the upstream volatile-bail\n    blocks) + G_LOAD16_ABS store-side x11 (EXACTLY the compare-vs-store\n    asymmetry the plan flagged) + 2 indirect.\n\nDecision: PROCEED to Phase 2 (implement the unified helper + byte-diff these\nfixtures + full differential). Honest caveat recorded: this counts foldable\nsites, not bytes saved — Phase 2's byte-diff is still the payoff gate.\n\nDurable artifacts kept: dev/measure-loadfold-recovery.sh (the harness, runs from\nmain), plan §"Phase 1 — RESULTS" (verdict + probe diff for reproducibility), TODO\nM2 bullet updated. Throwaway worktree + probe-patched vendor torn down.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8acc183	author	Will Norris
8acc183	added	162
8acc183	deleted	0
8acc183	files	1
8acc183	body	Spin the load-fold-call-hazard audit's §Deferred bullet into a standalone,\nmeasurement-gated plan. Today two gates split two capabilities:\nshouldFoldMemAccess is AA-precise (folds across a provably non-aliasing store)\nbut bails on all volatile; noStoreBetween is single-use-volatile-tolerant but\nbails on any intervening store. Plan = merge into one helper holding both —\ndrop the blanket volatile bail for a single-use clamp (Volatile && NumUsers!=1\n-> bail), and thread AA into foldableAbsLoad16/foldableIndirLoad16 for the\nmayAlias check. Symmetry: AA-precision recovers 16-bit-side folds, the\nvolatile-drop 8-bit-side folds (+ fixes today's compare-vs-store asymmetry).\n\nPhase 1 is a throwaway instrument-and-count (compile-only) over the a16 corpus\n+ c-torture + Csmith; both recoverable counts ~0 => DEFER-confirm. Correctness\nanalysis (1-access-preserving, ordering-safe, AA composes) shows zero\nregression risk. shouldFoldMemAccess is upstream MOS => the volatile relaxation\nis flagged an upstream-contribution candidate. TODO M2 bullet added.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
