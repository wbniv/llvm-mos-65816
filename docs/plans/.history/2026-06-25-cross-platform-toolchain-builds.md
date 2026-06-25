| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/ebac767) | plan: cross-platform toolchain builds (macOS arm64, Windows x86_64, Linux arm64) cross-compiled from the Linux Docker |

<!--history-meta v1
ebac767	author	Will Norris
ebac767	added	140
ebac767	deleted	0
ebac767	files	1
ebac767	body	New docs/plans/2026-06-25-cross-platform-toolchain-builds.md + a Distribution/\nPackaging TODO item. Decisions locked via Q&A: targets = macos-arm64 +\nwindows-x86_64 + linux-arm64 (plus the existing linux-x86_64); approach =\ncross-compile from the existing Ubuntu x86-64 Docker (no mac/Win CI runners).\n\nKey design: only the host binaries (clang/lld/llvm-*) differ per platform —\nthe MOS builtins + clang headers + SNES SDK are host-agnostic and copied once\nfrom the canonical Linux build, so cross builds disable the runtimes sub-build\nand reuse the native tablegens via LLVM_NATIVE_TOOL_DIR. Risk-ordered\nincrements: 0 refactor (host-parameterize toolchain.sh + package-release.sh,\nLinux byte-identical) → 1 linux-arm64 (qemu self-test) → 2 windows-x86_64\n(mingw + wine) → 3 macos-arm64 (osxcross + a user-supplied macOS SDK, the one\nmanual ask) → 4 task package-all.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01UFzfnhDq55ttkAyXt724ZX
-->
