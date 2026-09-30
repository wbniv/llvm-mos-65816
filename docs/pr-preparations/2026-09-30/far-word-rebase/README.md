# Far-loop (0069) and native-word (0070) series: rebased review packet

Prepared September 30, 2026. This packet rebases the [September 28 extracted series](../../2026-09-28/far-word-index/upstream-series.md) from `26d7c2c1eebf` onto current `llvm-mos/llvm-mos` main `06bc967d2668c7c11c4d6eb43a6aed1f99ad258b`. It repeats that packet's checks on the rebased trees and adds an independent review of the complete compiler/ABI series. It covers both TODO items: the bounded Farblit range proof (0069, patch 8) and the native-word speed policy (0070, patches 12–14). The [plan](../../../plans/2026-09-30-far-word-rebase.md) records the contract. Nothing is posted; the #320/#321 holds and the SNES platform track stay unchanged.

## Series and rebase

The same 14 patches were applied with `git am -3`, with no conflicts. For every commit, the added and removed lines equal the September 28 series; the [range-diff](evidence/range-diff.txt) differs only in context. The [round-trip](evidence/series.json) applies each [rebased patch](patches/) to the destination in order and matches every intermediate tree, with no whitespace warnings.

| # | Patch | Role |
| ---: | --- | --- |
| 1 | Native widths and near-memory foundation | #321 prerequisite, as in the 0065 packet |
| 2–3 | Explicit address widths; long widths in printed assembly | MC prerequisites |
| 4 | Far data addressing and bounded runtime indexing | #320 prerequisite |
| 5–7 | Far indexed bytes, native far words, extending-load worklist | Earlier 0061/0062/0066 work |
| 8 | Bounded byte-loop proof | **0069** |
| 9 | Native index copy costs | Repair found by the September 28 extraction |
| 10 | Four-byte far-quad spills | Earlier 0018 |
| 11 | Generic VirtRegRewriter undefined-lane identity copies | Earlier 0028 |
| 12–14 | Speed-only bounded native far-word loads, plus checks | **0070** |

## Destination reconciliation

Three upstream commits landed after the previous base:
- **#570** (GlobalISel debug-info salvaging) edits generic GlobalISel utilities.
- **#586** (optional BRK signature operand) edits `MOSInstrInfo.td`.
- **#605** (experimental SSA register allocator) edits the MOS pass configuration. It sits behind `-mos-experimental-regalloc`, which defaults to off through the CMake option `LLVM_MOS_EXPERIMENTAL_REGALLOC_DEFAULT=OFF`, so the conventional allocator the series was validated against is unchanged.

The [open-PR overlap](evidence/open-pr-overlap.json) lists 13 open upstream PRs sharing files with the series. One is a definition-level collision. **#594** (`mlund`, "Add 32-bit imaginary register foundation") defines `MOSImagReg32`, `RL` registers, `MaxImag32Regs` and an `Imag32` class. Patch 4 defines the same names for far-pointer quads, with a hardcoded register-number offset of `0x600` where #594 uses `Imag16RegsOffset + MaxImag16Regs`. Whichever merges second conflicts. The series should be reconciled with #594's register foundation before submission. The others share files with #601 (DWARF/CFI), #603, #593, #585 and several of our own PRs, which is ordinary merge-order overlap.

## Validation results

| Check | Result |
| --- | --- |
| Rebase and round-trip | 14/14 patches apply; every intermediate tree matches; changed lines identical to September 28 |
| Candidate suites | MOS CodeGen/MC plus both X86 0028 regressions: 164 tests, 163 passed, 1 unsupported (`getchar-regression.ll`, by its own directive) ([log](evidence/candidate-suite.log)) |
| Compared with September 28 | Same statuses for every shared test. New: upstream's `brk-signature.s` and the two X86 regressions, which previously ran separately. |
| Pre-0070 tools | Fail only `far-word-policy.mir`, `far-word-index-integration.ll` and `far-word-index-boundaries.mir` ([log](evidence/pre0070-suite.log)) |
| Opcode sensitivity | 6 real outputs pass; 228/228 single-opcode substitutions rejected ([results](evidence/sensitivity-results.json)). Legalizer outputs are byte-identical to September 28 apart from the input path in `ModuleID`. |
| Runtime replay | The frozen post-LTO IR of all 58 configurations was compiled by the rebased pre-0070 and candidate backends, linked with the existing SDK, and run on MAME plus the calibrated bsnes probe twice. All pass, and repeat profiles agree. Every object hash, ROM hash, main-byte count and master-clock count is identical to September 28 ([results](evidence/runtime-results.json)). |

Because the executed programs are byte-identical, the September 28 [size and master-clock table](../../2026-09-28/far-word-index/upstream-series.md#rebased-runtime-and-size-evidence) applies unchanged to the rebased series. It includes the O3 XY16 size cost and the size-mode controls. [Identity](evidence/identity.json) records both frozen toolsets (pre-0070 `llc` `b86894b7…`, candidate `llc` `d7fde754…`), the build configuration and the host directories behind each container mount.

## Independent review

[Verdict](independent-review.md): **do not file this series yet.** The reviewer confirmed every coordinator result above with its own runner on the frozen tools. It found the rebase faithful and upheld the optimizations:
- **0069:** the Z-flag loop bound holds at every use.
- **0070:** admission matches the description across 17 probe functions, both modes and O0–O3, and the word load always runs with an 8-bit Y.
- **Patches 9–11:** the copy-cost repair, the quad spills and the generic identity-copy repair all held.

The blocking findings are in the far prerequisite (patch 4) that those optimizations sit on. Each has a concrete input in the [review evidence](evidence/independent-review.json). They were then replayed on the downstream release toolchain (`llc` `9031686c`, built from the committed patch stack at `5dc63f4d`):

| # | Finding | Downstream | Record |
| --- | --- | --- | --- |
| B1 | A fourth far-pointer argument gets a 16-bit RS pair | Verifier error; segfault without the verifier | [mos-far-pointer-arg-exhaustion](../../../defects/mos-far-pointer-arg-exhaustion.json) |
| B2 | Far memory lengths above 65535 are truncated or the call is deleted (silent) | Same: 70000 → 4464, a 65536-byte memmove removed | [mos-far-memop-length-truncation](../../../defects/mos-far-memop-length-truncation.json) |
| B3 | Far runtime loads on non-65816 CPUs emit `$A7` (silent) | Same on `mos6502` | [mos-far-access-non-65816](../../../defects/mos-far-access-non-65816.json) |
| B4 | The far index fold leaves an undef `DBG_VALUE`, so `-g` fails `-verify-machineinstrs` | Same, byte and word folds | [mos-far-index-fold-dangling-dbg](../../../defects/mos-far-index-fold-dangling-dbg.json) |
| B5 | Far-quad DWARF location describes 46 bits | Not reproduced: downstream emits `DW_OP_regx RL1`, a number outside the MOS DWARF specification | Extraction gap |
| B6 | s32→s16 `G_TRUNC` reaches `selectTrunc` and asserts | Not reproduced: downstream selects it with `Pat<(i16 (trunc Imag32:$s)), (EXTRACT_SUBREG Imag32:$s, sublo16)>` in `MOSInstrLogical.td`, which the extraction omitted | Extraction gap |
| B7 | Patch 4's `Imag32` definitions collide with open #594, which keeps them non-allocatable over a linker contiguity concern | Process | Needs a maintainer and author decision |

The nonblocking findings, and how each is handled:
- **N1:** X16↔Y16 and A16 copies are neither lowered nor costed, and no input reaches them.
- **N2:** patch 11 could be a smaller diff, and one of its two tests is characterization only.
- **N3:** clang-format would rewrite 613 lines.
- **N4:** 52 comment lines carry development-history tags.
- **N5:** drop `-mos-far-loop-range`, and make `all` honour `optnone`.
- **N6:** the suite records named container paths. Fixed: [suite provenance](evidence/suite-provenance.json) now maps each mount to its host directory and binary hash.
- **N7:** list the loud unsupported shapes in the PR.
- **N8:** the sensitivity runner does not mutate the boundary tests.
- **N9:** rebase checks are needed against #593, #601 and #585.

All but N6 apply to the patch text itself, so they belong to the split series below.

## What remains before filing

- **Split the prerequisites.** Rebuild the prerequisites as reviewable #321 and #320 commit series ([plan](../../../plans/2026-09-30-split-320-321-series.md)). The repairs below land in those commits, not as fixes on top of monolithic patches 1 and 4.
- **Repair and re-review.**
  - Repair B1–B4 downstream with same-input red/green regressions, and carry the repairs into the #320 series.
  - Restore the omitted trunc pattern (B6).
  - Decide the far-quad DWARF representation (B5).
  - Apply N1–N5 and N7–N9.
  - Rerun this packet's checks and the runtime replay, then have the series independently reviewed again.
- **Reconcile with #594 (B7).** Settle this with its author and the maintainers before filing a competing register definition.
- **Settle the #320/#321 scope.** This rebased series does not certify either feature issue. Compiler overhead and independent-application profitability remain unmeasured.
- **Before posting,** publish immutable evidence links and recheck the destination.

## Attribution

Rebase, validation, reconciliation and packet preparation: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`. The September 28 extraction, copy-cost repair and measurements: OpenAI Codex CLI 0.157.1 (session source `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`. The independent review names its own attribution. Downstream replay of the review findings and the four defect records: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`.
