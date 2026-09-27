# Gate 0064 to regions with competing carries

**Status (2026-09-27):** implementation and evaluation complete; **default promotion rejected**. Patch 0067 exposes `off`, `always` and experimental `gated`, with `always` retained as the default. The [report](../investigations/2026-09-27-competing-carry-gate.md) explains [why the gate removes the original incidental costs](../investigations/2026-09-27-competing-carry-gate.md#why-the-gate-removes-the-incidental-regressions), and why that is insufficient for general profitability.

The 3,720-configuration census has 3,592 successful three-way comparisons and zero policy-specific compile failures. The gate recovers all 32 original growing configurations and their measured timing costs, but relinquishes 6.81% of the existing aggregate size saving (limit: 5%) and leaves four growing configurations without fewer carry materializations. The 181 supported MOS tests pass. Runtime has one XY16 VLA mismatch reproduced on the preserved baseline and every policy; no gate-specific mismatch was found. Sequential compile-time measurements are recorded without a speed claim.

This finishes the proposed experiment with a rejected default change. The original plan below remains dated context, including its intended default and acceptance criteria. Further default promotion needs a better profitability model; PR #609 remains withdrawn.

Completion: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`.

**Earlier preserved-build measurement follow-up (2026-09-27):** the [preserved-build timing comparison](../investigations/2026-09-27-mos-carry-timing.md) measures 0064 execution time. Sum and rotate improve by 30.45% and 17.61%, while the XY16 Oz L-system interpreter regresses by 2.80%; smaller HUD and DCT costs are also retained. The original zero-cycle-regression criterion is not met. That report did not measure compiler overhead, ordinary-6502 timing or timing of the exact upstream extraction; the later gate report adds bounded current-stack compile-time and kernel timing. At the time of that measurement, the region-gate hypothesis below was untested; byte-size recovery alone would not establish that these execution-time regressions were resolved. The implementation report records the subsequent gated comparison.

The separate [farblit legalization repair](../investigations/2026-09-27-farblit-byte-load.md) is established by matching-input red/green evidence for patch 0066. Its aggregate opcode-count gate remains a separate follow-up. The original scope notes below describe the evidence available when this plan was written.

Follow-up and merge review: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`. The original plan and its attribution are retained below.

## Original plan — context

[Patch 0064](../../patches/llvm-mos/0064-mos-computed-carry-scheduling.patch) makes the MOS
pre-RA scheduler count live computed carry (`Cc`) values and prefer orders that keep at most
one alive. The 65816 and 6502 have a single carry flag, so a second live carry is saved to a
register (`ldy #1 / bcs +2 / ldy #0`, 5 B) and restored (`cpy #1`, 2 B). 0064 removed every
save on the recovered inputs: sum 409 → 248 B, rotate 385 → 285 B, targeted kernel 133 → 59 B
([completion plan](2026-09-26-mos-carry-scheduling.md#selected-policy-and-rejected-candidates)).

The corpus improves by about 200 KB in aggregate across Os/Oz/O2 and the three code modes.
But **32 configurations grow**, 208 B in total, across nine source families. The worst is
`lsystem_sim` at 41 B (Oz xy16). The [growth review](../defects/evidence/2026-09-26-mos-carry-scheduling/growth-review.json)
records each one with function deltas and archived before/after disassembly.

Every recorded explanation is downstream of the schedule, not the carry decision itself:
"changes scratch allocation", "saves/reloads through ZP", "different frame allocation". The
scheduler cannot see those costs when it picks an order. One gate was already tried: ranking
the carry cost after the physical-register costs. It changed nothing; all nine growing
sources compiled byte-identical.

The project's governing lesson 2 applies: a new form should fire only where it wins, and a
misclassification must only miss a win, never cause a regression. 0064 currently fires in
every scheduling region.

## Approach

**Hypothesis.** The growing functions are ones where 0064 reordered instructions without
removing any carry save. If so, a region-level gate that leaves non-competing regions on the
original order recovers the 208 B and keeps the wins.

### Phase 1 — measure from retained evidence (no compiler build)

1. Write `dev/count-carry-saves.py`. It counts, per function in a disassembly listing, carry
   materializations (`ld[xy] #1 / bcs / ld[xy] #0` and the accumulator form) and restores
   (`cp[xy] #1`, `cmp #1` after a materialization).
2. Validate the counter on the reduced shapes before trusting it. The retained
   [sequence counts](../defects/evidence/2026-09-26-mos-carry-scheduling/carry-sequence-counts.json)
   give the expected values: baseline sum 17 materializations / 18 restores, rotate 12 / 12;
   0064 zero for both.
3. Unpack `growth-disassembly.tar.gz` from the same evidence directory. For every growing
   function in all 32 configurations, count saves before and after 0064.
4. Decide from the table:

| Phase 1 result | Next step |
|---|---|
| No growing function lost a carry save | Build the region gate (Phase 2). |
| Some growing functions did lose saves | The gate cannot help those. Record which, then choose between accepting them and the per-function fallback below. |
| The counter cannot be validated | Stop and fix the counter; do not guess. |

### Phase 2 — the region gate

In `MOSSchedStrategy` (`vendor/llvm-mos/llvm/lib/Target/MOS/MOSMachineScheduler.{cpp,h}`):

- Compute a **carry-competition predicate** once per scheduling region. It is true when the
  region contains at least two computed, non-`LDImm1` `Cc` values whose def-to-use spans can
  overlap under the DAG. The existing 0064 value tracking already identifies these values by
  defining node.
- When the predicate is false, skip the computed-carry term entirely. The region then
  schedules exactly as it did before 0064.
- Add `-mos-carry-sched={off,gated,always}` (default `gated`) so each arm can be measured from
  one compiler build.

The gate must be conservative: on any doubt, report "no competition". A wrong "false" only
forgoes a win.

### Phase 3 — corpus rerun

Reuse the 0064 census (`dev/measure-carry-scheduling.py`): Os/Oz/O2 × default/a16/xy16 plus
the 13 ordinary 6502 fixtures. Compare three arms, `off`, `always` and `gated`, and record
per-configuration and per-function deltas.

**Rejected as the primary approach:** compiling each function twice and keeping the smaller.
It guarantees no per-function growth, but it roughly doubles back-end compile time, does not
fit LLVM's pass pipeline, and could never go upstream. It stays as the downstream fallback
from Phase 1.

This change has no visible surface (scheduler heuristic, measurement script), so there are
no mockups.

## Original scope notes (before the measurement follow-up)

- The generic TableGen fine-grained pressure-set contract. It stays its own T4 item and
  [defect record](../defects/mos-carry-scheduling-pressure.json).
- Hot-loop cycle and compile-time measurement of 0064 itself. It is still unmeasured, but it
  is a separate question from byte growth.
- The combined-stack farblit byte-load legalization failure.
- Re-posting upstream (PR #609 is withdrawn; any revision is user-triggered).

## Verification

1. The counter reproduces the retained reduced-shape counts exactly: baseline sum 17 / 18,
   rotate 12 / 12; 0064 sum 0 / 0, rotate 0 / 0.
2. Phase 1 produces a per-function table for all 32 growing configurations, committed next to
   the growth review.
3. With `gated`, every function whose regions all evaluate the predicate false is
   byte-identical to `off`.
4. The recovered inputs keep their wins under `gated`: sum ≤ 248 B, rotate ≤ 285 B, kernel
   ≤ 59 B, all with zero carry saves.
5. Corpus: no configuration grows versus `off` under `gated`, or each remaining growth is
   listed with its removed carry saves as justification. The aggregate win stays within
   5 % of `always`.
6. The differential holds on the corpus: host == default@MAME == a16@MAME == a16@bsnes-jg,
   `-verify-machineinstrs` clean, and the MOS lit suite passes.
7. `carry-pressure-schedule.mir` passes, plus a new MIR test for a non-competing region that
   checks the `off` order is kept.

Plan: Claude Code 2.1.280 using Claude Opus 5.5 (`claude-opus-5-5`), medium reasoning effort;
session `65695418-7e9b-45bd-92e3-2ecfd88ecf0b`. 0064 implementation and evidence: OpenAI Codex
CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort, as recorded in the
[defect record](../defects/mos-carry-scheduling-pressure.json).
