| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/ba93049) | #321 xy16 seed445/247 Track B — Phase A+B tooling: dev-setup task + cvise interestingness test |

<!--history-meta v1
ba93049	author	Will Norris
ba93049	added	197
ba93049	deleted	0
ba93049	files	1
ba93049	body	Execution start of docs/plans/2026-06-20-321-xy16-seed445-cvise-reduction.md (the real fix\nfor the +mos-xy16-only Csmith miscompile; disambiguation in f410115 proved it a genuine\ncompiler bug on BOTH emulators, so reduce-then-root-cause, not guess).\n\n- Taskfile `dev-setup`: idempotent host-prereq installer (cvise for C-reduction of fuzz\n  repros); the home for future host prereqs.\n- dev/reduce-xy16.sh: cvise/creduce interestingness test. TARGET-ONLY multi-config\n  differential — interesting iff V(default-Os)==V(default-O0)==V(a16-Os) and != V(xy16-Os),\n  all read from bsnes-jg headless (load-insensitive => parallel-safe; MAME not used). No x86\n  host oracle is possible (Csmith int is 16-bit, x86's is 32-bit). Validated: INTERESTING on\n  seeds 445 & 247, boring on a trivial TU; frame budget 90 covers the slow -O0 oracle.\n\nReduction of seed 445 (preprocessed 852-line standalone TU) is running; the minimal repro +\nroot-cause + the vendor/ fix (on wt/321-xy16) land next.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
