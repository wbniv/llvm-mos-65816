| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/bae20ba) | #321 c-torture suite plan: record the Phase-2 backlog resolution |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/215f74d) | #321 c-torture Phase 2 -Os: 2 new miscompiles (pr34768), 1 flake, triage notes |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/0d76bfc) | #321 c-torture Phase 2 (-O1): 16 confirmed NEW a16/xy16 runtime miscompiles |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/15542ff) | #321 c-torture Phase 1: pilot finds a real a16 ZP-pressure overflow (pr15296.c) |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/8085d2a) | #321 c-torture Phase 0: fetch + host-side compile/link filter (1253/1656 in-scope) |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/34cd16a) | #321 plan: vendor GCC c-torture/execute behind the +mos-a16/+mos-xy16 differential gate |

<!--history-meta v1
bae20ba	author	Will Norris
bae20ba	added	30
bae20ba	deleted	0
bae20ba	files	1
bae20ba	body	Update the umbrella plan to reflect the same-day triage outcome: the "diverse, several\ndistinct bugs" expectation was wrong for the a16 cases — 13 of 18 rows were ONE root\ncause (the CmpBrAbsImm16 frame-index scramble, f2d65c2); the pr7284-1 false positive was\nremoved via dg-require (8622e3f, in-scope 1253->1228); pr49419's a16 leg was fixed too,\nleaving it xy16-only. Remaining backlog = 4 defects, ALL xy16, prime suspect the shared\nMOSInsertREPSEP X-flag lattice. Docs only.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01FbDXYbhvNuPv7B7SPgPLes
215f74d	author	Will Norris
215f74d	added	19
215f74d	deleted	0
215f74d	files	1
215f74d	body	-Os full pass: 2 new confirmed miscompiles pr34768-1/-2 (a16+xy16, both\nemulators) — PR34768 const-indirect-call. Root-caused to the LTO level:\nper-function 65816 asm is correct (test reloads x post-call; foo negates\nright; neither clobbers __rc20/tmp), so the bug is whole-program LTO\nwrongly treating (c?foo:bar)() as side-effect-free because bar is const.\nA pipeline interaction, not per-instr selection (seed-42-shaped).\n\nAlso: pr40404 "build fails" was a FLAKE (builds clean 3/3 host-side);\n20020402-1 + 20041011-1 XPASS at -Os (opt-level-specific, rows stay);\npr7284-1 is a false positive (int32plus / UB on 16-bit int). Net genuine\ndistinct miscompiles: 17 (15 @ -O1 + 2 @ -Os). xfails.tsv + plan updated.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
0d76bfc	author	Will Norris
0d76bfc	added	58
0d76bfc	deleted	20
0d76bfc	files	1
0d76bfc	body	Full -O1 differential pass over all 1253 in-scope tests:\n1098 PASS, 136 SKIP, 3 known-XFAIL (a16-zp-pressure-overflow) + 16 FAIL.\n\nAll 16 FAILs re-run in isolation on a quiet box with bsnes-jg REPRODUCED\n(zero flakes); every a16 case agrees on both MAME and bsnes-jg. They are\nNEW runtime wrong-value miscompiles (default self-checks PASS, a16/xy16\nwrites 0xDEAD) — not the known register-pressure family — and diverse\n(packed structs, nested struct/arrays, memset, varargs, signed left-shift,\ncomputed-goto, counted loops at INT limits) => likely several distinct\na16/xy16 codegen bugs. This is the payoff of the external suite: real bugs\nthe home-grown tests never hit.\n\nRecorded in examples/65816/torture/xfails.tsv (expected-fail manifest);\ntorture_run.py now reports a listed test as XFAIL (and a fixed one as\nXPASS -> "remove the row"), so the gate is green-modulo-known. Per-defect\nroot-cause is the open backlog (new TODO item). No vendor/llvm-mos change.\n\nNote: the -Os pass didn't run (the runner left orphan MAME children that\nhung teardown after -O1, and set -e stopped the chained pass); the 16 are\nunaffected (confirmed isolated). -Os rerun + orphan-reaping are follow-ups.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
15542ff	author	Will Norris
15542ff	added	68
15542ff	deleted	21
15542ff	files	1
15542ff	body	120-test differential pilot (40 @ -Os, 40 @ -O1, 40 @ -O1 over pr*):\n102 PASS, 17 SKIP, 1 XFAIL. All four classification paths exercised; the\nrunner is correct.\n\nThe one FAIL, pr15296.c, is a REAL +mos-a16 -O1/-Os defect: the a16 build\nallocates so many Imag16 zero-page pairs that .zp.noinit grows past 256 B\nand an 8-bit ZP relocation overflows (R_MOS_ADDR8 out of range). DEFAULT\n8-bit and +mos-a16 -O0 link clean; -O1/-Os fail — the SAME register-\npressure root cause as the globals.c RA crash, a different symptom (link\nZP overflow vs RA crash). Added KNOWN_ISSUES["a16-zp-pressure-overflow"]\nso the gate XFAILs it (the fuzzer is unaffected — it never feeds link\nerrors to classify_known); recorded as a "related manifestation" in the\nRA-pressure investigation. Fix home: the deferred A16-threading Phase 3.\n\nPlan: Phases 0+1 marked DONE, Phase 1 RESULTS + verification filled.\nNo vendor/llvm-mos or 0002 change.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8085d2a	author	Will Norris
8085d2a	added	76
8085d2a	deleted	30
8085d2a	files	1
8085d2a	body	Phase 0 of the GCC c-torture/execute differential suite (plan\n2026-06-19-321-c-torture-execute-differential-suite.md):\n\n- dev/fetch-torture.sh — pinned gcc-14.2.0 (sha256 a7b39bc6…f3cc9),\n  extracts only gcc.c-torture/execute into gitignored vendor/c-torture/.\n  Idempotent; fetch-don't-commit (GPLv3 stays out of the Apache repo).\n- examples/65816/torture/_shim.c — adapts a self-checking torture test\n  onto the corpus_result value-readback model (PASS 0x600D / FAIL 0xDEAD).\n  Precompiled to _shim.o and linked against each test, because -Dmain=…\n  applies to all TUs (would otherwise rename the shim's own main).\n- tools/torture_filter.py — host-only, default-build-only compile/link\n  filter (parallel, no emulator). Partitions the suite into in-scope vs\n  unsupported with a reason bucket per excluded test; sanitized portable\n  diagnostics; deterministic (byte-identical across runs).\n- examples/65816/torture/{inscope,unsupported}.tsv — the manifests:\n  1253/1656 in-scope; 403 unsupported (197 compile-error, 176\n  undefined-symbol [168 = printf/__putchar], 26 link-other, 4\n  region-overflow). builtins/ + ieee/ excluded by design.\n\nNo vendor/llvm-mos or 0002 change — test-harness only. Plan + TODO updated\n(item now [wip]; Phases 1-3 pending).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
34cd16a	author	Will Norris
34cd16a	added	150
34cd16a	deleted	0
34cd16a	files	1
34cd16a	body	Plan to slot the de-facto-standard execution-correctness suite (~1,500\nself-checking abort()/exit(0) programs) into the existing differential\nengine (tools/a16_fuzz.py). Key design: the default (non-a16) llvm-mos\nbuild is the trusted oracle — a test is in-scope iff default runs it to\nthe PASS sentinel, and among in-scope tests any +mos-a16/+mos-xy16\ndisagreement is a real defect. This sidesteps the 16-bit-int target\nsuitability question and mirrors the corpus-a16 model at much larger\nscale. Fetch-don't-commit (GPLv3, sha256-pinned, gitignored — the\nWDC816CC/ORCA refs precedent). Phased: fetch + host-only compile/link\nfilter; shim adapter + pilot; scale + triage; sampled secret-gated CI.\nTODO entry under Test Bench / CI.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
