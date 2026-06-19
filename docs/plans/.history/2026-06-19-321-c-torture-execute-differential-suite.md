| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/15542ff) | #321 c-torture Phase 1: pilot finds a real a16 ZP-pressure overflow (pr15296.c) |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/8085d2a) | #321 c-torture Phase 0: fetch + host-side compile/link filter (1253/1656 in-scope) |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/34cd16a) | #321 plan: vendor GCC c-torture/execute behind the +mos-a16/+mos-xy16 differential gate |

<!--history-meta v1
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
