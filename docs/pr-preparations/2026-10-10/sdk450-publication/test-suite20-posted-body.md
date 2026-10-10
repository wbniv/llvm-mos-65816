Adds `SingleSource/UnitTests/longjmp-zero.c`, a regression test for [llvm-mos-sdk#450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450), which makes `longjmp(env, 0)` return one from `setjmp` as C requires. The review there asked for the test to live in llvm-test-suite instead of the SDK.

The test jumps with 0, 1, 7, 256 and -1 and exits nonzero on the first value where `setjmp` returns something other than the value (or 1 for zero). The values cover zero, small values, a value needing the high byte of a 16-bit `int`, and all bits set. It is a standalone file picked up by the existing `UnitTests` glob, so no CMake change is needed. It ships a one-line `longjmp-zero.reference_output` (`exit 0`) like every other test in that directory. The file is needed: the harness records the exit status in the captured output and compares it with this file, and without the file a nonzero exit is not reported as a failure.

This regression fails with the current SDK and passes with #450. This PR is available for review alongside the SDK fix; I propose landing it once test-suite CI uses an SDK containing that fix. Merging #450 alone does not establish that CI has picked up the repaired SDK.

Evidence, using this test through `llvm-lit` with `-C cmake/caches/<level>.cmake -C cmake/caches/target-mos.cmake -DTEST_SUITE_SUBDIRS=SingleSource`, `mos-sim` as the runner, and an SDK built at [`3f6968bbc156`](https://github.com/llvm-mos/llvm-mos-sdk/commit/3f6968bbc156ff9a63102a8e158db868819bd61c) without and with #450:

| Level | Without #450 | With #450 |
|---|---|---|
| `-O0` | FAIL (`longjmp(env, 0): setjmp returned 0, expected 1`) | PASS |
| `-O2` | FAIL (same message) | PASS |
| `-O3` | FAIL (same message) | PASS |
| `-Os` | FAIL (same message) | PASS |
| `-Oz` | FAIL (same message) | PASS |

Run by hand outside the harness, the other four values (1, 7, 256, -1) pass without #450 at `-O0`, `-O2` and `-Os`, so only the zero case fails.

Related, not changed here: `SingleSource/UnitTests/SetjmpLongjmp/C/WhileLoop.c` already exercises this case, because its last iteration calls `longjmp(buf, 0)`. That directory is disabled for every target by the FIXME in `SingleSource/UnitTests/CMakeLists.txt` (EH edges), so it never runs. Built by hand against the same SDK and run under `mos-sim` with a 10 s timeout, `WhileLoop.c` does not terminate without #450 at `-O0`, `-O2` and `-Os`, and exits 0 after 74 lines of output with it. I left the directory alone; I mention it in case you want to re-enable it for MOS at some point.

AI attribution: Claude Code 2.1.295, model Claude Sonnet 5.5 (`claude-sonnet-5-5`), reasoning effort high.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Publication and merge-sequencing edits: OpenAI Codex 0.162.1, model `gpt-6.1-sol`, medium reasoning effort; session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`.
