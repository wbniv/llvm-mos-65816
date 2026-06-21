| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/93862b3) | M1 Phase 0: build llvm-mos from source (lean) + green baseline |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/dc88c35) | docs: plan M1 Phase 0 (from-source llvm-mos toolchain) + TODO |

<!--history-meta v1
93862b3	author	Will Norris
93862b3	added	34
93862b3	deleted	10
93862b3	files	1
93862b3	body	Codegen work (M1 #320) can't begin on the prebuilt, immutable toolchain.\nThis stands up a from-source llvm-mos build in the dev container and proves\nthe regression corpus stays green on the self-built compiler.\n\n- dev/toolchain.sh: clone llvm-mos, build clang/lld via the MOS.cmake cache\n  (Release, lld, 1 link job, ccache) -> build/llvm-mos-install. Trims the\n  distribution to clang+lld (idempotent sed drop of clang-tools-extra:\n  clangd/clang-tidy/include-fixer/...), cutting a cold build 39.2 -> 26.1 min.\n- dev/Dockerfile: host clang/lld/ccache (+zlib) to build LLVM; lld + Release\n  keep peak link memory under the 14 GiB host ceiling.\n- dev/build.sh: MOS_TOOLCHAIN selects the toolchain (default prebuilt). CMake\n  can't hot-swap the cross-compiler, so wipe the SDK build tree (only) when\n  MOS_TOOLCHAIN changes, tracked via build/.mos-toolchain.\n- dev/run.sh: `toolchain` target; forward MOS_TOOLCHAIN/BUILD_JOBS.\n\nVerification (2026-06-14): toolchain builds (clang 23.0.0git @ c798c31,\nTarget: mos); MOS_TOOLCHAIN=...llvm-mos-install build+corpus -> 7/7 (byte-\nidentical to prebuilt: same builtins.a, same expected values); default\nprebuilt path round-trips green (self-built<->prebuilt wipe verified both\nways). The self-built compiler is byte-equivalent to the prebuilt — only\nnow it's one we can edit for #320.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
dc88c35	author	Will Norris
dc88c35	added	130
dc88c35	deleted	0
dc88c35	files	1
dc88c35	body	M1 (#320 far pointers) is the first real backend codegen — impossible\nwithout building llvm-mos from source (the bench uses a prebuilt, immutable\ntoolchain). Phase 0 scopes that foundation + a green corpus baseline on the\nself-built compiler; the #320 data-layout work is deferred to an\nupstream-coordinated follow-up.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
