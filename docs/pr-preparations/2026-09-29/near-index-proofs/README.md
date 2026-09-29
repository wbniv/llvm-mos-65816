# Near-index proof recovery: upstream review packet

Prepared September 29, 2026. This packet extracts the completed downstream near-index proof recovery onto `llvm-mos/llvm-mos` main `06bc967d2668c7c11c4d6eb43a6aed1f99ad258b`. The [September 27 investigation](../../../investigations/2026-09-27-near-index-overflow-proofs.md), the [canonical optimization record](../../../defects/mos-near-index-overflow-proofs.json) and its preserved baseline remain the authoritative local evidence. The [plan](../../../plans/2026-09-29-near-proof-upstream-packet.md) records the contract.

## Scope and publication

The series has two patches. Apply both to the destination before reviewing or building patch 2.

1. `[MOS] Extract opt-in native widths and near-memory prerequisites`: the #321 compiler subset prepared for the [0065 packet](../../2026-09-28/0065/README.md). It is rebased without edits, and its added and removed lines are identical to that reviewed patch. It already contains the bank-wrap guard `canFoldNearIndex` and its three near-index callers.
2. `[MOS] Recover near-index no-wrap proofs after loop strength reduction`: the pass, its registration and `near-index-proofs.ll`.

The pass does not depend on 0063 or 0065, so neither is included. The PR is unposted. Merging requires accepted #321 native-width support. The [native-width posting hold](../../../321-upstream-native-width-pr.md) remains in force; this packet does not authorize publication.

## Destination and prior work

The [destination reconciliation](evidence/destination-reconciliation.json) records the searches and source checks. Upstream main moved three commits past the 0065 packet's `26d7c2c1eebf` on September 29. #605 adds an experimental SSA register allocator, off by default, and edits `MOSTargetMachine.cpp`, `MOS.h` and the MOS `CMakeLists.txt`. Those are the files this pass registers in. Patch 1 rebases cleanly; the [range-diff](evidence/prerequisite-range-diff.txt) shows only context changes. The experimental allocator was not exercised with native widths or this pass.

The stock destination has no no-wrap checks on its near-index folds. The proof requirement, and therefore the lost-proof cost, arrives with patch 1's bank-wrap guard. The pass needs patch 1 to have any effect. `MOSIndexIV` runs in the middle-end loop pipeline, before codegen LSR, so it cannot restore flags that LSR drops. IRTranslator transfers GEP `nuw` to `G_PTR_ADD`. The destination's ScalarEvolution has use-specific no-wrap flags, but nothing sets them and `getSCEV` returns the bare node, so the pass reads only node-level flags.

## Changes relative to downstream `0002`

The recovery logic matches `0002`. The extraction differs in these ways:

- The pass argument is `mos-near-nowrap-recovery`. In `0002` it equals the `-mos-recover-near-nowrap` switch, and `opt` aborts at startup because it registers every legacy pass name as an option. The [option-collision record](../../../defects/mos-near-nowrap-option-clash.json) preserves the failing downstream `opt`. `0002` now carries the same rename and ID insertion, and the record is closed with matching-input red/green. The test adds an `opt` startup RUN line.
- The pass is inserted after LSR by ID, and its header exports `MOSRecoverNearNoWrapID`. The earlier instance-based insertion leaked the pass whenever LSR was absent.
- The index width comes from the data layout rather than a literal 16.
- An `LLVM_DEBUG` line names the proof that fired: the recurrence or the ordering.
- A file description comment and a pass header follow MOS conventions.

The retained downstream regression loads through `ptr addrspace(2)`, which is #320 and not part of patch 1. The upstream test uses near-only loops. They cover a copy loop and a fixed buffer, which regain `(zp),y` and `abs,x`. The controls are an unflagged loop, a pointer-increment recurrence, a constant base that wraps and one that does not, the stock 6502 exclusion, the disabled switch, and `opt` startup.

## Validation results

| Check | Result |
| --- | --- |
| Ordered patch application | Clean on the destination; [round-trip tree](evidence/series.json) `ec89cf0e` matches the final source. Patch 1 keeps the known end-of-file blank line in `MOSFeatures.td`. |
| Patch 1 only | MOS CodeGen+MC: 143 passed, 1 unsupported; the two new tests fail ([log](evidence/baseline-suite.log)) |
| Patches 1 and 2 | 145 passed, 1 unsupported ([log](evidence/candidate-suite.log)) |
| Regression replay | Patch 1 alone fails the indexed-form checks in default and XY16. The candidate passes all six checks ([log](evidence/regression.log)). |
| Proof paths | Three test GEPs recover through the recurrence and one through the ordering proof ([debug log](evidence/proof-paths.log)); `near-index-proofs-debug.ll` checks both paths in assertion builds |
| `opt` startup | The first extraction aborts with exit 134; the final extraction exits 0 ([record](../../../defects/mos-near-nowrap-option-clash.json)) |
| Frozen-IR replay | 1,045 paired configurations: 499 smaller, 39 larger, net −69,616 B ([summary](evidence/replay-summary.json)) |
| Recovery disabled | The candidate with `-mos-recover-near-nowrap=false` reproduces the patch-1 code hash and exit status in every configuration |
| Runtime | 394 of 394 MAME and bsnes-jg checks pass; recovery changes the code of 183 of the 197 compiled builds. Four `csrjmp_sim`/`vlastack_sim` A16/XY16 builds fail to compile on patch 1 alone as well ([results](evidence/runtime-results.json), [summary](evidence/runtime-summary.json)) |

Toolsets are assertion-enabled Release builds of the destination with each patch applied. The candidate binaries were built at `43e1c4d6`; the final commit `980fe1f2` changes only the two test files. Two earlier replays used the pre-review candidate `llc` `b8329fc5`, and every configuration's exit status and code hash matches the final candidate's. [Identity](evidence/identity.json) records the source commits, binary hashes, build configuration and the host directories behind each container mount.

## Profitability

**September 27 downstream census.** This is dated evidence on the downstream compiler, compiling C through clang. Recovery saved 33,159 B across 1,197 pairs. Nine configurations grew: `poolfx_sim.c` default +124 B, `dither_sim.c` A16 +153 B and XY16 +88 B, and six smaller default-mode growths. Runtime checks covered twelve near-fixture configurations, 48 corpus-program checks and the 62-work gallery (`0x5CF0`). They all passed on that compiler ([investigation](../../../investigations/2026-09-27-near-index-overflow-proofs.md)).

**Extracted-backend replay.** [`measure.py`](measure.py) freezes IR for the same 412 inputs with the local frontend (`-Os`, no LTO) in default, A16 and XY16 modes. Every arm then compiles identical IR with machine verification and the destination driver's `-disable-spill-hoist`.

| Mode | Paired | Patch 1 bytes | With recovery | Change | Smaller / larger |
| --- | ---: | ---: | ---: | ---: | ---: |
| Default | 363 | 1,897,560 | 1,886,875 | −10,685 | 164 / 29 |
| A16 | 342 | 1,567,212 | 1,538,141 | −29,071 | 167 / 5 |
| XY16 | 340 | 1,548,207 | 1,518,347 | −29,860 | 168 / 5 |

The 39 larger configurations add 2,453 B in total and are all listed in the [summary](evidence/replay-summary.json). The largest are `a16cmpaudit.c` A16 (+575 B) and `bitboard64.c` default (+543 B). In `a16cmpaudit`, one recovered GEP lets a loop keep its index in 8-bit Y across an A16 body, which adds about 80 `rep`/`sep` pairs and Y spills. In `bitboard64`, 68 recovered GEPs turn shared computed pointers into 153 more `(zp),y` accesses. The recovered flags are correct in both. The legalizer folds each access independently, without a cost model. These totals are not comparable with the September 27 census: the compilers, frontend path and set of compilable inputs all differ.

[`runtime.py`](runtime.py) ran every corpus program whose code the replay shows changing: 65 programs with manifest or host oracles, plus the two near fixtures, in all three modes. Each build uses the extracted candidate and the driver flags. It was checked on MAME and bsnes-jg after 1,000 frames. All 394 core checks match their oracles. The near-Y decoder and a [derived bank-wrap witness](near-index-wrap-near.c) return `0x5CF0` everywhere. Recovery does not change the fixtures' own code, so they validate patch 1's Y-lifetime and bank-wrap contracts on the extracted backend. The derived witness seeds banks $7E/$7F with long stores instead of far pointers. Two changed programs, `hdr_bloom_sim` and `iir_scope_sim`, have no manifest or buildable host oracle and are listed as skipped. These runtime checks exercise the candidate backend; the frontend, linker, startup libraries and SDK bitcode are the local toolchain's.

Replay failures are listed in the [summary](evidence/replay-summary.json) by class. Most fail on both arms: far-pointer IR that patch 1 cannot legalize, known undefined-register copies after virtual-register rewriting, and an existing LSR formula assertion. A replay without `-disable-spill-hoist` also hits the known spill-hoist scratch-register failure. Those failures move between arms because allocation changes ([first-run summary](evidence/replay-summary-llc-only.json)). Five configurations fail only on patch 1, with undefined-register copies after rewriting. One fails only with recovery: `boids.c` XY16, recorded as a [latent defect in patch 1's X preservation](../../../defects/mos-xy16-preserve-x-p-save.json). There, `preserveX` pushes `$p` as defined after a call clobbered its flags, because a scavenger status-register save elsewhere in the loop makes N/Z look live. With recovery disabled, the same source compiles. Given the IR that carries the recovered flags, patch 1 alone and the downstream compiler fail identically. The defect is therefore in `preserveX`, which `0002` also carries; recovery only produces code that reaches it. Only machine verification rejects the output.

## Independent review

The [independent review](independent-review.md) approved the series with changes and found no soundness defect. Its 26 adversarial probe functions add `nuw` only where no wrap can occur in a well-defined execution. The final patch 2 addresses its findings: ID-based insertion removes the leaked pass instance, the index width comes from the data layout, and new tests cover the ordering proof. The re-review confirmed these fixes and gave the same flag decisions on all 12 probe files. It independently reproduced the `preserveX` failure without patch 2's code. Its last wording nit is fixed, and `near-index-proofs-debug.ll` now pins each proof path. Its evidence is in [independent-review.json](evidence/independent-review.json).

## Reproduction

1. Apply `patches/*.patch` with `git am` to a clean checkout of the destination.
2. Build an assertions-enabled LLVM with target MOS and at least `llc`, `opt`, `llvm-mc`, `llvm-objdump`, `llvm-readobj`, `llvm-size`, `FileCheck`, `not`, `count` and `split-file`.
3. Run `llvm-lit llvm/test/CodeGen/MOS llvm/test/MC/MOS`.
4. Freeze the tools after patch 1 as the baseline and after patch 2 as the candidate. Run `regression.sh TOOL_DIRECTORY llvm/test/CodeGen/MOS/near-index-proofs.ll` for each.
5. In the repository development container, run `measure.py` with the local frontend, both tool directories and the September 27 `census-identity.json`. Pass `--llc-flag=-disable-spill-hoist` for driver parity.
6. Run `runtime.py` with the candidate `llc`, the baseline as `--compare-llc`, and the replay's `report.json`.
7. Run everything under `ulimit -c 0`. Configurations that fail by design otherwise leave core dumps behind.

## Attribution

Extraction, destination reconciliation, validation, both new defect records and packet preparation: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`. The downstream implementation and September 27 measurements: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; verified session `01a0e315-89ed-7e70-b7dc-fcc2940366d9`. The independent review names its own attribution.
