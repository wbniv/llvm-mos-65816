| Date | Change |
|------|--------|
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/c3c1967c) | mos: add and measure experimental competing-carry gate |

<!--history-meta v1
c3c1967c	author	Will Norris
c3c1967c	added	246
c3c1967c	deleted	0
c3c1967c	files	1
c3c1967c	body	Add patch 0067 with off, always and gated scheduling policies. The gate\nexcludes cheap constants, provisional frame carries and boundary users,\nthen requires potentially overlapping computed carries. Preserve always\nas the default because the full evaluation rejects default promotion.\n\nThe 3,720-configuration census has 3,592 successful three-way comparisons\nand no policy-specific compile failures. Gated recovers the 32 original\ngrowing configurations, but gives up 6.81% of the aggregate saving and\nleaves four growth cases without fewer carry materializations.\n\nRetain measured runtime and compile-time results, exact inputs, identities,\nROMs and profiles. All 30 originally growing SNES cases recover off-policy\nclock counts; the targeted sum/rotate gains remain. Compile-time ranges\noverlap, so make no compile-speed claim. Qualify the XY16 VLA oracle\nmismatch reproduced on the preserved baseline and all three policies.\n\nDocument the causal explanation, rejected refinements and acceptance\noutcome; update current summaries and generated views while preserving\ndated baselines and the withdrawn upstream packet.\n\nValidation: 181 MOS tests pass (2 unsupported); 4 counter tests pass;\n32 always-policy outputs match the preserved pre-gate compiler; 64 final\npolicy comparisons match the frozen measured arms; patch application\nreproduces all four final source/test files. Runtime passes 78/79 corpus\ninputs and all 50 signed-32-bit fuzz seeds, with the baseline VLA mismatch\nretained. Structured evidence and documentation dependency checks pass.\n\nAI attribution: OpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra,\nxhigh reasoning effort; verified session\n01a0e126-2178-79f3-adba-51b951fb1f96.
-->
