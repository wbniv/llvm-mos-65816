| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/34cd16a) | #321 plan: vendor GCC c-torture/execute behind the +mos-a16/+mos-xy16 differential gate |

<!--history-meta v1
34cd16a	author	Will Norris
34cd16a	added	150
34cd16a	deleted	0
34cd16a	files	1
34cd16a	body	Plan to slot the de-facto-standard execution-correctness suite (~1,500\nself-checking abort()/exit(0) programs) into the existing differential\nengine (tools/a16_fuzz.py). Key design: the default (non-a16) llvm-mos\nbuild is the trusted oracle — a test is in-scope iff default runs it to\nthe PASS sentinel, and among in-scope tests any +mos-a16/+mos-xy16\ndisagreement is a real defect. This sidesteps the 16-bit-int target\nsuitability question and mirrors the corpus-a16 model at much larger\nscale. Fetch-don't-commit (GPLv3, sha256-pinned, gitignored — the\nWDC816CC/ORCA refs precedent). Phased: fetch + host-only compile/link\nfilter; shim adapter + pilot; scale + triage; sampled secret-gated CI.\nTODO entry under Test Bench / CI.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
