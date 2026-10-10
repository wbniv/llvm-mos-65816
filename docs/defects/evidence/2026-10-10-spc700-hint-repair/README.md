# SPC700 copy-hint repair: evidence (2026‑10‑10)

This directory supports [`mos-spc700-hint-outside-order`](../../mos-spc700-hint-outside-order.json) and the [plan](../../../plans/2026-10-10-spc700-hint-outside-order.md). The 2026‑10‑01 baseline in [`2026-10-01-spc700-hint-outside-order/`](../2026-10-01-spc700-hint-outside-order/) is unchanged.

Attribution: Claude Code 2.1.296, `t4-opus-high` agent, model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort (agent definition); session [session_012Tm5osWxSMUvv28Uw7nudx](https://claude.ai/code/session_012Tm5osWxSMUvv28Uw7nudx).

## Compilers

All four are assertions-enabled Release builds of upstream `06bc967d2668`. [`identity.json`](identity.json) records their host paths and SHA‑256 hashes.

| Name | Source | `llc` SHA‑256 |
|---|---|---|
| `up-06bc967d` | upstream `06bc967d2668` | `2f5c1768…` (bit-identical to the record's `p-321-00`) |
| `fix-06bc967d` | + [`repair-06bc967d.diff`](repair-06bc967d.diff) | `55e62f61…` |
| `up584-06bc967d` | + [`upstream-584.diff`](upstream-584.diff) (llvm-mos#584, merged 2026‑10‑05) | `c3878a98…` (bit-identical to `r3-584-up`) |
| `fix584-06bc967d` | + #584 + repair | `8f3f3c1d…` |

The builds reproduce the preserved baselines byte for byte, so the rebuilt tree is the tree that was tested. #584 is needed for end-to-end IR runs, because on `06bc967d` the reduced input reaches the late-optimization crash that #584 fixed once allocation succeeds. Destination results on upstream main `0f031168a7cc` are in the [upstream packet](../../../pr-preparations/2026-10-10/spc700-hint-order/README.md).

## Inputs

- [`boids-reduced.ll`](boids-reduced.ll) is reduced from the record's `boids.ll` by `llvm-reduce`. The [`interesting.sh`](interesting.sh) script accepts an input when `up-06bc967d` reports the assertion; see the [reduction log](llvm-reduce.log). It is a loop that loads a function pointer and calls it.
- [`regalloc-spc700.mir`](regalloc-spc700.mir) is the upstream regression test: the thunk-opcode constant copied into RC17, with and without an intervening call.
- [`boids-pre-greedy-main-excerpt.mir`](boids-pre-greedy-main-excerpt.mir) and [`boids-regalloc-debug-tail.log`](boids-regalloc-debug-tail.log) come from the original input. `%420:anyi8 = LDImm 95` is hoisted out of the loop; `$rc17 = COPY %420` feeds `JSR &__rc17`, and greedy prints `hints: $rc17` just before the assertion. [`reduced-pre-greedy.mir`](reduced-pre-greedy.mir) shows the same shape for the reduced input.

## Red/green

Exit codes come from the logs in this directory (`<check>-<compiler>.log`; the last line is `exit_code=`).

| Check | `up-06bc967d` | `fix-06bc967d` | `up584-06bc967d` | `fix584-06bc967d` |
|---|---|---|---|---|
| `mir-*`: `regalloc-spc700.mir`, `-run-pass=greedy,virtregrewriter -verify-machineinstrs` | 134, hint assertion | **0** | 134, hint assertion | **0** |
| `reduced-*`: `boids-reduced.ll -O2 -verify-machineinstrs` | 134, hint assertion | 139, late-opt crash (#584) | 134, hint assertion | **0** |
| `boids-*`: record baseline command | 134, hint assertion | 134, spill-hoist abort in `@_title_emit` | 134, hint assertion | 134, spill-hoist abort in `@_title_emit` |
| `boids-disable-spill-hoist-*`: baseline + `-disable-spill-hoist -verify-machineinstrs` | 134, hint assertion | 139, late-opt crash (#584) | 134, hint assertion | **0** |

The `@_title_emit` abort (`Remaining virtual register … dead early-clobber %2480:imag16 = STStk`) is a separate, pre-existing defect. [`title-emit-first.py`](title-emit-first.py) moves `@_title_emit` ahead of `@main`; the unrepaired `up-06bc967d` and `up584-06bc967d` then abort in `@_title_emit` with the same message (`title-emit-first-*.log`). This is the spill-hoist scratch-register defect that local patch `0033` repairs. Upstream clang always passes `-disable-spill-hoist` for MOS (`clang/lib/Driver/ToolChains/CommonArgs.cpp`), so compiler-driver builds do not reach it. The 2026‑10‑01 record attributed this abort to the #320 1c filter; the 1c logs place it in `@_title_emit` as well, after the non-fatal "ran out of registers" error in `@main`.

After the repair the hint is gone and RC17 is fed from an allocatable register: [`reduced-post-rewriter-fix584.mir`](reduced-post-rewriter-fix584.mir) has `renamable $rc22 = LDImm 95` and `$rc17 = COPY renamable $rc22`; [`reduced-fix584.s`](reduced-fix584.s) is the assembly.

## Suites

MOS lit (`llvm/test/CodeGen/MOS`, `llvm/test/MC/MOS`) on the same build trees:

- `fix-06bc967d`: 134 tests, 133 passed, 1 unsupported ([log](lit-fix-06bc967d.log)).
- The same tree with `up-06bc967d` as `llc`: 132 passed, 1 unsupported, 1 failed: `CodeGen/MOS/regalloc-spc700.mir` ([log](lit-up-06bc967d.log)).
- `fix584-06bc967d`: 135 tests, 134 passed, 1 unsupported ([log](lit-fix584-06bc967d.log)).

## Corpus census

The census compiles all 52 default-mode IRs for `mosspc700` at `-O0` to `-O3`. For `-Os` and `-Oz`, `llc -O2` compiles copies of the IRs whose attribute groups carry `optsize` or `minsize optsize`, the attributes clang passes for those levels. It compares `up584-06bc967d` with `fix584-06bc967d`. [`census/summary.txt`](census/summary.txt) has the counts. The per-input rows are `census/*.tsv`, made by [`census.sh`](census/census.sh); it was run from `.scratch/spc700-hint/`, where the attribute-rewritten inputs live.

- With `-verify-machineinstrs -disable-spill-hoist` (clang's setting), all 18 asserting inputs compile at each of `-O1`, `-O2`, `-O3`, `-Os` and `-Oz`, with the verifier clean: 90 outcomes go from failing to passing. No other outcome changes. All 177 input/level pairs that compiled before produce byte-identical assembly. `-O0` (fast allocator) does not change.
- Without `-disable-spill-hoist`, the same 90 outcomes move from the hint assertion to the spill-hoist abort. All 100 rewriter aborts in that run, including 10 that both compilers share, show the `STStk` scratch-register signature.
- The other failures are present on both compilers and unrelated: 5 far-pointer legalization errors, one Loop Strength Reduction assertion, and `-O0`/`-Oz` verifier errors.
- On other CPUs ([`xcpu.sh`](census/xcpu.sh), `-O2 -disable-spill-hoist`), exit codes and assembly are identical for `mos6502`, `mos65c02`, `mos65ce02` and `moshuc6280` (19 inputs compile on each) and for `mosw65816` (46 inputs).

In the repaired SPC700 output, the 18 inputs at `-O2` have 124 `call __rc17` sites and 124 `mov __rc17,#95` instructions: a post-allocation pass folds the register copy back to the immediate (see `reduced-fix584.s`). The counts match; they were not paired site by site. The cost of the repair is the hoisted register that held the constant, plus any save of it as a callee-saved register. Release builds without the repair placed the constant in the reserved RC17, and that output was not measured. A release comparison, or the call-lowering follow-up in the plan, would settle the size question.

**Optimization levels:** this is an allocator-contract repair, so it is not gated by level. Every level that runs greedy reaches it.
