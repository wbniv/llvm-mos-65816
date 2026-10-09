| Date | Change |
|------|--------|
| [2026-09-28](https://github.com/wbniv/llvm-mos-65816/commit/f4453fc5) | Publish reviewed 0065 upstream preparation and dashboard status |
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/42512bff) | docs: record near-store delivery and contributions page plan |
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/4d7136cb) | perf(mos): complete broader near-store profitability |

<!--history-meta v1
f4453fc5	author	Will Norris
f4453fc5	added	10
f4453fc5	deleted	3
f4453fc5	files	1
f4453fc5	body	Publish the exact-destination compiler extraction, matching-input validation, loaded-pointer fallback evidence, and separate independent 0065 review. Remove the completed T4 action and mark preparation complete while retaining the native feature posting hold and merge prerequisites. Preserve the local completion record and previously published compiler work.\n\nPreparation and publication assistance: OpenAI Codex CLI 0.158.0 (codex-tui), model gpt-6-astra, xhigh reasoning effort; verified session 01a0e75a-a9ed-7372-9bac-b19b732a46a2. Independent review: OpenAI Codex CLI 0.158.0 (codex-tui), model gpt-6-astra, xhigh reasoning effort; verified session 01a0e79c-b9af-7ed3-acf5-19074d8d761a. Earlier implementation credits are preserved in their records.
42512bff	author	Will Norris
42512bff	added	20
42512bff	deleted	1
42512bff	files	1
42512bff	body	Record downstream delivery of 0065, retain its upstream extraction and review gates, and synchronize current summaries and generated dashboard views. Preserve the pending public contributions-page design and earlier contributor credits.\n\nIntegration review: OpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra, xhigh reasoning effort; verified session 01a0e126-2178-79f3-adba-51b951fb1f96.
4d7136cb	author	Will Norris
4d7136cb	added	266
4d7136cb	deleted	0
4d7136cb	files	1
4d7136cb	body	Add standalone patch 0065 for indirect store-and-unit arithmetic, indirect\ncall results, zero-extended bytes, and absolute store-and-decrement. Keep\nthe smaller native sequence for loaded destination pointers and preserve\nthe atomic, call-live, and native-consumer exclusions.\n\nRetain identified baseline/candidate tools and matching-input evidence,\nadd code-generation and runtime regressions, and register the patch in\nbootstrap and regeneration. Record each T3 decision in the completion\nplan and refresh current summaries, dashboard views, and dependencies.\nUpstream #321 extraction and independent review remain separately tracked.\n\nValidation: 486 reduced comparisons, 72 smaller and none larger; 179 MOS\ntests pass with two unsupported; the 412-input corpus has no new failures\nor size increases. Only the new fixture changes in the existing-corpus\ncomparison, saving 35 bytes per native mode. MAME and bsnes-jg agree with\nthe host; installed-toolchain reruns and patch round trip pass. Captured\nMIR and logs retain the original tool-output bytes, including whitespace.\n\nAssisted-by: OpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra,\nxhigh reasoning effort; verified session\n01a0e0ee-df60-7d80-8629-5ad167a8c407.
-->
