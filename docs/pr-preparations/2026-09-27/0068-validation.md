# 0068 standalone upstream validation

**Status:** standalone extraction validated on llvm-mos/llvm-mos `26d7c2c1eebf98ca194b92609ba4e7540bfc6ef6`. Independent review and upstream publication remain pending.

The [exact patch](0068-llvm-mos.patch) contains one MOS MC implementation change and two regression tests. It needs no carry-scheduling, #320, #321, or SNES platform changes. The compiler [canonical record](../../defects/mos-null-output-streamer-crash.json) retains the original baseline; this is an additional validation of that repair.

## Destination reconciliation

GitHub main and a shallow fetch resolved to the revision above. The [audit](../../defects/evidence/2026-09-27-null-output-upstream/prior-work.json) retains the inspected entry points, registration contract, history and issue search. `CodeGenTargetMachineImpl` still constructs a generic null streamer and runs the MOS asm printer; `emitStartOfAsmFile` unconditionally uses its target streamer. `.zeropage` parsing reaches the same missing factory. No prior destination guard or null-output regression covers either path.

`MOSTargetStreamer::finish` on this revision dispatches through virtual section queries and symbol-reference methods. The null subclass overrides these operations and finalization with no-ops. The generic finalizer itself does not contain an unconditional ELF-streamer cast; this refines the earlier report's finalization explanation without changing the established null-pointer cause.

## Matching-input results

| Check | Unpatched upstream | Standalone candidate |
|---|---|---|
| Retained original `arith.Os.ll`, minimal function and section/constructor fixture; three CPUs; plain and diagnostic null output | 18 SIGSEGV failures | 18 successes; empty output |
| `.zeropage` parser; three CPUs; null output | 3 SIGSEGV failures | 3 successes; empty output |
| Ordinary object and assembly emission for all inputs | 24 successes | 24 successes; every output byte-identical to baseline |
| MOS CodeGen and MC suites | 131 passed, 1 unsupported | 133 passed, 1 unsupported |

CPUs are `mos6502`, `mos65c02`, and stock `mosw65816`. LLVM machine verification is enabled for the IR commands. Baseline logs retain `MOSAsmPrinter::emitStartOfAsmFile` and the `.zeropage` parser failure signatures. The candidate adds CodeGen and MC null-output regressions. Existing `getchar-regression.ll` is unsupported on both builds.

This output-streamer repair changes no executable program bytes in the 24 comparisons. No emulator execution is claimed for this extraction.

## Reproduction and identities

[Identity and hashes](../../defects/evidence/2026-09-27-null-output-upstream/identity.json), [baseline matrix](../../defects/evidence/2026-09-27-null-output-upstream/baseline/receipt.json), [candidate matrix](../../defects/evidence/2026-09-27-null-output-upstream/candidate/receipt.json), [baseline suite](../../defects/evidence/2026-09-27-null-output-upstream/baseline-suite.log), and [candidate suite](../../defects/evidence/2026-09-27-null-output-upstream/candidate-suite.log) retain the results. [The runner](0068-validate.py) refuses to overwrite an existing arm directory.

Release builds have assertions enabled, with MOS, X86, ARM and AArch64 enabled. Only the MOS suites are claimed here. An isolated copy of the existing build cache was reconfigured and rebuilt against the exact unpatched destination; unchanged source timestamps were retained only after byte comparison. The baseline tools were frozen before the patch was applied. The candidate rebuild changes only the MOS target-streamer compilation unit and relinks the two tools. Preserved executables are in `build/null-output-upstream/{baseline,candidate}/bin/`; the working downstream source and installed compiler are untouched.

The container image is `sha256:12d4d50d447cac8d6e3f9c6efe3cca676c60e8f8890638007c0cf2b73ad96482`. Source and build were mounted at `/work/build/register-exhaustion-src` and `/work/build/0029-cross-target-build`; their host locations and CMake configuration are recorded in the evidence. Apply the retained patch to the recorded upstream revision, rebuild `llc` and `llvm-mc`, then run the matrix with `--arm candidate --tools <preserved-bin-directory>` in a fresh evidence copy.

The historical 0064 carry-scheduling extraction remains a dated artifact; this validation uses current upstream plus only 0068. Author review covers the factory, its callers and no-op virtual methods. Independent review remains a separate gate.

Validation and author review: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; verified session `01a0e315-89ed-7e70-b7dc-fcc2940366d9`.
