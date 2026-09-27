# Competing-carry scheduler gate

**Result:** the gate is implemented and measured, but **rejected as the default**.
It recovers the 32 original growing configurations and preserves the targeted
sum/rotate speedups. Across the full census it gives up **6.81%** of the existing
aggregate size saving, exceeding the plan’s 5% limit. Four configurations also
grow without removing a carry materialization. Patch
[0067](../../patches/llvm-mos/0067-mos-competing-carry-gate.patch) therefore keeps
`always` as the default and exposes `gated` for explicit experiments.

This completes the implementation and evaluation in the
[competing-carry plan](../plans/2026-09-27-0064-competing-carry-gate.md), with default
promotion declined. The canonical
[carry-pressure record](../defects/mos-carry-scheduling-pressure.json) remains a
workaround for the generic TableGen pressure-set defect.

Implementation, measurements and documentation: OpenAI Codex CLI 0.157.1
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0e126-2178-79f3-adba-51b951fb1f96`.

## Why the gate removes the incidental regressions

The 6502 and 65816 have one carry flag. When two computed carry values must stay
live at once, one may need to be materialized as a byte and later restored.
The three-instruction materialization in the preserved 8-bit controls occupies
six bytes (2 + 2 + 2); the original plan’s five-byte note was incorrect.
Patch 0064 gives the scheduler an extra preference for avoiding that overlap.
Its original model excludes `LDImm1`, but also counts `LDCImm` constants,
provisional frame-address carries and carries with users outside the scheduling
region. Those values do not establish that changing the local order will avoid
an expensive carry save.

This distinction matters because instruction order affects register allocation.
A schedule chosen to reduce the modeled carry pressure can require more register
moves, zero-page saves/reloads, frame space or accumulator/index-width changes.
The retained disassembly shows that none of the 32 growing configurations removes
a carry materialization in its growing function. Their combined 208-byte cost
therefore has no compensating reduction in these carry-save sequences.

The experimental `gated` policy restricts both the values being tracked and the regions
where the extra preference applies:

- Exclude `LDImm1` and `LDCImm`: their carry constants can be rematerialized with
  `CLC` or `SEC`.
- Exclude `AddrLostk` and `AddrHistk`: frame layout can turn these pseudos into
  copies or constant carry loads. Their provisional carry is not enough evidence
  of an expensive computed value.
- Exclude values with a scheduling-boundary user: their complete lifetime is not
  represented by the local scheduling region.
- Require two remaining computed carry values whose lifetimes can overlap under
  the dependency graph. If every use of one must precede the other's definition,
  that pair does not compete. A use at the next definition ends the first range.

When no eligible pair competes, the extra carry preference is skipped and the
ordinary MOS pressure heuristics choose the order. Across the 32 original growing
configurations, the gated object disassembly matches `off` exactly. This explains
why the HUD and DCT instruction costs disappear: the gate avoids the incidental
schedule changes that introduced them. The runtime measurements separately check
that recovery; matching byte size alone would not establish equal execution time.

This is a conservative heuristic, not a proof that every activated region gets
smaller or faster. Farblit XY16 O2 removes 22 carry materializations, so the gate
still activates. Its other allocation and instruction costs outweigh that saving:
45 extra bytes and 298,012 → 300,276 master clocks, a 0.76% slowdown in the measured
`main` interval. The corpus acceptance rule explicitly allows listed size growth
with removed carries as justification; the stronger zero-cycle-regression rule
remains unmet. The other failures below prevent default promotion even under
the plan’s more permissive size rule.

## Comparison scope

`off`, `always` and `gated` are selected with `-mos-carry-sched` in one identified
compiler build. `always` retains the original 0064 policy. All other compiler
changes, linker inputs and runtime drivers are held fixed within each comparison.
The current stack includes the separate 0065 profitability and 0066 far-load
legalization repairs. Earlier preserved-build timing remains dated evidence in
[the original timing report](2026-09-27-mos-carry-timing.md).

The census covers Os/Oz/O2 in default, A16 and XY16 modes, plus the ordinary-6502
adapted fixtures. Cycle measurements use the calibrated bsnes-jg probe and repeat
each run twice while checking the result oracle. The original sum/rotate functions
retain the common A16 driver used in the earlier report. Compiler wall-clock
measurements use a separate sequential run; concurrent census durations are not
a compile-time benchmark.

## Code size and acceptance

The [census](../defects/evidence/2026-09-27-competing-carry-gate/census-summary.json)
contains **3,720 configurations**: 409 sources × Os/Oz/O2 × default/A16/XY16, plus
13 adapted ordinary-6502 inputs × three optimization levels. All three arms
compile successfully in **3,592** configurations. The other **128** reject in all
three arms; there are **zero policy-specific compile failures**. O2 now covers
all 409 sources, expanding the original 252-source O2 sweep.

| Policy | Aggregate text change versus `off` |
| --- | ---: |
| `always` | −213,866 B |
| `gated` | −199,309 B |
| Saving relinquished by the gate | 14,557 B (6.81%) |

These are sums across configurations, not one ROM’s size. The original 32-case
archive contains 208 bytes of growth; the current combined stack has 194 bytes
of growth on those same configurations. `gated` matches `off` disassembly exactly
for all 32. The four preserved sequence-count controls match 17/18 and 12/12
materializations/`CMP #1` candidates before 0064, and 0/0 afterward. A `CMP #1`
count alone does not prove that an instruction restores a saved carry.

The original C controls retain sum 409 → 248 B and rotate 385 → 285 B in A16 and
XY16, with zero materializations under `gated`. The retained upstream kernel MIR,
compiled on the current downstream stack, is 115 → 51 B, also with zero saves.
Its earlier 133 → 59 B result belongs to the earlier upstream build.

### Remaining growth under `gated`

| Input | Mode / opt | Bytes | Carry materializations | `off` → `gated` master clocks |
| --- | --- | ---: | --- | ---: |
| `matcascade_sim` (`mat_mul`) | default / O2 | +4 | 2 → 2 | 6,015,932 → 6,019,372 |
| `farblit` (`main`) | xy16 / O2 | +45 | 27 → 5 | 298,012 → 300,276 |
| `avalanche` (`main`) | default / Os | +1 | 1 → 0 | 194,399,540 → 194,399,582 |
| `matcascade_sim` (`mat_mul`) | default / Os | +4 | 2 → 2 | 6,015,316 → 6,018,796 |
| `avalanche` (`main`) | default / Oz | +1 | 1 → 1 | 195,115,060 → 195,115,058 |
| `matcascade_sim` (`mat_mul`) | default / Oz | +4 | 2 → 2 | 6,032,318 → 6,035,758 |

`matcascade_sim` grows four bytes at each optimization level, with two
materializations in `mat_mul` in every arm. Its `main` also forfeits the 64-byte
saving and eight removed materializations achieved by `always`. Avalanche `-Oz`
grows one byte without removing a materialization. Thus **four of the six growing
configurations fail the plan’s justification rule**. The tiny Avalanche timing
deltas include layout/refresh effects and are not isolated hashing benchmarks.
The matcascade intervals cover `main` through the oracle store.

### Refinements tested and rejected

The initial constant-only exclusion recovered HUD/DCT growth but left 22 original
regressions. Excluding provisional frame values and boundary users recovered all
32, producing the experimental policy retained here. Additional trials compared
the 32 controls and the largest lost wins:

- Allow arithmetic carries with boundary uses: recovered no bytes in the 100
  selected lost-win configurations.
- Use local carries only to activate the gate, then track provisional/boundary
  values too: recovered 5,939 bytes in that sample, but restored 20 original
  regressions.
- Allow all boundary carries while excluding frame pseudos: recovered 796 bytes
  but restored 14 original regressions.
- Track constants only after computed carries activate the gate: recovered only
  61 bytes in the expanded sample.
- Require a competing pair to be serializable in at least one direction, excluding
  forced overlap: changed none of the sampled results. Combining this with the
  conditional constant tracking still recovered only 61 bytes.

These are sample totals, not full-census estimates. None resolves the acceptance
failures. Provisional frame carries can be expensive after layout, so excluding
them also loses real carry-save reductions elsewhere. The initial hypothesis is
supported for the 32 historical growth cases but is insufficient as a general
profitability rule. The experimental option remains available; a default change
needs a better way to judge carry preservation and allocation costs.

## Execution-time measurements

All 34 comparisons from the earlier timing report were replayed with the current
stack and all three policies: **102 ROM/policy measurements, each run twice**.
The four sum/rotate cases retain the measured **30.45% / 17.61%** speedups.
For the 30 originally growing SNES cases, `gated` and `off` have **identical measured
clock counts**. The separate XY16 Oz interpreter interval also matches `off`.
These results establish recovery for those inputs, not universal non-regression.

| Scope | `off` | `always` | `gated` |
| --- | ---: | ---: | ---: |
| Sum, 24 calls, A16/XY16 | 106,784 | 74,264 | 74,264 |
| Rotate, 24 calls, A16/XY16 | 111,192 | 91,608 | 91,608 |
| First HUD update, A16 Os | 60,534 | 60,664 | 60,534 |
| First HUD update, XY16 Os | 60,414 | 60,598 | 60,414 |
| 128 DCT fill-cell calls, A16 Os | 20,670,778 | 20,678,780 | 20,670,778 |
| L-system interpreter, XY16 Oz | 17,336,362 | 17,109,190 | 17,336,362 |

Values are SNES master clocks. The current stack includes other compiler repairs,
so absolute values differ from the preserved September 26 build. In particular,
the current `always` interpreter is faster than current `off`; the earlier +2.80%
result remains valid for its frozen build pair. The interpreter entry marker is
verified at `main + 0x14f` in every arm. Original inputs, ROMs, raw profiles,
commands and identities are retained separately for both experiments.

The ordinary-6502 kernel runs the same 512 oracle vectors in every arm. Whole
program `mos-sim --cycles --profile` counts are **179,472 / 145,659 / 145,659** for
`off` / `always` / `gated`, repeated identically. These include the common driver,
startup and result checking; they are CPU cycles, not SNES master clocks. Timing
of the two adapted 6502 rotkal census inputs and the exact upstream compiler
extraction remains outside this result.

## Compile time

Six representative configurations were compiled sequentially after the census,
runtime and trial jobs finished, using the final compiler. Each arm/input has one
warmup and seven measured runs, rotating arm order by input and round. Both wall
time and child-process CPU time are retained. The shared host is an Intel
Core i7-1185G7 running Linux; this is a bounded overhead check, not a dedicated
benchmark machine.

| Input | Mode / opt | `off` median wall s | `always` | `gated` |
| --- | --- | ---: | ---: | ---: |
| `farblit` | xy16 / O2 | 0.1848 | 0.1897 | 0.1856 |
| `rcundef2` | xy16 / Os | 0.2181 | 0.2097 | 0.2067 |
| `lsystem_sim` | xy16 / Oz | 0.2148 | 0.2031 | 0.2199 |
| `dctbloom` | a16 / Os | 1.0053 | 0.9794 | 1.0117 |
| `avalanche` | default / Os | 0.5298 | 0.5616 | 0.5134 |
| `arith` | default / Os | 0.0468 | 0.0431 | 0.0401 |

The sum of the six medians is **2.1996 / 2.1867 / 2.1774 seconds**. The gated sum
is 1.01% below `off`; run ranges overlap in every configuration, so these samples
do not establish a compile-speed improvement. The corresponding CPU-time sums
are 2.1651 / 2.1552 / 2.1215 seconds. No large compile-time cost is apparent in this
sample; neither worst-case graph-query cost nor whole-project build time is bounded
by these measurements.

## Correctness, evidence and delivery

- Final CodeGen/MOS and MC/MOS suites: **181 pass, two unsupported**. The new MIR
  test covers constants, serial computed chains, a live-out carry and frame
  address pseudos in both scheduling directions and native mode; it also checks
  that the default equals `always`. The existing positive carry test also runs
  explicitly under `gated` in all six configurations.
- The counter’s four tests pass. All 32 `always` outputs match the preserved
  pre-gate compiler. After selecting the final default, 64 focused comparisons
  confirm that default and explicit `gated` match their frozen measured arms.
  The final scheduler source differs from the measured gate only in its default
  initializer; the experimental refinements are not in patch 0067.
- Runtime: **78 of 79 corpus cases and all 50 deterministic signed-32-bit fuzz
  seeds pass** across default/A16/XY16 MAME and A16 bsnes-jg, with machine-verifier
  checks. Ten initial short-window failures pass 40 rechecks on the exact same
  ROMs with the documented longer corpus window; both log sets are preserved.
- `vlastack_sim` XY16 returns `0xD3BD` instead of `0xD77B` on the preserved
  pre-gate compiler and all three policies, in both emulators. Default and A16
  return the oracle. This is an unresolved baseline observation, recorded under
  the canonical carry investigation until its mechanism is reconciled; it is
  not a gate-specific failure or a claimed repair.
- Patch 0067 applies to the preserved pre-gate scheduler and reproduces the final
  sources/test exactly. Both toolchain application and 0002 regeneration lists
  include it. The installed compiler is refreshed with `always` as default.

The [evidence receipt](../defects/evidence/2026-09-27-competing-carry-gate/receipt.json)
indexes compiler/source identities, the full census, source snapshots, original
and new growth counts, rejected trials, runtime failures and reruns, linked ROMs,
profiles, exact replay scripts and compile-time samples. Baseline files, earlier
credits and the withdrawn PR #609 packet remain intact. No independent review,
generic pressure-contract repair or upstream submission is claimed.
