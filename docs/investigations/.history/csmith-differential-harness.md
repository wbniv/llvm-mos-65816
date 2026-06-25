| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/80af866) | docs(investigations): Csmith differential harness — already-built reference + the WDC816CC/Plum Hall origin |

<!--history-meta v1
80af866	author	Will Norris
80af866	added	256
80af866	deleted	0
80af866	files	1
80af866	body	Consolidate the scattered facts about the existing Csmith differential\nfuzzer (dev/csmith.sh, tools/csmith_run.py, tools/a16_fuzz.py, the\nexamples/65816/csmith adapter, the fuzz-csmith CI job, the plan, the TODO\nitem) into one navigable investigation doc, so the next person doesn't\nrebuild what's already merged (dd5616b; CI e865dff).\n\nRecords the two strategic questions that motivated it: why build an open\noptimizing toolchain when WDC816CC is free (gratis≠libre; WDC-silicon-only\nlicense; closed binary can't be byte-shaved), and how to get "Plum Hall\nvalidated" or similar (the C frontend is inherited from upstream Clang; the\nunproven surface is the 65816 backend, so execution-differential testing —\nthis harness — is the higher-value, reproducible answer).\n\nNo code change; one new Markdown file.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01UFzfnhDq55ttkAyXt724ZX
-->
