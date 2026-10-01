# 0065 near-store profitability: upstream review packet

Prepared September 28, 2026. This packet extracts the completed downstream optimization onto `llvm-mos/llvm-mos` revision `26d7c2c1eebf98ca194b92609ba4e7540bfc6ef6`. The [local completion record](../../../plans/2026-09-27-broader-near-store-profitability.md), [canonical missed-optimization record](../../../defects/mos-near-store-profitability.json), original patches, and preserved baseline remain the authoritative September 27 evidence.

## Split series (current)

**Fifth round (2026‑10‑01).** A test-only addition to #321‑11 (frame-index-displacement.ll) changed the #321 hashes from #321‑11 on; 0063 and 0065 were rebuilt on it with unchanged diffs (`pkt-r5-0065` `24b7c4e8a3a8`). 18 patches round-trip to final tree `09cce8159518`; MOS CodeGen+MC 159 pass, 1 unsupported; `llc` byte-identical to round three's ([record](evidence/split-series.json); round three: [`split-series-r3.json`](evidence/split-series-r3.json)).

**Third round (2026‑10‑01).** The #321 commits were rebuilt for the review's N3/N4 findings (comments and whitespace only, plus one sorted `#include`). 0063 replays cleanly. 0065 conflicts in `MOSLegalizerInfo.cpp`, because #321's lines around its hunks were reformatted; the conflict was resolved to the patch's own text (`pkt-r3-0065` `db92a67164bb`). With comments stripped, every file equals the previous candidate's except that include. [`patches-split/`](patches-split/) and [the round-trip record](evidence/split-series.json) are regenerated: 18 patches, every intermediate tree matches, final tree `04a530515ead`, MOS CodeGen+MC 158 pass, 1 unsupported. The previous record is [`split-series-before-r3.json`](evidence/split-series-before-r3.json). The table below describes the earlier split.

This packet's destination was `26d7c2c1eebf`, with its own #321 extraction as patch 1. Its later patches (0063 and 0065, patches 2 and 3 below) now apply with `git am -3`, without conflicts, on the 16-commit [#321 split series](../../2026-09-30/split-320-321/README.md) at `06bc967d2668`. [`patches-split/`](patches-split/) holds the 16 split commits followed by those two patches. On 2026‑09‑30 the split was regenerated with the [native-width pressure-set change](../../../plans/2026-09-30-native-register-pressure-sets.md#application) (#321‑1 and #321‑8), and this section records the rerun on the regenerated commits.

| Check | Result |
| --- | --- |
| 0063 and 0065 on the split | Applied with `git am -3`, no conflicts |
| Final tree | `cde019345d24` |
| Round trip | Each of the 18 patches applied in order to `06bc967d2668` reproduces its commit's tree ([record](evidence/split-series.json)) |
| MOS CodeGen + MC | 158 passed, 1 unsupported: the split's 155 plus 0065's three tests |
| `llc` | sha256 `0f7583ca279b…`; it differs from the previous candidate because the destination and the #321 extraction differ, and now also by the pressure-set change |

The replay, runtime and loaded-pointer measurements below were taken on the `26d7c2c1eebf` series and have not been repeated on the split. Everything below this section is that dated record.

## Scope and publication

The ordered series contains the #321 native compiler prerequisites, 0063's absolute increment rule, and 0065's broader near-store profitability rule with additional boundary tests. Apply all three patches to the exact destination before reviewing or building 0065. Upstream main has no native-width entry point, so the final patch cannot be applied or evaluated alone.

This is a compiler review preparation. The compiler PR is unposted. Merging 0065 requires accepted #321 native-width support and 0063. The [native-width posting hold](../../../321-upstream-native-width-pr.md) remains in force; this packet does not authorize publication or certify the complete native feature's debugger, SDK, or platform integration.

## Destination and prior work

[Reconciliation and source identities](evidence/destination-reconciliation.json) record searches of the canonical record, original reports, local history, standalone patches, aggregate implementation, and live source. The completed change is downstream commit `4d7136cb15cf85a676b624a5892e5e8ce7ae0217`; no new defect is claimed. The September 26 0063 review covers its earlier artifact. This packet has a separate 0065 review.

On the exact destination, `legalizeCustom` calls byte-oriented `legalizeAddSub`, `legalizeLoad`, and `legalizeStore`. Native feature gates, word pseudos, and profitability helpers are absent. The retained [legalizer history](evidence/destination-legalizer-history.json) includes upstream vector scalarization and three-way comparison work; their entry guards remain in the extraction. The destination's #571 register changes are reconciled using native A/X/Y DWARF numbers `0x01000000`–`0x01000002`; high-byte implementation registers have no DWARF number. Native LLDB integration is outside this packet's validation.

## Prerequisite extraction

The first patch extracts native A16/XY16 feature gates, register/instruction definitions, legalization and selection, post-RA mode insertion, accumulator residency, spill/scavenger/frame behavior, and full-width interrupt preservation from `0002`. It includes native immediate printing from 0045, the zero-page byte-index guard from 0051, wide any-extension support from 0055, and the near atomic guards also carried by 0062. Native sign fill remains feature-gated. The observer test supplies the no-wrap proof required to reach indexed rewriting.

The extraction excludes #320 far address spaces, packed pointers, far calling conventions, Imag32 registers, far memory forms, the independent near-index proof-recovery pass, COP assembler support, and SNES implementation/configuration. Existing public [NMI tally ROM evidence](https://biohack.net/snes/nmitally/) supports the local native interrupt contract; that demo was not rebuilt as part of this extraction.

0065 recognizes byte-returned unit arithmetic, indirect call results with zero-size frame teardown, and zero-extended byte sources. It preserves the loaded-destination-pointer native fallback, ordered memory operands, atomic exclusions, same-block checks, and call/inline-assembly barriers. Indirect decrement uses a native store with byte arithmetic. Absolute decrement and profitable indirect increments share byte stores.

## Validation results

| Check | Result |
| --- | --- |
| Ordered patch application | Clean index application on the exact destination produces the recorded candidate tree; one harmless extra-blank-line warning in the prerequisite feature definitions |
| Prerequisites + 0063 suite | 142 passed, one unsupported |
| Final MOS CodeGen + MC suite | 145 passed, one unsupported |
| Preserved original regression | Native modes fail before 0065 and pass afterward; default passes both |
| Frozen IR replay | 486 comparisons: 72 smaller, 414 unchanged, zero larger; 282 bytes saved |
| Default objects | All 12 byte-identical before/after 0065 |
| Loaded destination pointer | Native 17 B versus explicit bytes 22 B in A16 and XY16 |
| Runtime | Host/default/A16/XY16 checksum `0xFA36`; all six MAME/bsnes-jg assertions pass |

[Series hashes and round-trip](evidence/series.json), [baseline identity](evidence/pre0065-identity.json), [candidate identity](evidence/candidate-identity.json), [measurements](evidence/measurements.json), [runtime results](evidence/runtime-candidate-results.json), [runtime dependencies](evidence/runtime-environment.json), and [independent review](independent-review.md) retain the exact artifacts and limits. The baseline was frozen before a single comment wording cleanup; its identity includes the entire comment-only difference from patch 2. No compiler operation differs in that reconciliation. Raw IR, MIR, assembly, object files, commands, diagnostics, and runtime artifacts are retained in the evidence archives.

The [PR body](pr-body.md) is prepared locally. None of this replaces the preserved September 27 corpus run or broadens its claim to a fresh frontend/LTO corpus run. The independent review applies to this packet and its 0065 patch; the complete #321 feature's remaining integration and publication decisions keep their own scope.

## Reproduction

Apply `patches/*.patch` in lexical order with `git am` in a clean checkout of the destination. Build an assertions-enabled LLVM with target MOS and tools `llc`, `llvm-mc`, `opt`, `FileCheck`, `llvm-objdump`, and `llvm-size`. Run `llvm-lit -v llvm/test/CodeGen/MOS llvm/test/MC/MOS` using that build's lit configuration.

Freeze the tools after patch 2 as the comparison baseline and after patch 3 as the candidate. Unpack `micro-inputs.tar.gz` to an input directory and run `validate.py --tools TOOL_DIRECTORY --inputs INPUT_DIRECTORY --out NEW_OUTPUT_DIRECTORY` for each. These are 36 frozen LLVM IR inputs, producing 486 function comparisons. This replays backend optimization with identical IR; it does not rerun the historical 412-input frontend/LTO corpus.

Run `python3 dev/check-near-store-profitability.py TOOL_DIRECTORY docs/defects/evidence/2026-09-27-near-store-profitability/a16-near-store-profit.ll` on both tool sets. The expected comparison is default mode passing on both and the two native modes failing before 0065 and passing after it.

`runtime.py --llc EXTRACTED_LLC --out NEW_OUTPUT_DIRECTORY` runs in the repository development container with the existing SNES SDK/emulators. It uses the identified local frontend to produce IR, the extracted backend for all fixture machine code, and the existing linker/startup libraries. The fixture is an ordinary object with LTO disabled; the existing linker still materializes SDK bitcode for `exit` and `__memset`. It checks the host result against default, A16, and XY16 on MAME and bsnes-jg. This validates the extracted backend while explicitly retaining the local frontend/SDK dependency.

## Attribution

Extraction, destination reconciliation, validation, and packet preparation: OpenAI Codex CLI 0.158.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e75a-a9ed-7372-9bac-b19b732a46a2`. Earlier implementation and evidence credits remain in the linked original records.
