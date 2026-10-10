# Restore the setjmp/longjmp test battery

**Published October 10, 2026:** the follow-up is appended to existing [llvm-test-suite #20](https://github.com/llvm-mos/llvm-test-suite/pull/20) at `28bfe7e74d8eceec0a4ef963ce6d63c2ccb0620e`. Its title and description are updated, and the existing [SDK #450 reply](https://github.com/llvm-mos/llvm-mos-sdk/pull/450#issuecomment-6091769549) now states that the disabled tests have been repaired and restored. [Verified publication receipt](publication.json) · [posted #20 description](test-suite20-posted-body.md) · [posted SDK reply](sdk450-posted-reply.md). #450 remains the runtime prerequisite; land the tests once test-suite CI uses its fixed SDK.

The following preparation and validation evidence was captured before publication. [The patch](test-suite-followup.patch) applies after the original published head `4ac8bccdeb434481754b96251aabca055f7de1a5`; the [initial publication receipt](../sdk450-publication/publication.json) and the draft texts remain dated evidence.

Implementation, investigation and validation: OpenAI Codex 0.162.1, model `gpt-6.1-sol`, medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`. Original #20 implementation and October 9 validation retain their Claude Code 2.1.295, Claude Sonnet 5.5 (`claude-sonnet-5-5`), high reasoning effort credit in [the original packet](../../2026-10-09/validation.md).

## What the disabling notice actually means

The notice is inherited from LLVM, rather than a recent llvm-mos maintainer decision. [Chris Lattner's August 2006 change](https://github.com/llvm/llvm-test-suite/commit/881fcffbff9593940659b5391b442ff26c5bb1f1) disabled these tests for llvm-gcc4 because exception handling support was incomplete. [The January 2016 CMake change](https://github.com/llvm/llvm-test-suite/commit/3f6e30dc678dcc7d83c6b15f5960c28963f51613) copied the disable to match Make; its author reported that the accidentally enabled tests had worked on x86.

The original failing llvm-gcc4 executable, inputs at that revision and optimizer diagnostics were not recovered. These contemporary passing runs do not establish the change that repaired that historical compiler behavior. No historical compiler defect is marked fixed, and no new compiler repair is claimed.

## Prior-work reconciliation

Searches covered `docs/defects/*.json`, original setjmp/longjmp investigations and follow-up plans, TODO/upstream summaries, repository Git history, standalone patches and aggregates 0001/0002, and the MOS target sources at the current compiler pin `f24948c7d1a4`. Relevant existing work is the common 6502 zero-return repair in #450 and the separate native-SNES page-1 stack reconstruction/CSR repairs. The latter remain platform work; none was used in these simulator runs. No structured record or MOS patch was found for the historical llvm-gcc4 EH-edge disable. This is restoration and repair of test fixtures, rather than a new compiler-defect discovery.

The exact destination is llvm-test-suite #20 at `4ac8bccdeb43`, based on `9f5e9987ba6d`. Its top-level UnitTests CMake file excludes SetjmpLongjmp; that directory otherwise includes C and C++, with five C files and one C++ file. None has a reference-output file. CMake's traditional test builder emits VERIFY only when such a file exists. The C++ Makefile already declares an EH-support requirement; the CMake route has no equivalent probe.

The current SDK CI workflow downloads the `prerelease` SDK. Its October 6 Linux asset has SHA-256 `b3b00856df56f5a3c4a91a4c2398b977273919e13ef9a04228aefe05eceaf0f2`. Its clean upstream Clang is LLVM 24 at `0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63`, rather than the downstream compiler used in October 9's validation. [Compiler identity](evidence/release-identity.json). The retained [IR](evidence/SimpleCTest.ll) contains `returns_twice` on both the setjmp declaration and call, and `noreturn` on longjmp.

## Changes

- Enable the SetjmpLongjmp CMake directory, retaining all five C tests.
- Add explicit stdout and `exit 0` references to all six restored fixtures. Output checking is necessary because the traditional harness can otherwise accept a nonzero exit.
- Include stdio in SimpleCTest. Use `switch (setjmp(...))` in SimpleCTest and MultipleSetjmp, and a direct `if (setjmp(...))` in WhileLoop. C permits setjmp only in specified expression contexts; assignment to a variable is outside that contract ([C11 draft, section 7.13.1.1](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf)). SimpleCTest and MultipleSetjmp retain explicit expected-return-value checks. WhileLoop checks loop/re-entry output; its numeric labels use the unchanged argument, while the standalone test checks returned values directly.
- Repair C++Catch by ending the helper object's lifetime before longjmp. Jumping across its non-trivial destructor has undefined behavior ([C++ draft](https://eel.is/c++draft/csetjmp.syn)). The test still checks that longjmp does not enter the C++ catch handler and that both objects are destroyed normally.
- Probe C++ exception compilation/linking before adding C++Catch. The C tests run independently. The actual MOS toolchain fails this capability probe; host GCC succeeds. This does not implement MOS C++ exception handling.
- Correct the same disallowed setjmp assignment in our posted longjmp-zero test. Its switch still checks zero, 1, 7, 256 and -1, and a volatile flag distinguishes the initial return from an erroneous zero return after longjmp.

## Validation

| Configuration | Result |
|---|---|
| Five original C files, downstream LLVM 23 + fixed SDK, O0/O1/O2/O3/Os/Oz | 30 direct simulator runs match host output; exploratory evidence only |
| Five original C files, clean CI prerelease LLVM 24, Os | Four pass; WhileLoop times out with the unfixed SDK; all five pass with #450's assembly |
| Restored C tests + revised longjmp-zero, clean CI compiler + #450 assembly, llvm-lit, O0/O3/Os/Oz | 24/24 pass; C++Catch correctly excluded by capability probe |
| Restored C and C++ tests + revised longjmp-zero, host GCC 15.2, llvm-lit, O0/O3/Os/Oz | 28/28 pass |
| Same six C tests, clean CI compiler + unfixed SDK, llvm-lit, O3 | Four pass; WhileLoop and longjmp-zero fail |
| Each of the seven host references independently changed to expect exit 1 | 7/7 rejected by llvm-lit; references restored afterwards |

These are focused checks, not a full test-suite run. No Mac runtime run is claimed. The original C fixtures' nonconforming setjmp expressions make their exploratory results insufficient to establish compiler correctness; the final suite uses permitted expressions.

For the fixed-runtime tests, the published #450 assembly was assembled by the clean CI compiler and supplied as a strong object at link time, ahead of the SDK archive. The SDK archive itself was unchanged. The retained [source](evidence/setjmp-fixed.S) reproduces [the linked object](evidence/setjmp-fixed.o) byte-for-byte: SHA-256 `1524d6500b2225135ef12f08d00754f5e0d4fc1126953600015215ae81ba7e1a`. The same compiler/archive without that object produces the two expected failures. This isolates the runtime change without a compiler rebuild.

[Evidence hashes](evidence-sha256.json) cover command records, compiler identity, configure/build/lit logs, original sources and host output, incorrect-reference runs, and the failing zero-return diagnostic. The WhileLoop stdout artifact is a labelled excerpt with the full capture's hash/location. [Source hashes](source-hashes.json) identify the exact original PR files downloaded from its immutable commit and the tested candidate files. The patch was applied to those original files and all 13 resulting files were byte-compared with the tested candidate. Added comments pass the repository history checker; patch whitespace was checked.

The tested checkout and builds are in `.scratch/sjlj-restoration/`. The original external clone's shared object store disappeared during validation; Git fetch attempts did not restore it. Patch verification therefore uses the seven changed original files downloaded directly at #20's immutable commit, plus six new references, rather than claiming a working Git checkout. The test sources, compiler and captured runs used for the final results are retained locally.

## Next step

Follow review and CI on existing #20 and #450. The follow-up, replacement description and revised existing reply are published, as recorded in [publication.json](publication.json). The retained [body draft](test-suite-body.md) and [reply draft](sdk450-reply.md) show the approved preparation; exact posted copies above record the final publication wording. Keep #450 as the one-file runtime fix; land the tests only once test-suite CI uses an SDK containing #450.
