| Date | Change |
|------|--------|
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/4d7136cb) | perf(mos): complete broader near-store profitability |

<!--history-meta v1
4d7136cb	author	Will Norris
4d7136cb	added	266
4d7136cb	deleted	0
4d7136cb	files	1
4d7136cb	body	Add standalone patch 0065 for indirect store-and-unit arithmetic, indirect\ncall results, zero-extended bytes, and absolute store-and-decrement. Keep\nthe smaller native sequence for loaded destination pointers and preserve\nthe atomic, call-live, and native-consumer exclusions.\n\nRetain identified baseline/candidate tools and matching-input evidence,\nadd code-generation and runtime regressions, and register the patch in\nbootstrap and regeneration. Record each T3 decision in the completion\nplan and refresh current summaries, dashboard views, and dependencies.\nUpstream #321 extraction and independent review remain separately tracked.\n\nValidation: 486 reduced comparisons, 72 smaller and none larger; 179 MOS\ntests pass with two unsupported; the 412-input corpus has no new failures\nor size increases. Only the new fixture changes in the existing-corpus\ncomparison, saving 35 bytes per native mode. MAME and bsnes-jg agree with\nthe host; installed-toolchain reruns and patch round trip pass. Captured\nMIR and logs retain the original tool-output bytes, including whitespace.\n\nAssisted-by: OpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra,\nxhigh reasoning effort; verified session\n01a0e0ee-df60-7d80-8629-5ad167a8c407.
-->
