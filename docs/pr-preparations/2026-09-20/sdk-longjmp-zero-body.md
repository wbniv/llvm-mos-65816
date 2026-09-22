`longjmp(env, 0)` currently makes `setjmp` return zero on the common 6502 runtime. C requires this case to return one, so programs can distinguish the initial setjmp return from a non-local return.

Normalize an all-zero return value to one in the `longjmp` epilogue, retaining every nonzero 16-bit value. This changes neither the buffer layout nor stack restoration and is independent of native-65816/SNES support.

Add a simulator test target through the SDK's existing ExternalProject/CTest structure. It builds `mos-sim` and tests zero, 1, 7, 256 and -1 at `-O0`, `-O1`, `-O2` and `-Os`, with a timeout for each case. No external emulator/core is required.

Validated using a fresh SDK library and simulator build at [`3f6968bbc156`](https://github.com/llvm-mos/llvm-mos-sdk/commit/3f6968bbc156ff9a63102a8e158db868819bd61c), with the local installed MOS compiler. The integrated `test-sim` target fails all four zero cases without the fix (16 pass) and passes all 20 with it. Test executables were cleaned between library revisions because SDK libraries are selected implicitly by the platform configuration.

Reference: [POSIX.1-2024 / IEEE Std 1003.1-2024, `longjmp`, RETURN VALUE](https://pubs.opengroup.org/onlinepubs/9799919799/functions/longjmp.html). This published standard explicitly aligns the function with ISO C and requires `setjmp()` to return 1 when `val` is 0.
