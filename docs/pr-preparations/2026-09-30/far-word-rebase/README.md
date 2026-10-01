# Far-loop (0069) and native-word (0070) series: rebased review packet

Prepared September 30, 2026. This packet rebases the [September 28 extracted series](../../2026-09-28/far-word-index/upstream-series.md) from `26d7c2c1eebf` onto current `llvm-mos/llvm-mos` main `06bc967d2668c7c11c4d6eb43a6aed1f99ad258b`. It repeats that packet's checks on the rebased trees and adds an independent review of the complete compiler/ABI series. It covers both TODO items: the bounded Farblit range proof (0069, patch 8) and the native-word speed policy (0070, patches 12–14). The [plan](../../../plans/2026-09-30-far-word-rebase.md) records the contract. Nothing is posted; the #320/#321 holds and the SNES platform track stay unchanged.

## Split series (current)

Status (2026‑10‑01, third round): **ready for a final check, not for filing.** The [third independent review](independent-review-3.md) found no blocker. Its nonblocking N17–N22 and the older N1, N2, N3 (patches 5 and 6), N5, N7, N8 and N9 are addressed below and in the [#320 map](../split-320-321/REVIEWER-MAP-320.md#where-the-reviews-findings-land). Filing still waits on mlund's answers on #594 (B5 numbering, B7 alignment including the 1b reservation fix, N18). [Plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md#third-round-n17n22-and-the-older-open-items).

The series is #321 in 16 commits (rebuilt for N3/N4), the two MC commits, llvm-mos#584 (our open SPC700 late-opt fix, formerly hidden in #320‑2), #320 in nine commits, then this packet's patches 9, 5–8 and 11–14 (top `f299b753f0d5`, branch `pkt-r3-far-word`). [`patches-split/`](patches-split/) holds all 37 patches in that order.

| Patch | Third-round change |
| --- | --- |
| 9 | N1: `copyPhysRegImpl` and `copyCost` stop with a fatal error naming an unlowered X16↔Y16 or A16 copy instead of reaching `llvm_unreachable`; native-copy-unlowered.mir |
| 5, 6 | N3: their own C++ lines are clang-format clean |
| 8 | N5: `-mos-far-loop-range` removed; the loop proof only narrows the known-bits bound, so it is always on |
| 11 | N2: reduced to `copyHasUndefLanes()` plus a parameter to `handleIdentityCopy` (38 changed lines instead of 299); the X86 characterization test says so. Its output equals the old patch 11's on every CPU |
| 12 | N5: `-mos-far-word-index=all` no longer folds in `optnone` functions |
| 13 | N8: word-store sibling rejection and X8 forcing tests; byte siblings pinned in far-word-policy.mir; the boundary tests' OFF runs removed with the option |

| Check | Result |
| --- | --- |
| Round trip | Each of the 37 patches applied in order to `06bc967d2668` reproduces its commit's tree; final tree `5d6924925790` ([record](evidence/split-series.json); the second round's is [`split-series-before-r3.json`](evidence/split-series-before-r3.json)) |
| Per commit | Every commit built with assertions and passed MOS CodeGen+MC with no MOS warnings: patches 9, 5, 6, 7, 8, 11, 12, 13, 14 give 181, 182, 183, 184, 185, 185, 186, 190, 190 pass, 1 unsupported each ([stages](../split-320-321/evidence/r3/stages.tsv)) |
| Red/green | 35 red runs fail and 230 green runs pass; seven characterization runs pass on their parents by design, all of them in patches 11, 13 and 14 ([table](../split-320-321/evidence/r3/red-green.tsv)) |
| X86 (patch 11) | virtregrewriter-x86-undef-high-byte-result.mir fails on patch 8 ("Found 1 machine code errors") and passes from patch 11 on; virtregrewriter-x86-copy-contracts.mir passes on both, as its header now says |
| Sensitivity (N8) | 111 function/configuration pairs over four test files, 262 of 262 opcode substitutions rejected ([results](evidence/sensitivity-r3.json)) |
| Default mode, all 14 CPUs | Patches 9, 5–8 and 12–14 are identical to their parents. Patch 11 changes three corpus inputs (examples_snes_bf-vm on 12 CPUs, +8 bytes; metaball +1 and sodo +8 on mosw65816), exactly as the reviewed patch 11 did; its message now states it ([sizes](../split-320-321/evidence/r3/patch11-default-size.txt)) |
| Against the second round | The top produces the same assembly and objects as the second-round top for every input on every CPU; only the N20 far-value errors differ ([table](../split-320-321/evidence/r3/default-all-cpus.txt)) |
| Replay objects | The 58 frozen configurations give objects byte-identical to the reviewed carried packet's, which passed MAME and bsnes ([comparison](evidence/split-r3-replay.json)); the emulators were not rerun |

N9, rebase check against the other open PRs (heads read on 2026‑10‑01, applied read-only onto the series top):

| PR | Head | Result |
| --- | --- | --- |
| #593 (mlund, split ZP-stack counters) | `06aad6b5c745` | Its first commit is already in upstream `main`. The second conflicts with #594 and #320 in `MOSMCInstLower.cpp` (the Imag32 operand case) and `MOSZeroPageAlloc.cpp` (#594's composite candidates). Resolved by keeping both: #593's assertion and `PairRequired` around #594's quad branch. Builds; MOS CodeGen+MC 191 pass, including `zp-alloc-65ce02.ll` and every CSR and far test |
| #601 (johnwbyrd, DWARF CFI) | `76e6266607b8` | Merges without conflicts and builds. Two #321 tests (`a16-byte-store.ll`, `a16-indirect-byte-store.ll`) fail: their `CHECK-NEXT` after the function label meets the new `.cfi_startproc`. Whichever lands second updates those two tests; no code conflict |
| #585 (mlund, 65CE02 arithmetic shifts) | `c2fd5d7e32c9` | Merges without conflicts; builds; 191 pass |

## Split series, second round (reviewed by the third independent review)

Status (2026‑10‑01): **ready for a focused third independent review, not for filing.** The [second independent review](independent-review-2.md) upheld the first carry (B1–B3, B6, N3/N4, patch 12) and found two blockers, B8 and B9, and nonblocking N10–N16. All are addressed. The user's #594 decision (option 1) is implemented. Two items stay open:

- the RL DWARF numbering (B5), escalated because the chosen formula lands inside the RS range of the MOS DWARF specification;
- the llvm-mos-sdk companion for the six far runtime entries (N11), queued as future/blocked.

[Plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md#second-round-594-option-1-b8-b9-n10n16); [#320 map](../split-320-321/REVIEWER-MAP-320.md).

The series is #321 in 16 commits, the two MC commits, #320 in nine commits (#594 ×3, the quad reservation fix, the far address space with the RL allocation gate, quad spills, #320‑2..4), then this packet's patches 9, 5–8 and 11–14. [`patches-split/`](patches-split/) holds all 36 patches in that order.

- **Patch 10** (quad spills) is now #320‑1d, the B9 fix.
- **Patch 9** (native index copy costs) now precedes patch 5. Patch 5's own XY16 test (`far-global-long-x.ll`) asserts in `copyCost` ("Unexpected physical register copy") without it. That was never visible, because patch 5 had not been built on its own before.
- **Patch 5** calls the shared B8 helper at the absolute-indexed fold and extends `far-fold-debug.ll`.
- **Patch 12** keeps the word-fold debug test.

| Check | Result |
| --- | --- |
| Round trip | Each of the 36 patches applied in order to `06bc967d2668` reproduces its commit's tree; final tree `3ca03f1da90c` ([record](evidence/split-series.json)) |
| Per commit | Patches 9, 5, 6, 7, 8, 11 and 14 built with assertions and passed MOS CodeGen+MC: 179, 180, 181, 182, 183, 183, 187 pass, 1 unsupported each, no MOS warnings ([stages](../split-320-321/evidence/r2/stages.tsv)). Patches 12 and 13 change only tests over patch 11's and 14's code |
| Red/green | Patch 9's, patch 5's and patch 12's tests are red on their parents and green after ([table](../split-320-321/evidence/r2/red-green.tsv)) |
| Replay objects | The 58 frozen configurations give objects byte-identical to the reviewed packet's, which passed MAME and bsnes ([comparison](evidence/split-r2-replay.json)); the emulators were not rerun |
| `llc` | candidate `c90f96487d2f…` (`build/split-320-321/llc/r2-fw-14`, run commit `6306e48b493b`, same tree as `c275e191de52`), pre-0070 `e34098a6f568…` (`r2-fw-11`) |

The 0070 size and speed table below is unchanged, because every executed object is identical.

## Split series, first carry (reviewed by the second independent review)

Status at the time (2026‑10‑01): **ready for a second independent review, not for filing.** The far-prerequisite repairs B1–B4, the missing B6 trunc pattern and the #320 parts of N3/N4 are now in the #320 commits of the [split series](../split-320-321/README.md#far-prerequisite-carry-2026-10-01), each in the commit whose code it corrects ([plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md)). Two blockers remain open and are escalated: the #594 alignment of #320‑1 (B7) and the far-quad DWARF numbering (B5).

The series is #321 in 16 commits, the two unchanged MC commits, #320 in 4 commits, then this packet's patches 5–14. [`patches-split/`](patches-split/) holds all 32 patches in that order. Patches 5–14 were cherry-picked onto the carried #320‑4. Patches 5 and 12 met context changed by the carried #320 comments and formatting and were resolved by hand. Patch 12 no longer reformats #320‑4 lines (the review's N3 request), so it now carries only its semantic change. Patch 12 also extends `far-index-fold-debug.ll` with the word fold, because the 0070 word fold reuses #320‑4's repaired fold path.

| Check | Result |
| --- | --- |
| Round trip | Each of the 32 patches applied in order to `06bc967d2668` reproduces its commit's tree; final tree `f3aba3593673` ([record](evidence/split-series.json)) |
| Final tree vs the previous candidate `77dc044c39bb` | the pressure-set change, the carried repairs (11 library files) and 18 added test files; no other path |
| MOS CodeGen + MC | candidate (patch 14): 179 passed, 1 unsupported; pre-0070 (patch 11): 175 passed, 1 unsupported; no MOS build warnings |
| Pre-0070 `llc` on the candidate's tests | fails exactly `far-word-policy.mir`, `far-word-index-integration.ll`, `far-word-index-boundaries.mir` and the word-fold half of `far-index-fold-debug.ll` ([results](../split-320-321/evidence/carry/pre0070-tests.txt)) |
| X86 0028 regressions | not rerun: patch 11 and the generic `VirtRegMap.cpp` are unchanged |
| Replay objects | the 58 frozen post-LTO IR configurations give byte-identical objects with and without the carry; 34 of them differ from September 28 because of the pressure-set change ([comparison](evidence/split-carry-replay.json)) |
| MAME and bsnes | all 58 configurations pass on both emulators, with repeat bsnes profiles equal ([results](evidence/split-carry-runtime-results.json)) |
| `llc` | candidate `cce5eb24ccd61411…`, pre-0070 `3626b2ca18d2fd22…` (`build/split-320-321/llc/c-fw-14`, `c-fw-11`; assertions Release build of `build/split-320-321/build`) |

0070 on the current series (default vs baseline `main`, the level gate unchanged):

| Farblit `main` | Os | Oz | O2 | O3 |
| --- | --- | --- | --- | --- |
| A16 | identical | identical | +9 bytes, 7.25% faster | −21 bytes, 7.07% faster |
| XY16 | identical | identical | +23 bytes, 9.70% faster | −19 bytes, 7.33% faster |

The pressure-set change moved these from September 28's O2 results (A16 −111 bytes and 7.78% faster; XY16 −29 bytes and 7.81% faster). At O2 the policy now trades a few bytes for speed, which is the objective of that level. The `bounds` and `farblit_press` fixtures are unchanged by 0070, as before. The 0069 effect was not isolated: every replay configuration contains patch 8.

Everything below this section describes the monolithic-prerequisite series and remains its dated record.

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

**Third review (2026‑10‑01), of the second round on #594:** [independent-review-3.md](independent-review-3.md). No new blocker: #594 is carried faithfully, and B8, B9, N10 and N12–N15 are fixed. The #320 prerequisite and 0069/0070 can file once mlund answers the #594 points (B5 numbering, B7 alignment including the 1b reservation fix). Nonblocking N17–N22 remain, notably N17: #320‑2 silently fixes an upstream SPC700 segfault.

**Second review (2026‑10‑01), after the far-prerequisite carry:** [independent-review-2.md](independent-review-2.md). B1, B2, B3 and B6 are fixed and B4 is fixed at its site, but two new blockers remain: B8 (the same dangling `DBG_VALUE` at three other far fold sites) and B9 (#320 asserts on Imag32 spills until far-word patch 10). Filing still waits on those as well as B5/B7.

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
  - ~~Repair B1–B4 downstream with same-input red/green regressions, and carry the repairs into the #320 series.~~ Done: downstream in `664b877a`, split carry on 2026‑10‑01.
  - ~~Restore the omitted trunc pattern (B6).~~ Done in #320‑2.
  - Decide the far-quad DWARF representation (B5); escalated with B7.
  - ~~Apply N3 and N4 to the #320 commits.~~ Done. ~~N3/N4 in the #321 commits and far-word patches 5 and 6, and N1, N2, N5 and N7–N9.~~ Done in the third round (patch 10 is #320‑1d, which is clean).
  - ~~Third review's N17–N22.~~ Done in the third round, except N18, which is mlund's to answer.
  - Decide whether the HuC6280 block-move fix inside #321‑11 should also go upstream on its own, like #584 ([record](../../../defects/mos-huc-blockmove-frameindex-offset.json)).
  - ~~Rerun this packet's checks and the runtime replay.~~ Done on the carried split. Then have the series independently reviewed again.
- **Reconcile with #594 (B7).** Settle this with its author and the maintainers before filing a competing register definition.
- **Settle the #320/#321 scope.** This rebased series does not certify either feature issue. Compiler overhead and independent-application profitability remain unmeasured.
- **Before posting,** publish immutable evidence links and recheck the destination.

## Attribution

Rebase, validation, reconciliation and packet preparation: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`. The September 28 extraction, copy-cost repair and measurements: OpenAI Codex CLI 0.157.1 (session source `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`. The independent review names its own attribution. Second and third rounds (after the second and third independent reviews): Claude Code 2.1.285 (t4-opus-high agent `a7633adfeee82a4f5`), model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort; session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F). Carry of the far-prerequisite repairs into the split, the packet rebuild and the 2026‑10‑01 replay: Claude Code 2.1.285 (t4-opus-high agent `a7633adfeee82a4f5`), model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort; session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F). Downstream replay of the review findings and the four defect records: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`.
