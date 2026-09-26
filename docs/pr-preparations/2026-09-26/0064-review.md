# 0064: destination review and profitability assessment

Author review by OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`,
`xhigh` reasoning effort; verified session
`01a0dd01-d72e-76f2-bf27-a796e0f7d994`. This is the implementation agent's
review, not an independent review. Earlier credits remain in the
[implementation plan](../../plans/2026-09-26-mos-carry-scheduling.md).

## Exact destination reconciliation

The live GitHub API returned llvm-mos main
[`7bd67c0ae4e8`](https://github.com/llvm-mos/llvm-mos/commit/7bd67c0ae4e8bb65a3f980912bf201df22131e34).
The [saved reply](validation/runs/carry-0064-upstream/audit/destination.json)
identifies the complete revision. The extraction has no candidate prerequisites.

At that revision, `MOSTargetMachine::createMachineScheduler` constructs
`MOSSchedStrategy`; `MOSSubtarget::enableMachineScheduler` returns true, and
`MOSPassConfig::alwaysRequiresMachineScheduler` returns true. The subtarget
forces pressure tracking and permits both scheduling directions. There is no
entry guard that makes the path unreachable. A debugger stop in
`MOSSchedStrategy::initialize` also confirmed this call chain during MIR replay.
The scheduler's existing A, X/Y and imaginary-register preferences precede
generic pressure checks. `Cc` is still marked fine grained, while TableGen's
initial pressure sets still omit that flag. 0064 does not modify that contract.

[Scheduler history](validation/runs/carry-0064-upstream/audit/scheduler-history.json)
includes `f8376e9c5d63`, which removed an older physical-register bias for live
range costs, and `0478de010ee4`, which ordered call arguments. That history
supports explicitly reviewing spill costs when adding another preference.
The [related PR search](validation/runs/carry-0064-upstream/audit/related-prs.json)
found the old 65816 REP/SEP PR, not an existing repair of this computed-carry
heuristic. The exact destination source and tests remain the decisive evidence.

The original grouped shift/add MIR already passes on this upstream baseline,
including after an explicit unpatched rebuild. That is **not reproduced on
this build**, not closure of the downstream report. The extracted regression
starts with a valid interleaving of the same operations. Default and bottom-up
scheduling retain overlapping flags on the baseline; the candidate separates
the chains. Top-down is an existing passing control. This is a deliberately
constructed pass input, not a claim that current upstream C lowering naturally
produces that order. Existing MOS tests did not cover this scheduling contract.

## Contract review

- Every selected instruction still comes from the scheduler's legal ready
  queues. No dependence is removed or added; required overlap remains possible.
- The model records a defining node and distinct users. Two-address reuse of
  one virtual register does not combine successive carry values. Multiple users
  keep a value live until the last consumer crosses the relevant boundary.
- Top pressure covers definitions already selected at the top with outstanding
  users. Bottom pressure covers selected users whose definition has not been
  selected at the bottom. Initialization clears all state for each region.
- Only virtual registers of exactly `Cc` class are modeled. Physical live-ins,
  broader register classes and cross-region information without DAG data edges
  remain outside the added cost. This limits optimization coverage, while the
  existing DAG and allocator retain correctness responsibility.
- `LDImm1` is excluded because CLC/SEC can rematerialize constant flags. Dead
  carries with no users add no pressure. The cost is the change in
  `max(0, live carries - 1)`, not an unconditional ban on starting a carry.
- Equal costs fall through to the existing preferences. The added per-region
  storage and user scans have not been benchmarked; high fan-out can increase
  candidate evaluation work. No low-overhead assertion is justified yet.

The upstream patch retains the implementation from downstream 0064. Extraction
changes the regression's initial order and addresses, adds a multiple-user
control, and replaces native-width RUNs with ordinary-MOS coverage. Native
features, ABI changes, platform configuration and generic TableGen code are
absent. Full verification is linked in the [validation record](0064-validation.md).

## Profitability decision

The exact upstream interleaved MIR improves **133 → 59 bytes**, with six carry
materializations removed. All **117** ordinary-MOS corpus comparisons are
byte-identical. These establish a targeted improvement and neutral controls;
they do not establish widespread upstream application gains.

The earlier downstream census remains separately identified in the
[plan](../../plans/2026-09-26-mos-carry-scheduling.md#8-completed-validation-and-packaging) and
[32-case disassembly review](../../defects/evidence/2026-09-26-mos-carry-scheduling/growth-review.json).
Reassessment of its costs:

| Retained loss | Assessment |
|---|---|
| L-system corpus, up to +41 bytes / 2.04% | Changed frame allocation introduces indirect frame traffic in the turtle loop, despite two fewer REP/SEP instructions. Highest priority for a future cycle measurement. |
| `rcundef2`, up to +17 bytes | Scratch/static-stack routing changes; the largest configuration uses an extra stack byte. |
| Spirograph HUD, +11/+15 bytes | Earlier offset computations add zero-page saves/reloads; XY16 adds one mode transition. Other function sizes are unchanged. |
| Avalanche, up to +11 bytes | Palette setup shifts/reloads grow; core calculation, tick and blit function sizes are unchanged. |
| L-system renderer +5–9; DCT bloom +4 bytes | Extra transfers around arithmetic/lookup or before the fill loops. |
| Three corpus cases, +1 byte each | An earlier high-byte load uses X/Y followed by a transfer to A. |

Keep these bounded losses visible and accept them in the local PR proposal
alongside the measured aggregate gains. Moving the carry preference after the
physical-register heuristics did not improve the nine growing Os/Oz sources in
the recorded experiment. Broader TableGen candidates had substantially more
regressions and remain rejected. This assessment does not infer execution time
from byte counts or approve those candidates.

## Disposition

The standalone patch and PR text are ready for upstream review on the recorded
base. At completion of this review, no push or PR creation had occurred. Recheck the destination before posting
if it moves. Independent review has not been performed in this preparation.
The canonical record remains **workaround**: generic pressure repair, farblit,
and all-XY16 diagnosis retain their separate scopes. Cycle and compiler-time
measurements are prerequisites for corresponding performance claims.

## Publication update

Compiler commit `155e209c4cee` is now [pushed to the fork branch](https://github.com/wbniv/llvm-mos/tree/mos-computed-carry-scheduling).
No PR has been opened; the review and measurement limits above still apply.
Publication: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.
