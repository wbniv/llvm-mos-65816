# #320/#321 split into reviewable commit series

Status: split landed on branch `split-320-321` in `build/split-320-321/source` (a worktree of `.scratch/carry-clang-upstream/source`), head `d228074b8659`. Nothing is posted. Contract: [the split plan](../../../plans/2026-09-30-split-320-321-series.md).

Attribution: Claude Code 2.1.283 (t4-opus-high agent), model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`.

| Directory / file | Contents |
|---|---|
| [REVIEWER-MAP-321.md](REVIEWER-MAP-321.md) | 16 #321 commits: purpose, key hunks, tests, validation, default-mode effect, dependency diagram |
| [REVIEWER-MAP-320.md](REVIEWER-MAP-320.md) | 4 #320 commits, the #594 reconciliation point, and where the independent review's B1–B7/N3/N4 findings land |
| [patches-321/](patches-321/) | `git format-patch` of the #321 series on `06bc967d2668` |
| [patches-mc/](patches-mc/) | the two MC address-width commits, unchanged apart from their parent |
| [patches-320/](patches-320/) | the #320 series, applied after `patches-mc/` |
| [spec/](spec/) | everything needed to rebuild the series and its evidence (see [Reproducing](#reproducing)) |
| [evidence/](evidence/) | per-commit suite summaries, default-mode comparisons, red/green proofs, invariant lists, and sha256 of the large logs |

## Chain

`06bc967d2668` → #321 1–16 (`c38fa4cc5a60`..`780d9e028c04`) → MC `f088a60da471` "Honor explicit address widths for constant operands" → MC `03f35f926152` "Preserve long address widths in printed assembly" → #320 1–4 (`e58e959eb861`..`d228074b8659`).

The MC commits keep their diffs, messages, authors and dates.

## Invariants

The split must reproduce the monolithic patches, except that it may add test files under `llvm/test/` so every commit carries its own tests.

| Gate | Result |
|---|---|
| #321 end tree vs `340c8ee25d5c^{tree}` | **Equal plus 10 added `llvm/test/` files, no other path** ([list](evidence/321.invariant.txt)); checked by `build-series.sh` and again by applying `patches-321/` to `06bc967d2668` (tree `6bb9b089ba56`) |
| #320 end tree vs `11044c53d5fc^{tree}` | **Equal plus 11 added `llvm/test/` files, no other path** ([list](evidence/320.invariant.txt)); applying `patches-mc/` then `patches-320/` gives tree `007a292544d2` |
| Every commit builds with assertions and passes MOS CodeGen + MC | **Yes** for all 20 split commits (table below); no new warnings in `lib/Target/MOS` |
| Every added test fails on its parent and passes on its own and every later commit | **Yes** for all 11 ([red/green](evidence/red-green.tsv)) |
| Later packet patches apply unchanged | **Yes**: far-word 5–14, the near-index recovery patch, and 0065's 0063/0065 patches (below) |
| No #320 content in the #321 commits (`AS_Far`, `AS_FarPacked`, `FarCC`, `p2`, `Imag32`, `addrspace(2)`) | **None in code.** One test, `xy16-near-indir-y.ll`, carries a data layout string containing `p2:32:8-p3:24:8` |

## Tests the split adds

| Commit | Test | Fails on the parent because |
|---|---|---|
| #321‑1 | `native-width-registers.mir` | unknown register name `a16` (and unrecognized features) |
| #321‑2 | `a16-accumulator-forms.mir` | unknown machine instruction `LDAImag16` |
| #321‑3 | `MC/MOS/index-width-mapping-65816.s` | no `$xh` mapping symbols |
| #321‑3 | `xy16-index-forms.mir` | unknown machine instruction `LDXImm16` |
| #321‑5 | `scavenger-p-undef-6502.ll` | mos6502 -O0 assertion "expected N to be free when saving scavenger register" |
| #321‑6 | `native-spill-copy.mir` | byte spill path assertion on A16 |
| #321‑7 | `coalesce-call-clobbered-imag.mir` | `$rc2`/`$rc3` coalesced into the pair across the call |
| #321‑8 | `a16-load-store.ll` | byte loads and stores |
| #321‑13 | `near-index-nowrap.ll` | mosw65816 folds the plain and global-base adds |
| #321‑15 | `a16-small-add.ll` | `adc #2` under +mos-a16 |
| #320‑1 | `imag32-copy.mir` | unknown register name `rl2` |

`scavenger-p-undef-6502.ll` is reduced from gcc.c-torture `strlen-4.c` and comes from the downstream tree's tests. It shows that #321‑5 also fixes an assertion in default mos6502 code at -O0. The other ten tests were written for this split. None has yet been copied into downstream `0002` or `vendor/`.

## Per-commit evidence

Build and suite: an assertions build per commit in `build/split-320-321/build` (hard-link copy of `build/far-word-rebase/build`), MOS CodeGen + MC lit in the dev container, with the not-yet-added tests probed against each build. Default-mode hashes come from the first run, before tests were added; every commit's `llc` in the tests run is byte-identical to that run's (`llc_sha256_same_as_default_run` in [series-evidence.tsv](evidence/series-evidence.tsv)), so the comparison carries over unchanged.

| Commit | lit (pass) | mos6502 vs parent | mosw65816 vs parent |
|---|---|---|---|
| base `06bc967d2668` | 132 | — | — |
| #321‑1 | 133 | 18 asm differ | 33 asm differ |
| #321‑2 | 134 | identical | identical |
| #321‑3 | 136 | identical | 68 object-only (`$xh` symbols) |
| #321‑4 | 138 | identical | identical |
| #321‑5..11 | 139–147 | identical | identical |
| #321‑12 | 149 | 16 asm differ | 17 asm differ |
| #321‑13 | 150 | identical | 28 differ (27 asm, 1 newly compiling) |
| #321‑14, 15 | 151, 152 | identical | identical |
| #321‑16 | 153 | identical | 3 asm differ (interrupt handlers) |
| MC ×2 | 158 | — | — |
| #320‑1..4 | 159, 161, 162, 163 | #320‑2: 5 far inputs fail with a different error; others identical | same |

Each run also has one unsupported test, `getchar-regression.ll` (its own `REQUIRES`). Default-mode method, explanations and code-size numbers: [REVIEWER-MAP-321.md](REVIEWER-MAP-321.md#default-mode-evidence).

## Downstream packets on the split

Each packet's later patches were applied unchanged with `git am -3` on the split, then built and run through the MOS CodeGen and MC suites. Each packet README now has a "Split series" section, a `patches-split/` directory and an `evidence/split-series.json` round-trip record. Their independent reviews are unchanged.

| Packet | Series | Conflicts | Final tree vs previous candidate | Suites | `llc` vs previous candidate |
|---|---|---|---|---|---|
| [far-word](../far-word-rebase/README.md) | #321 1–16, MC ×2, #320 1–4, far-word 5–14 (32) | none | `77dc044c39bb` + 11 added tests | 172 pass + both X86 0028 regressions | identical |
| [near-index](../../2026-09-29/near-index-proofs/README.md) | #321 1–16, recovery patch (17) | none | `980fe1f29381` + 10 added tests + one `MOSFeatures.td` blank line | 155 pass | identical |
| [0065](../../2026-09-28/0065/README.md) | #321 1–16, 0063, 0065 (18) | none | different destination (`26d7c2c1eebf` before) | 156 pass | differs (destination) |

The coordinator's brief listed the far-word order as MC ×2 before #321. The series keeps #321 first, as the packet's patch 1 did before patches 2–3, because the split and all of its evidence were built in that order.

## Deviations from the plan

Each was needed for a build or test gate, or to keep one concept per commit.

1. **Plan #321‑2 split into 2 (accumulator forms) and 3 (index forms).** Together they were about 600 lines of TableGen, and the index half changes default mosw65816 objects (`XHigh` → `$xh` mapping symbols), which must sit in a named commit.
2. **Plan #321‑6 split into commits 5, 6 and 7, placed before selection.** Scavenger status-flag preservation, native spills/copies and the coalescing guard are separate concepts; the spill/copy lowering comes before the first selection commit so no selection commit can meet a native value it cannot spill. Scavenging (5) precedes spills (6) because both use `computeLiveBefore`, which would otherwise land in the middle of the removed `assertNZDeadAt`.
3. **Plan #321‑4a..4d reordered and split:** 8 loads/stores, 9 s32/s64 lanes and wide any-extensions (plan 4d), 10 ALU and shifts (plan 4b), 11 compares (plan 4c). Wide lanes precede the ALU: in the first ordering, native arithmetic without them failed `anyext-masked-byte.ll` under `+mos-a16` with "unable to legalize … G_UNMERGE_VALUES s64".
4. **Monolithic tests moved to the commit that makes them pass.** `a16-byte-store.ll` and `a16-indirect-byte-store.ll` need a native `adc` producer and the A16 residency peephole, so they land in commit 10. `a16-immediate-width.ll` needs native compares and lands in commit 11.
5. **Late optimization (`threadAccum16`) merged into the ALU commit (10)** instead of plan #321‑6, because the byte-store tests need it.
6. **Byte-index guard is its own commit (12)**: it changes default codegen in both modes and is independent of native widths.
7. **`+mos-xy16` selection is its own commit (14)** instead of being spread over 4a–4c.
8. **Small 8-bit add relief is its own commit (15)**: a register-allocation measure, not ALU selection.
9. **Plan #320‑2 and #320‑3 merged** (commit 2): legalization alone has no observable test. #320 has 4 commits, not 5.
10. **Default-mode changes beyond the expected one.** The plan expected only the near-index no-wrap guard (#321‑13). The split also found #321‑1 (register pressure sets), #321‑3 (object mapping symbols), #321‑5 (a mos6502 -O0 assertion becomes a pass), #321‑12 (byte-index guard) and #321‑16 (interrupt handlers on plain mosw65816). Each commit message states its effect.
11. **Interim text.** Three places carry intermediate-only lines so earlier commits compile without later concepts; the end tree is unaffected: `tryIndexedAddressing16`'s opcode lambdas and constant-offset condition (commits 8–13), `foldableAbsLoad16`'s condition without the Xc16 guard (10–13), and the `selectGeneric` Imag32 pin condition without the indexed far opcodes (#320‑2, ‑3).
12. **Added tests** (coordinator decision after the first report): the end-tree invariant was relaxed to "monolithic tree plus added `llvm/test/` files", and 11 focused tests were added.

## Unresolved

- **#321‑1 changes default codegen** through generated register pressure sets (+1.2% mos6502, +1.1% mosw65816 on the fixed set) although it only adds opt-in registers. Raised with the user separately; out of scope here.
- **#594.** #320‑1 defines the Imag32 family that open PR #594 also defines, with a different register-number offset and allocation policy. It must be reconciled before submission; #320‑1 is the commit a #594 rebase replaces ([details](REVIEWER-MAP-320.md#1-add-the-far-address-space-and-32-bit-imaginary-pointer-quads-e58e959eb861)).
- **Review findings are not fixed here** (by instruction): B1–B7, N3 (clang-format) and N4 (60 history-tag comment lines, including a broken "(Native widths: )" in #321‑8) are mapped to commits in [REVIEWER-MAP-320.md](REVIEWER-MAP-320.md#where-the-independent-reviews-findings-land).
- **0065 measurements** (replay, runtime, loaded pointer) were taken on its `26d7c2c1eebf` series and were not repeated on the split.
- **Commits 5, 7 and 16 independence** from the rest of the series is by code inspection; they were built only in series order.

## Reproducing

[`spec/`](spec/) is a copy of `build/split-320-321/spec/`:

- `321.diff`, `320.diff`: the monolithic diffs (`git diff 06bc967d2668 340c8ee25d5c`, `git diff 0c77988b2e0b 11044c53d5fc`) with the added tests appended (`321.tests.diff`, `320.tests.diff`); `321.spec`, `320.spec`: which diff lines each commit introduces, plus the interim lines; `stage.py`: emits the cumulative patch for one stage.
- `build-series.sh`, `build-all.sh`: rebuild the whole chain from the specs and `msgs/` (generated by `msgs/gen321.py`, `msgs/gen320.py`) and check both tree invariants.
- `run-stages.sh`, `build-and-test.sh`: per-commit build, suites, probe of not-yet-added tests, and default-mode hashes. `default-hashes.sh`, `compare-hashes.py`, `size-compare.sh`, `obj-diff.sh`: default-mode evidence. `red-green.py`: the red/green table. `format-count.sh`: N3 counts. `packet.sh`, `packet-record.py`: downstream packet rebuilds and round-trip records. `collect-evidence.sh`: fills [`evidence/`](evidence/).

The scripts name `build/split-320-321/source` (a worktree of `.scratch/carry-clang-upstream/source`) and its build directory; run them from a copy placed there. Default-mode inputs are `build/split-320-321/default-inputs/` (38 MOS `.ll` tests at the base plus 52 corpus IRs). Full build and lit logs stay under `build/split-320-321/evidence/`; [large-logs.sha256](evidence/large-logs.sha256) records their hashes. Frozen `llc` binaries kept: `build/split-320-321/llc/{321-00,321-16,320-04}`.
