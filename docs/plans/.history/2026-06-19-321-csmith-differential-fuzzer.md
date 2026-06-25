| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/e865dff) | #321 CI: wire Csmith (Phase 5) + c-torture (Phase 3) as sampled, secret-gated jobs |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/9bdf5d4) | #321 csmith: finalize for merge — Phase 4 first finding (s32) FIXED, GO disposition |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/1d9fa68) | #321 csmith Phase 1-3: host-side differential runner + --gen dispatch |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/18c2c1f) | #321 csmith: record Phase 0 GO in the backlog + triage the deferral Inbox |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/d39d49b) | #321 csmith Phase 0: GO — differential fuzzer scaffolding + recorded verdict |

<!--history-meta v1
e865dff	author	Will Norris
e865dff	added	26
e865dff	deleted	4
e865dff	files	1
e865dff	body	Two new jobs in .github/workflows/smoke.yml, both `needs: xcheck` (reuse its cached\nfrom-source toolchain) and running the SAME 4-way differential gate (host == default\n== +mos-a16 == +mos-xy16 on MAME + +mos-a16 on bsnes-jg):\n\n- torture (in-container, mirrors corpus-a16): fetches the sha256-pinned suite on the\n  host, runs a seeded pseudo-random subset; full mode runs the whole in-scope set at\n  -Os and -O1.\n- fuzz-csmith (HOST-side, since dev/run.sh fuzz --gen csmith isn't Dockerized):\n  installs MAME, builds vendor/csmith, MOS_TOOLCHAIN -> host build path; sampled = 40\n  seeds, full = seeds 1..500.\n\nA `workflow_dispatch` `mode` input (sampled [default] / full) + `sample_seed` drive\nscope; a commented `schedule:` block (auto-selects full) is ready for when the repo\ngoes public. Both secret-gated: skip, not fail, without the SPC700 BIOS.\n\ntools/torture_run.py: add seeded `--sample N` / `--sample-seed S` (was sequential\n`--start`/count slice only — inscope.tsv is alphabetical, so a head slice clusters).\nDeterministic + clamps. Help updated in dev/torture.sh + dev/run.sh.\n\nLocal verification (the exact per-run CI commands, 4-way):\n  dev/run.sh fuzz --gen csmith 40 1      -> 36/40 PASS, 0 mismatch/crash/error\n  dev/run.sh torture --sample 150 --sample-seed 1 --opt -Os\n                                         -> 143 PASS, 0 FAIL, 7 SKIP, 0 XFAIL\nWorkflow YAML validates; embedded run-scripts shellcheck-clean (fixed a set -e abort\nin the mode-resolution: `[ x = y ] && MODE=full` -> `if [ x = y ]; then ...; fi`).\n\nDocs: both plan docs get a Phase 5 / Phase 3 RESULTS section; implementation-status +\nTODO flipped to done.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
9bdf5d4	author	Will Norris
9bdf5d4	added	11
9bdf5d4	deleted	2
9bdf5d4	files	1
9bdf5d4	body	The a16-unmerge-s32 legalizer gap this fuzzer surfaced is fixed on main (s32 as\n2x s16 under +mos-a16); the sweep re-runs 92/100 PASS, 0 xfail, 0 mismatch and\nthe XFAIL is removed. Update the plan (Phase 4 RESULT + GO/merge disposition)\nand the TODO (csmith item reflects the fix; drop the now-resolved standalone s32\nfinding item — main carries the canonical Done entry). Branch ready to merge.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
1d9fa68	author	Will Norris
1d9fa68	added	99
1d9fa68	deleted	8
1d9fa68	files	1
1d9fa68	body	tools/csmith_run.py drives Csmith-generated C through the existing\ndifferential engine: per-seed gen (run from examples/65816/csmith so\nplatform.info -> 16-bit int is read), host-side fit pre-filter\n(torture_filter.classify -> SKIP+counted), then\nevaluate(expected=None, cflags=..., verify=False) -- default-build-as-oracle.\n\na16_fuzz.py gains additive cflags=() on compile_rom / verify_machineinstrs /\nevaluate plus a verify=True gate (default-empty / default-True -> every\nexisting caller byte-for-byte unchanged). Two non-obvious bits the Phase-0\nspike flagged: the s32 legalizer ICE is an LTO *link* error (mos-clang aborts\nld.lld), so classify_known() now runs on the CompileError too, not just the\nverify log; and Csmith skips per-program verify (its <math.h> won't resolve\nunder bare --target=mos -- the --config link is the crash gate). New\na16-unmerge-s32 KNOWN_ISSUES entry XFAILs the long-split gap (a separate M2\ninvestigation -- not fixed here).\n\ndev/csmith.sh runs the path host-side (build-csmith-on-demand, BIOS check);\ndev/run.sh fuzz --gen csmith|builtin dispatches before the Docker step\n(csmith default, host-side; builtin unchanged, still in-container).\n\nSweep seeds 1-100: 83/100 PASS, 0 mismatch, 10 xfail (a16-unmerge-s32),\n7 skip (diverged-before-result) -- reproduces the Phase-0 spike. corpus 7/7,\ncorpus-a16 5/6+xfail, builtin fuzz 50/50 green; 0002 untouched (diff is\ntools/ + dev/ only).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
18c2c1f	author	Will Norris
18c2c1f	added	1
18c2c1f	deleted	1
18c2c1f	files	1
18c2c1f	body	Plan Status -> "Phase 0 DONE (GO); Phase 1 next". Promote the auto-captured Inbox\ndeferrals into curated TODO entries: a [wip] Csmith differential-fuzzer item under\nTest Bench / CI (Phase 0 GO d39d49b; remaining phases; Yarpgen follow-up), and a new\nM2 item for the +mos-a16 G_UNMERGE_VALUES s32 legalizer gap the spike found. The three\nInbox bullets are replaced with a triaged fp-ledger note (now covered by those entries).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d39d49b	author	Will Norris
d39d49b	added	224
d39d49b	deleted	0
d39d49b	files	1
d39d49b	body	Csmith 2.4.0 built via dev/fetch-csmith.sh (host-side; gitignored vendor/csmith) + the\nfreestanding adapter examples/65816/csmith/{csmith_snes.h,platform.info}: the adapter\nsuppresses csmith's platform_generic.h and writes the 16-bit-folded checksum to\ncorpus_result; platform.info (integer size=2) + type-parametric safe_math make Csmith\noutput UB-free at the target's 16-bit int -> the default-build-as-oracle differential is sound.\n\nSpike (seeds 1-100, host-side MAME): 83 agree, 0 mismatch, 17 skip/fail. 0 value\nmismatches => sound oracle => GO. 9 skip/fail are a REAL new +mos-a16 finding (s32\nG_UNMERGE_VALUES legalizer gap; default builds the same programs clean) surfaced by\nCsmith's use of `long` -- the payoff. 8 are harness SKIPs (diverging main -> GC'd\ncorpus_result). Verdict + Phase-1 fixes recorded in the plan.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
