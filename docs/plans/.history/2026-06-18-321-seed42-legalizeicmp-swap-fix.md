| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/b2e139c) | #321 docs: dedicated plan for the seed-42 legalizeICmp fix + agent-handoff lessons |

<!--history-meta v1
b2e139c	author	Will Norris
b2e139c	added	156
b2e139c	deleted	0
b2e139c	files	1
b2e139c	body	- docs/plans/2026-06-18-321-seed42-legalizeicmp-swap-fix.md: full write-up of\n  the seed-42 default-build miscompile — defect, root cause (un-gated EQ-\n  canonicalization swap in 0002 legalizeICmp), the isolated-worktree + ccache\n  bisection table, the one-line fix, and verification (raw output per the plan\n  format).\n- docs/agent-handoff.md: two reusable lessons under the correctness-gate\n  section — (1) gating discipline: the differential fuzzer guards the DEFAULT\n  build, so every +mos-a16 change (incl. operand canonicalizations/predicates)\n  must be gated on the feature predicate, not a looser operand-shape test;\n  (2) the isolated-worktree + ccache-reuse build bisection technique for\n  attributing a fuzzer/regression finding to a specific patch/hunk.\n- TODO.md + the a16ret plan step-3 note: cross-link the dedicated fix plan.\n\nDocs only.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
