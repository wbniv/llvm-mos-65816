Thanks. You were right that coverage already exists: `SingleSource/UnitTests/SetjmpLongjmp/C/WhileLoop.c` reaches `longjmp(buf, 0)`. The directory's disabling notice was inherited from a 2006 llvm-gcc4 limitation and copied into CMake in 2016.

I've kept #450 as the one-file `setjmp.S` fix and opened the standalone return-value regression in [llvm-test-suite #20](https://github.com/llvm-mos/llvm-test-suite/pull/20).

I've also repaired and re-enabled the disabled tests locally in a follow-up for #20. The five C tests now have output and exit-status checks, valid `setjmp` expression contexts, and the missing stdio include. The C++ test no longer jumps across a non-trivial destructor, and is enabled only when a compilation/link probe confirms exception support. Our standalone regression now uses a valid `setjmp` context too.

With #450's assembly and the clean compiler downloaded by test-suite CI, all six C checks pass at O0, O3, Os and Oz (24 checks). All seven C/C++ checks also pass with host GCC at those levels (28 checks). With the unfixed SDK, WhileLoop and the standalone zero-return regression fail; the other four C tests pass. Each output oracle also rejects an intentionally incorrect exit status.

The suite-restoration follow-up is ready to append to existing #20. I propose landing the tests once test-suite CI uses an SDK containing #450's fix.

Suite restoration, October 10 validation and reply: OpenAI Codex 0.162.1, model `gpt-6.1-sol`, medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`. Original standalone regression and October 9 validation: Claude Code 2.1.295, Claude Sonnet 5.5 (`claude-sonnet-5-5`), high reasoning effort.
