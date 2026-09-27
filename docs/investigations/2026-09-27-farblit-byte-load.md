# Farblit byte-load legalization: cause and repair

**Status (2026-09-27): fixed locally by [0066](../../patches/llvm-mos/0066-mos-far-extload-worklist.patch).** The unchanged historical input fails on its preserved compiler and passes with the repair. [Canonical defect](../defects/mos-farblit-byte-load-legalization.json).

**Attribution:** OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`.

## Cause and prior work

This continues the September 26 defect record. Its original source, preprocessed input, IR/MIR, failing compiler and baseline record remain unchanged. Reconciliation covered the original increment-2 report, carry-scheduling follow-up, TODO, structured records, Git history, patches 0001/0061/0062 and the live source; [retained audit](../defects/evidence/2026-09-27-farblit-byte-load/prior-work.json).

The interaction is between 0061's eager address selection and 0001's in-place absolute-far rewrite:

1. `legalizeLoad` splits `G_ZEXTLOAD` or `G_SEXTLOAD` into a byte load and an extension. Its `changedInstr` notification queues the resulting `G_LOAD` for legalization.
2. 0061 immediately calls `selectAddressingMode`, preserving the address expression needed to select `long,X`.
3. `tryFarAbsoluteAddressing` changes the queued instruction into target pseudo `G_LOAD_FAR_ABS`. The worklist observer inserts generic instructions, but changing an instruction does not remove a previously queued entry.
4. The legalizer visits that target pseudo as though it were generic and fails. This is not a missing s8 legality rule. The native-word or carry-scheduling changes are not needed to explain the mechanism.

Removing only 0061's eager-selection block makes the original farblit input and the reduced signed/unsigned extending loads compile. A plain byte-return control already compiles on the preserved baseline. The repaired helper builds a new target instruction, clones its memory references and erases the generic instruction; erasure removes pending legalization work. Eager address selection remains enabled.

## Validation

| Check | Result |
| --- | --- |
| Original September 26 `source.i`, preserved baseline | Same `s8 G_LOAD_FAR_ABS 8355871` failure; compiler SHA-256 `18086f4e…3206` matches the original record |
| Same input with 0066 | Pass at `-Os` and `-O2`, A16 and A16+XY16 |
| Direct MIR with extending constant/global byte loads | Baseline fails; candidate passes with verifier and FileCheck in byte, A16 and A16+XY16 modes |
| MOS code-generation suite | 128 pass, two unsupported |
| MOS assembler suite | 52 pass |
| Farblit host oracle | `0x1E56EE65`; MAME and bsnes-jg agree in A16 and A16+XY16 |
| Farblit pressure host oracle | `0xD695`; MAME and bsnes-jg agree in A16 and A16+XY16 |
| Patch reconstruction | 0002 plus standalone patches reproduces live MOS source and focused tests; 0002 content is unchanged |

[Commands and retained logs](../defects/evidence/2026-09-27-farblit-byte-load/runs.json), [toolchain/source identities](../defects/evidence/2026-09-27-farblit-byte-load/identity.json), and [runtime transcript](../defects/evidence/2026-09-27-farblit-byte-load/runtime.log) identify the exact builds. Candidate Clang, llc and the LTO linker are preserved under `.scratch/farblit-t4/candidate-install`; the ablation binaries are separate. The source archive and original-source overlay document the reconstruction. No upstream submission or independent review is claimed.

## Remaining farblit gate qualification

The unmodified `dev/farblit.sh` still exits 1 because its aggregate opcode-count checks demand at least 3/6 `b7` loads, while the current A16/XY16 objects contain 2/5. All eight emulator assertions pass. This code-shape result is retained, not reported as a passing shell gate. The A16 object produced with 0066 is byte-identical to the control that only removes 0061's eager-selection block; the count mismatch is not introduced by the build-and-erase repair. Reconcile the combined native-word/indexed code shapes before changing those expectations or claiming all increment-2 optimization checks pass.

The first runtime attempt used a rebuilt Clang with an unrepaired LTO linker and reproduced the historical failure during linking. Rebuilding lld from the same repaired backend enabled the runtime results above. An LTO validation must identify both executables.
