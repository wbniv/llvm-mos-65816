The common SDK's `longjmp(env, 0)` currently makes `setjmp` return zero. [SDK #450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450) normalizes that return to one. This PR checks zero, 1, 7, 256 and -1 and restores the existing SetjmpLongjmp C tests, with explicit output and exit-status references.

The directory's disabling notice was inherited from a 2006 llvm-gcc4 limitation and copied into CMake in 2016. The five C tests pass with the current CI compiler and #450's runtime fix. The fixtures now use the expression contexts required for setjmp by C, and SimpleCTest includes stdio.

C++Catch destroys its helper object before longjmp, avoiding a jump across a non-trivial destructor. A CMake compilation/link probe enables that test only when C++ exceptions are supported. The C tests run independently, including on MOS.

Validation: llvm-lit passes all six C checks at O0, O3, Os and Oz with the clean CI prerelease compiler plus #450's assembly (24 checks), and all seven C/C++ checks with host GCC 15.2 at those levels (28 checks). With the unfixed CI SDK, WhileLoop and longjmp-zero fail; the other four C tests pass. Every reference also rejects an intentionally incorrect exit status. These are focused checks; no full-suite or Mac run is claimed.

Please review alongside #450, then land this PR once test-suite CI uses an SDK containing that fix. The fixed-runtime validation supplied #450's assembled object ahead of the unchanged SDK archive; it did not require a compiler change.

Original standalone regression and October 9 validation: Claude Code 2.1.295, Claude Sonnet 5.5 (`claude-sonnet-5-5`), high reasoning effort. Suite restoration, fixture corrections and October 10 validation: OpenAI Codex 0.162.1, model `gpt-6.1-sol`, medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`.
