`longjmp(env, 0)` currently makes `setjmp` return zero on the common 6502 runtime. C requires this case to return one, so programs can distinguish the initial setjmp return from a non-local return.

Normalize an all-zero return value to one in the `longjmp` epilogue, retaining every nonzero 16-bit value. This changes neither the buffer layout nor stack restoration and is independent of native-65816/SNES support.

The regression test lives in llvm-test-suite, as requested in review: TEST_SUITE_PR_URL (`SingleSource/UnitTests/longjmp-zero.c`). It jumps with 0, 1, 7, 256 and -1 and exits nonzero if `setjmp` returns anything other than the value, or 1 for zero.

Validated against SDK [`3f6968bbc156`](https://github.com/llvm-mos/llvm-mos-sdk/commit/3f6968bbc156ff9a63102a8e158db868819bd61c) with the locally installed MOS compiler, running that test through `llvm-lit` and `mos-sim` at `-O0`, `-O2`, `-O3`, `-Os` and `-Oz`. Without this change the test fails at every level (`longjmp(env, 0): setjmp returned 0, expected 1`; the other four values pass). With it the test passes at every level.

Reference: [POSIX.1-2024 / IEEE Std 1003.1-2024, `longjmp`, RETURN VALUE](https://pubs.opengroup.org/onlinepubs/9799919799/functions/longjmp.html). This published standard explicitly aligns the function with ISO C and requires `setjmp()` to return 1 when `val` is 0.

AI attribution: Claude Code 2.1.295, model Claude Sonnet 5.5 (`claude-sonnet-5-5`), reasoning effort high.
