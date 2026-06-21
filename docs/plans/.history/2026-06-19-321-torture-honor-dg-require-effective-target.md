| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/8622e3f) | #321 c-torture: honor dg-require-effective-target — drop the pr7284-1 false positive |

<!--history-meta v1
8622e3f	author	Will Norris
8622e3f	added	96
8622e3f	deleted	0
8622e3f	files	1
8622e3f	body	The differential oracle ("default build self-checks PASS") is necessary but not sufficient:\na test relying on UB our 16-bit-int target resolves differently can pass default by\nUB-luck and "fail" +mos-a16 as a false positive. pr7284-1 carries\n{ dg-require-effective-target int32plus } and shifts n<<24 (UB on 16-bit int) — exactly that gap.\n\ntools/torture_filter.py now parses dg-require-effective-target and buckets a test as\ndg-require-unsupported (before building) when it requires an integer width our target can't\nprovide. Deny set = {int32plus, int128} — only the provably-unsatisfiable integer-width\nrequirements, so a misclassification can only skip a target-inappropriate test, never drop a\nvalid one. label_values/indirect_jumps are NOT denied (computed goto works — 20071210-1 passes).\n\nRe-filter: in-scope 1253 -> 1228 (58 dg-require-unsupported; counts sum to 1656,\ndeterministic). pr7284-1 moves to unsupported.tsv and is removed from xfails.tsv. Harness\nonly — no vendor/llvm-mos or 0002 change.\n\nBacklog now: 4 real c-torture defects (pr49419, 20041011-1, doloop-1, va-arg-22) + the\nnewly-surfaced pre-existing k_isort xy16 miscompile (tracked separately).\n\nPlan: docs/plans/2026-06-19-321-torture-honor-dg-require-effective-target.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01FbDXYbhvNuPv7B7SPgPLes
-->
