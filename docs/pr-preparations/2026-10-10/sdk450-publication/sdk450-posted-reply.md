Thanks. You were right that a test exists: `SingleSource/UnitTests/SetjmpLongjmp/C/WhileLoop.c` already ends in `longjmp(buf, 0)`, but that whole directory is disabled by a FIXME in `UnitTests/CMakeLists.txt`, so it never runs, and none of the other tests there check the value `setjmp` returns.

I've removed the SDK test and kept only the `setjmp.S` change (one commit, one file), and opened a standalone `SingleSource/UnitTests/longjmp-zero.c` in llvm-test-suite: https://github.com/llvm-mos/llvm-test-suite/pull/20. I did not re-enable `SetjmpLongjmp` since its FIXME is about EH edges in general.

This regression fails with the current SDK and passes with #450. I propose landing the test-suite PR once its CI uses an SDK containing this fix.

Publication and merge-sequencing edits: OpenAI Codex 0.162.1, model `gpt-6.1-sol`, medium reasoning effort; session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`.
