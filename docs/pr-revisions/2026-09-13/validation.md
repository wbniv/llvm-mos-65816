# Validation of the proposed revisions

Validated locally on Linux with a Release LLVM build, assertions enabled, and the MOS target. Each branch was built on its existing PR base. No GitHub CI run was triggered, because nothing was pushed. All six proposed branches merge cleanly with upstream `main` at `1d4ea13ca0ac` (checked with `git merge-tree`); the merge results were not separately built.

| PR | Result |
| --- | --- |
| #578 | CodeGen/MOS: **79 pass**, 1 upstream-disabled test. New regression fails without the fix and passes with it. Reconstructed SNES demo changes from CRC mismatch to host/bsnes agreement. |
| #584 | CodeGen/MOS: **79 pass**, 1 upstream-disabled test, including SPC700 non-GPR LDImm and GPR-folding coverage. |
| #586 | MC/MOS: **40 pass**, including the new BRK disassembly and round-trip checks. |
| #588 | MC/MOS: **40 pass**, including revised COP and assembler-error checks. |
| #589 | CodeGen/MOS: **80 passing tests in the final revision**, 1 upstream-disabled test. The full run passed 79 and exposed one incorrect expected register transfer in the new test; after correcting that expectation, both new tests passed on focused rerun. |
| #590 | CodeGen/MOS: **79 pass**, 1 upstream-disabled test. **20/20 separate compiler runs** produce identical, nonempty assembly. [Hash evidence](590-determinism.txt). |

The disabled test is `getchar-regression.ll`, disabled by its upstream `UNSUPPORTED` directive. Missing-tool discovery notices from lit did not prevent any selected test from executing; every required tool for the selected suites was built.

## #578: diagnosis and independent runtime check

The reconstructed input is the historical loop-fold C reproducer at `docs/plans/spikes/2026-06-25-loopfold-min.c`, with `zoom.h` and the pyramid generator recovered from commit `730e809^`. The matrix CRC fold was restored to its loop form. The current local clang produced LLVM IR; the branch-built llc compiled that same IR before and after the fix, and the local SNES SDK linked each resulting object.

[Pass evidence](578-pass-evidence.txt) shows that virtual-register rewriting emits `A = COPY Y` at the loop header. MOSCopyOpt forwards it away, but its single post-order liveness update leaves A absent from the latch live-ins. Later lowering consequently uses A as scratch for the sign test. The replacement uses LLVM's existing fixed-point liveness helper before dead-copy cleanup. The original coalescing guard is completely removed.

The 51-line MIR test in [the complete diff](578-complete.patch) checks the latch's live-in A and the absence of the bad A reload through copy optimization, pseudo expansion, and late optimization. Both assertions fail on the compiler without the fix and pass on the revised branch.

The emulator runs used the same scripted input: `R:30,A:10,SELECT:4,R:50,NONE:120`, 200 emulated frames, and host replay of the 64 captured input samples (all 64 nonzero; 3 level swaps).

- [Before](578-runtime-red.txt): host `0x7F81`, ROM `0xC57C` — mismatch.
- [After](578-runtime-green.txt): host and ROM both `0x7F81` — pass.

These are this reconstruction's measured values; they are not the older June report's CRC values. The reduced MIR regression needs no emulator or SNES SDK.

## Local commits

| PR | Submitted head | Proposed head |
| --- | --- | --- |
| #578 | `edc9bbd23b71` | `c4fd3dfa74e7` |
| #584 | `3ce98fed82de` | `2d60650cfce2` |
| #586 | `064d33fc43ca` | `a2f81a87b01c` |
| #588 | `3ac109760642` | `fb1b4ba325a8` |
| #589 | `8c8d28b0c35a` | `9aead7afaa4a` |
| #590 | `cc9f0d027813` | `5e83a0784918` |

The submitted remote branches were read but never updated. `heads.json` records their full hashes for checking before any later approved push. Local compiler worktrees are under `/tmp/llvm-mos-review*`; the mail-formatted `*-commits.patch` files preserve the follow-up commits in this review directory.
