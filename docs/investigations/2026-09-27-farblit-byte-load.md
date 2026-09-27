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

## Farblit gate qualification: September 27 evidence

The unmodified `dev/farblit.sh` still exits 1 because its aggregate opcode-count checks demand at least 3/6 `b7` loads, while the current A16/XY16 objects contain 2/5. All eight emulator assertions pass. This code-shape result is retained, not reported as a passing shell gate. The A16 object produced with 0066 is byte-identical to the control that only removes 0061's eager-selection block; the count mismatch is not introduced by the build-and-erase repair. Reconcile the combined native-word/indexed code shapes before changing those expectations or claiming all increment-2 optimization checks pass.

The first runtime attempt used a rebuilt Clang with an unrepaired LTO linker and reproduced the historical failure during linking. Rebuilding lld from the same repaired backend enabled the runtime results above. An LTO validation must identify both executables.

## Instruction-shape reconciliation (2026-09-28)

**The opcode deficit is explained; the gate remains failing and its expectations are unchanged.** Native-word lowering in 0062 replaces `rdw`'s byte pair with one accumulator-wide `lda [dp]`. A16 loses one `b7`; XY16 loses two. This is distinct from the repaired legalization crash in the [canonical record](../defects/mos-farblit-byte-load-legalization.json). Neither a new compiler defect nor a performance improvement is established by these counts.

Attribution: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; verified session `01a0e529-62c6-7fc2-a0c6-357800272c63`.

### Exact build and per-probe mapping

Replayed the preserved 0066 candidate, with Clang `ff61df1d…f8d5`, llc `21c7bfe4…a70d`, and lld `5142afb3…95e2`. Both freshly generated non-LTO disassemblies match the September 27 captures, including relocations. Adding line tables leaves the disassembled instructions and relocations unchanged, allowing the fully inlined probes to be mapped without adding `noinline` or changing the input. [Identity and control scope](../defects/evidence/2026-09-28-farblit-shapes/identity.json), [commands](../defects/evidence/2026-09-28-farblit-shapes/commands.json), and [per-access source/assembly lines and widths](../defects/evidence/2026-09-28-farblit-shapes/analysis.json) retain the evidence. Compressed assembly and MIR before/after legalization are in the same evidence directory.

| Probe | A16 | A16 + XY16 |
| --- | --- | --- |
| `rd8` | byte `b7`, Y8 | byte `b7`, Y8 |
| `rdg` | byte `bf`, X8 | byte `bf`, X8 |
| `rd16` | byte `a7`, computed pointer | byte `b7`, Y16 |
| `rdw` | **word `a7`, M=0**, computed pointer | **word `a7`, M=0**, computed pointer |
| `rdw16` | byte `a7`, computed pointer | byte `b7`, Y16, wrapped 16-bit sum |
| `rdw16g` | byte `a7`, computed pointer | byte `bf`, X16, wrapped 16-bit sum |
| `rdw8` | byte `b7`, Y8, wrapped byte sum | byte `b7`, Y8, wrapped byte sum |
| `wr8` | byte `97`, Y8 | byte `97`, Y8 |
| `wr16` | byte `87`, computed pointer | byte `97`, Y16 |
| `cp8` load | byte `a7`, computed pointer | byte `b7`, Y16 for `j + 8` |
| `cp8` store | byte `97`, Y8 for `j` | byte `97`, Y8 for `j` |

The table describes the ten probe bodies; the constant-address readback loads remain separate. `b7`/`a7` alone do not specify access width: `rdw` has `rep #$20` before its `a7`. The only XY16 `a7` belongs to this runtime word load, not either absolute-base probe. 0061 selects `long,X` (`bf`) for `rdg` in both modes and `rdw16g` in XY16.

### Controlled byte-split experiment

The retained control replaces only `rdw`'s pre-legalizer `G_ZEXTLOAD` of an s16 memory value with two s8 loads at offsets 0 and 1, a merge, and the same zero extension. It resumes the same compiler at legalization with the machine verifier. This is a reconstructed instruction-shape experiment, not a recovered historical compiler or a runtime/timing comparison.

| Mode and lowering | `b7` | `97` | `a7` | `87` | `bf` |
| --- | ---: | ---: | ---: | ---: | ---: |
| A16, native word | 2 | 2 | 5 | 1 | 1 |
| A16, byte-split control | 3 | 2 | 5 | 1 | 1 |
| XY16, native word | 5 | 3 | 1 | 0 | 2 |
| XY16, byte-split control | 7 | 3 | 0 | 0 | 2 |

In A16, the byte-pair control materializes the scaled pointer for the low byte and reads the high byte with constant Y=1. Its third `b7` therefore does **not** prove the `cp8` runtime load folded. In XY16, both byte offsets fit Y16, giving two indexed byte loads; native-word lowering instead uses one unindexed word load. `legalizeLoadStore16` selects that native form, while `tryFarRuntimeIndexFold` accepts only s8 accesses. This accounts exactly for the observed 3-to-2 and 7-to-5 differences. The original gate only required six of the seven historical XY16 loads, so its failure understates the two-load change.

`cp8` has a separate range limitation. Its input MIR is `ptradd(ptradd(base, zext j), 8)`. The fold's known-bits bound for the byte PHI is 255; adding the peeled displacement gives 263, beyond Y8. The actual loop visits only 0..47, but the local proof does not use that loop bound. Y16 can hold 263, so XY16 folds the load with `j + 8`; its store uses a separately loaded Y8 containing `j`. The source comment promising one shared Y and the A16 PASS message naming `cp8` are not valid descriptions of this generated code. A replacement gate must check these probes individually instead of using an unrelated high-byte load to satisfy their count.

### Disposition and validation

The fresh unmodified [shell-gate run](../defects/evidence/2026-09-28-farblit-shapes/runtime.log) exits 1 only on the same two count checks. All eight MAME/bsnes-jg assertions pass: `0x1E56EE65` for farblit and `0xD695` for pressure, in both feature modes. All four ROM hashes match the September 27 identities; map hashes are recorded separately (the two farblit map files differ). This confirms the runtime result on the identified build; it does not validate the reconstructed byte-split control or the current installed compiler.

Before replacing the aggregate expectations, decide which optimization contract the gate should enforce: byte runtime folds, native-word access width, global `long,X`, and the remaining computed-pointer cases each need explicit coverage. If runtime-indexed native-word loads or an A16 `cp8` fold are required, they need separate implementation and profitability evidence. Lowering the minima to 2/5 and retaining “every runtime-base access folded” would incorrectly certify those missing shapes. No compiler, fixture, or gate expectation was changed in this reconciliation.
