| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/4a7a46b) | #321 xy16 seed247/445 — root cause FOUND + verified; fix scoping doc (scope-first) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/ba93049) | #321 xy16 seed445/247 Track B — Phase A+B tooling: dev-setup task + cvise interestingness test |

<!--history-meta v1
4a7a46b	author	Will Norris
4a7a46b	added	54
4a7a46b	deleted	1
4a7a46b	files	1
4a7a46b	body	Reduced seed 445 (cvise, dev/reduce-xy16.sh) to an 8-line UB-free repro and root-caused\nthe +mos-xy16-only miscompile, verified twice on both emulators:\n\n  A 16-bit value (g_21, selected into the Xc16 index-register class) is left LIVE in X\n  across a `sep #$10` that MOSInsertREPSEP inserts for an unrelated 8-bit `ldy`. On the\n  65816, narrowing the shared index-width flag to 8-bit ZEROES XH/YH — destroying the\n  high byte. corpus_result: want 0x0002, got 0x0000 (g_21 itself: 0x0216 -> 0x0016).\n\nNOT the requiredXWidth tweak the plan assumed: XH/YH are modeled (MOSRegisterInfo.td:114)\nbut nothing models index-narrowing as clobbering them (SEP has no Defs; MOSInsertREPSEP is\npost-RA, its lattice is per-instruction). So regalloc kept a 16-bit index value live across\nan 8-bit-index op — impossible on hardware (X/Y share one width flag).\n\nPer the user's scope-first decision, NO codegen changed. docs/investigations/\n65816-xy16-index16-highbyte-clobber.md scopes three fixes and recommends approach A (a\npre-RA, HasIndex16-gated pass marking 8-bit-index ops as clobbering XH/YH so regalloc\nspills live 16-bit index values). Awaiting approval before implementing.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
ba93049	author	Will Norris
ba93049	added	197
ba93049	deleted	0
ba93049	files	1
ba93049	body	Execution start of docs/plans/2026-06-20-321-xy16-seed445-cvise-reduction.md (the real fix\nfor the +mos-xy16-only Csmith miscompile; disambiguation in f410115 proved it a genuine\ncompiler bug on BOTH emulators, so reduce-then-root-cause, not guess).\n\n- Taskfile `dev-setup`: idempotent host-prereq installer (cvise for C-reduction of fuzz\n  repros); the home for future host prereqs.\n- dev/reduce-xy16.sh: cvise/creduce interestingness test. TARGET-ONLY multi-config\n  differential — interesting iff V(default-Os)==V(default-O0)==V(a16-Os) and != V(xy16-Os),\n  all read from bsnes-jg headless (load-insensitive => parallel-safe; MAME not used). No x86\n  host oracle is possible (Csmith int is 16-bit, x86's is 32-bit). Validated: INTERESTING on\n  seeds 445 & 247, boring on a trivial TU; frame budget 90 covers the slow -O0 oracle.\n\nReduction of seed 445 (preprocessed 852-line standalone TU) is running; the minimal repro +\nroot-cause + the vendor/ fix (on wt/321-xy16) land next.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
