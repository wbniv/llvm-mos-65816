# MOS carry-chain scheduling: diagnosis, optimization, and acceptance plan

**Date:** 2026-09-26. **Priority:** T4; selected as the next optimization.
**Status:** implemented and validated locally as patch **0064**.
The carry-saving optimization is complete; the generic TableGen pressure-contract
defect remains a qualified workaround. Results and remaining work are in §7–§9.
**Objective:** reduce avoidable carry materialization caused by pre-register-
allocation scheduling, with a demonstrated code-size benefit and preserved
runtime behavior across the MOS corpus.

Planning, implementation, measurement, and completion update: OpenAI Codex CLI 0.157.1 (`codex-tui`),
model `gpt-6-astra`, `xhigh` reasoning effort; verified from session
`01a0dd01-d72e-76f2-bf27-a796e0f7d994` metadata. The earlier measurements retain
the attribution recorded in their source documents.

Sections 1–5 retain the original September 26 execution plan and its acceptance
criteria. Section 7 records what was actually implemented, including deviations
and the explicitly accepted size tradeoffs.

## 1. Evidence and intended scope

The original report is the [three-access cliff in the increment 1 plan](2026-09-25-dpy-indexed-phase2-increment1.md#the-three-access-cliff--a-separate-reproducible-defect).
Its September 25 measurements were:

| Shape | Before increment 1, scheduler on/off | After increment 1, scheduler on/off |
|---|---:|---:|
| Three-access sum | 397 / 369 B | 410 / 290 B |
| Three-access rotate | 412 / 426 B | 420 / 340 B |

The report attributes the growth to interleaving a 32-bit scaling shift with a
32-bit pointer add. Two carry values become live together despite one physical
carry flag. Saving and restoring carry introduces branches, byte-register
temporaries, and comparisons. Disabling the post-RA scheduler did not change
the reported output.

These are historical measurements, not a current baseline or a promised
120-byte saving. Scheduling off is a diagnostic control. Success requires an
identified scheduling change with normal scheduling enabled.

Runtime `[dp],Y` increment 2 is already published in downstream commit
`a4eb416c`, with [verification recorded in its plan](https://github.com/wbniv/llvm-mos-65816/blob/a4eb416c/docs/plans/2026-09-25-dpy-indexed-phase2-increment2.md).
The implementation baseline must also include the reviewed local 0061/0062/0063
optimizations. Their effect on the original trigger must be measured before
choosing a repair. Preserve narrow-add wrapping, scaled-index range checks,
memory ordering, and M/X mode transitions throughout.

## 2. Prior-work reconciliation

Read-only reconciliation for this plan covered the original report, TODO M2,
the dashboard's `opt:carry-scheduler` item, structured defect records, patch
bundles, Git history, and the live MOS scheduler and register definitions.
Searches included carry/scheduler/pressure combinations and
`MOSSchedStrategy`, `registerClassPressureDiff`, `Cc`, `RegPressure`, and
`overrideSchedPolicy`.

- No existing canonical carry-scheduling record or standalone carry-scheduling
  repair was found. Preserve the original report as the discovery entry point.
- `MOSMachineScheduler.cpp` and `MOSSubtarget.cpp` match the vendored pin
  `8be0546128a55e78c63ca571d466aa72a782cd36`; neither has a local working diff.
  The native-width register definitions do have downstream changes. The
  checkout and build scripts contain unrelated pending edits, so the current
  executable cannot be treated as a reproducible baseline from HEAD alone.
- `MOSSubtarget::overrideSchedPolicy` already enables pressure tracking and
  allows both scheduling directions. Turning pressure tracking on is therefore
  not an implementation proposal.
- `MOSSchedStrategy::tryCandidate` ranks physical `Ac`, `XY`, and `Imag8`
  pressure changes before generic excess/critical/maximum-pressure checks.
  `registerClassPressureDiff` explicitly ignores virtual registers. Whether this
  ordering hides virtual carry pressure on the trigger remains a hypothesis.
- `Cc` is a fine-grained, single-register class, while `CV_GPR_LSB` includes
  carry, overflow, and byte-register alternatives. Inspect the actual assigned
  virtual classes and generated pressure sets before changing their costs.
- The existing native-shift carry-clobber repair (`Defs = [C]` on
  `ASLAcc16`/`LSRAcc16`) protects correctness. It is a distinct mechanism from
  avoidable carry overlap. Preserve it and its CRC/shift controls. Likewise,
  two-address rescheduling fix 0029 is a separate pass and contract.

Before compiler edits, retain this audit's exact searches/results and migrate
the historical report into its first structured record, provisionally
`docs/defects/mos-carry-scheduling-pressure.json`. Use
`prior_work.disposition = historical_migration`, explain the distinctions above,
and follow the [defect evidence workflow](../howto-defect-evidence.md).
Record creation follows baseline recovery; this plan makes no new confirmed
failure or resolution claim. If another record is found, extend that record.

## 3. Execution sequence

### A. Reconstruct and freeze the baseline

1. Create an isolated compiler worktree under `.scratch/carry-scheduling` using
   the [compiler-changing worktree recipe](../howto-feature-worktree.md).
   Give rebuilt sources and tools independent writable copies. Record the
   parent revision, vendor pin, complete ordered patch hashes, selected local
   overlays, SDK revision, and container identity. Reconcile increment 2 and
   0061–0063 explicitly; do not infer their presence from a binary timestamp.
2. Recover the exact sum and rotate inputs and their commands from the original
   worktree, saved session artifacts, and Git history. Keep
   `examples/65816/farindex.c` as an integration witness. If an original reduced
   input is missing, label its replacement reconstructed and retain the gap.
3. Preserve baseline Clang, llc, linker, resource headers, input/header hashes,
   preprocessed C, IR, and MIR immediately before/after machine scheduling and
   register allocation. Record the pass pipeline and verify the retained MIR
   replays at the intended boundary. Preserve object disassembly, function text
   sizes, commands, diagnostics, and exit statuses.
4. Re-measure identical inputs at `-Os` with the pre-RA scheduler on/off, holding
   post-RA scheduling fixed. Repeat the post-RA-only diagnostic. Cover default,
   a16, and xy16 where supported. Compare the historical configuration and the
   reconciled current stack without conflating them.
5. Establish a reproducible regression check for excess carry materialization
   and code size. Its failure must describe the recorded performance condition;
   compilation success is not that check. Freeze the baseline artifacts before
   candidate work. A current pass means not reproduced on that build; investigate
   which intervening change removed the trigger before claiming closure.

### B. Identify the scheduling decision

Trace both scheduling boundaries on the reduced MIR. Record ready candidates,
their chosen reasons, virtual carry live ranges, register classes, pressure-set
limits/deltas, and competing A/X/Y/Imag pressure. Use an assertions-enabled build
with local diagnostics when the installed build cannot expose this information.

Locate the first choice that makes independent carries overlap. Follow those
values through allocation and expansion to the final save/restore instructions.
Establish whether the problem is an absent pressure set, an inaccurate limit or
weight, an early physical-register preference, or a later allocation decision.
Count actual carry-preservation sequences; unrelated `bcs`, `ldy`, or `cpy`
instructions are not evidence of a carry spill by themselves.

### C. Compare small candidate changes

Test one explanation at a time, against the same frozen baseline:

1. Correct a demonstrated pressure-model error if the generated model fails to
   represent the carry resource accurately.
2. If the model is correct, prefer candidates that avoid exceeding carry
   capacity before applying the physical-register heuristics that caused the
   overlap. Use live pressure and virtual register classes, not a count of
   physical C operands. Account for both top-down and bottom-up scheduling.
3. If those approaches lose elsewhere, evaluate a narrowly justified preference
   for completing an existing carry chain. Retain legal DAG dependencies and
   permit genuinely necessary overlapping live values. Global serialization or
   a blanket scheduler disable is not an acceptable release change.

The first prototype belongs in `MOSMachineScheduler.{cpp,h}`; change
`MOSRegisterInfo` or subtarget policy only when the trace demonstrates a need.
Measure A/A16, X/Y, and imaginary-register pressure as well as carry: exchanging
carry saves for larger spills or extra REP/SEP transitions is not a win.
Preserve deterministic tie-breaking and check repeated builds of changed cases.
Decide whether to gate on native features from observed scope and regressions.
A change affecting ordinary MOS code requires ordinary MOS coverage.

## 4. Verification and measurements

| Layer | Required evidence |
|---|---|
| Scheduling regression | Small replayable MIR with competing shift/add carries, plus single-chain and necessary-overlap controls. Check the contract and final preservation cost, allowing equivalent schedules. |
| C integration | Recovered sum/rotate inputs and `farindex`; stress 16/32/64-bit carry chains, carry-consuming branches, native shifts, high register pressure, calls, volatile accesses, and inline-assembly clobbers. |
| Feature compatibility | Current runtime `[dp],Y`, global `long,X`, native far words, and near-store controls remain selected where expected. Preserve wrapping and bank-crossing inputs. |
| Static corpus | All compilable C inputs in `examples/65816`, `examples/snes/corpus`, and `examples/snes`, with the required generated assets; machine verification, default/a16/xy16, `-Os` and `-Oz`, no LTO. Repeat changed and carry-heavy cases at `-O2`. Include a representative ordinary 6502 near-code set if its scheduling changes. |
| Runtime | Host/MAME/bsnes checks for `farindex`, `farblit`, `farbank`, BankWalk, both near-store gates, CRC and carry-heavy kernels; full native corpus and 50 fixed fuzz seeds. Retain actual failures and classify skips. |
| Backend and packaging | Full MOS lit with an exact-baseline failure comparison; assembly round trips; patch-stack round trip; rebuild and identify the candidate tools used for each result. |

Extend the existing [size census runner](../../dev/measure-near-store.py) or use
its corpus/SDK discovery for `dev/measure-carry-scheduling.py`. Retain per-file
and per-function bytes, changed disassembly, spill counts, REP/SEP counts, and
errors. Summarize wins, losses, unchanged cases, total delta, and worst regression
for each mode and optimization level. Unsupported inputs and new compile failures
must remain visible in the report.

Use non-LTO runs to keep the backend trigger observable. Also build and execute
representative affected demos with their normal LTO settings. Cycle claims need
explicitly identified static estimates or reproducible emulator instrumentation;
ROM size, instruction counts, and frame counts alone do not establish a speedup.
Published [BankWalk](https://biohack.net/snes/bankwalk/) and
[Dual-LFSR](https://biohack.net/snes/lfsr2/) demos are relevant integration
customers; their existing publication is not evidence for the candidate build.

## 5. Acceptance and disposition

- The preserved regression input fails its recorded performance check on the
  baseline and passes with an identified change, with scheduling enabled and a
  causal trace linking scheduling to reduced carry-preservation work.
- The original sum and rotate cases improve or, if no longer reproducible,
  receive an evidence-backed current disposition without erasing old results.
  The 290/340 B historical scheduler-off results are reference points, not
  hardcoded current acceptance thresholds.
- Aggregate text size improves in the affected native modes. Every individual
  growth is inspected; the default acceptance target is zero unexplained size
  regressions and zero regressions in measured hot-loop cycles. An aggregate win
  does not by itself excuse a material loss. Tighten the rule or reject it if
  that condition cannot be met.
- Machine verification and runtime checks introduce no new failures. Reproduce
  existing full-suite failures on the identified baseline. Preserve required
  carry/overflow/processor-status dependencies, alias ordering, and mode rules.
- Retain source, preprocessed input, IR/MIR, tools, logs, and the regression
  artifact in the canonical record. Mark fixed only with matching-input evidence.
  Update the original increment 1 report, TODO M2, dashboard item, handoff, and
  dependent summaries with the result and exact attribution.
- Package a scoped compiler patch and prove its application and regeneration.
  Before any upstream submission, inspect the exact destination scheduler,
  callers, tests, and history. Submission readiness depends on whether the final
  implementation requires #320/#321; SNES platform code remains on its separate
  submission track.

If the candidates only shift costs or require broad changes without a measured
benefit, record that result and retain the open performance report. Broader lane
lowering and near-Y correctness work have their own scope and evidence.

## 6. Progress

- [x] Reconcile the original report and inspect the live scheduling policy.
- [x] Write the implementation and acceptance plan.
- [x] Recover inputs, reconstruct tools, and freeze a reproducible baseline.
- [x] Create or update the canonical evidence record and preserve `prior_work`.
- [x] Trace the responsible scheduling choice and compare candidate policies.
- [x] Complete focused, corpus, runtime, and packaging checks.
- [x] Record the disposition and refresh all affected documents and views.

## 7. Implementation and measured outcome

### Baseline and causal evidence

The isolated compiler lives in `.scratch/carry-scheduling` on
`wt/321-carry-scheduling`, based on downstream `c8a1403d`. Vendor pin:
`8be0546128a55e78c63ca571d466aa72a782cd36`. Its independently writable source
includes runtime `[dp],Y` increment 2 and patches 0049–0063. The captured
[identity](../defects/evidence/2026-09-26-mos-carry-scheduling/baseline-identity.json),
[source diff](../defects/evidence/2026-09-26-mos-carry-scheduling/baseline-source.diff.txt),
[untracked source archive](../defects/evidence/2026-09-26-mos-carry-scheduling/baseline-untracked-source.tar.gz),
and [overlay inventory](../defects/evidence/2026-09-26-mos-carry-scheduling/baseline-overlay.txt)
identify the reconstruction. Baseline tools and resource headers are preserved
independently in `build/carry-baseline-install`; candidate tools are in this
worktree's `build/llvm-mos-install`. Main's installed compiler was not replaced.

The original `p_sum.c` and `p_rot.c` were recovered byte-for-byte from the
September 25 session artifacts. Original discovery credit: **Claude Code
2.1.278, model `claude-opus-5`, high reasoning effort**, session
`65695418-7e9b-45bd-92e3-2ecfd88ecf0b`, agent `a35017d73ff4d881d`.
The original September 25 binary was unavailable; its old byte counts remain
historical evidence. All numbers below use the identified reconstruction.

| Original function, `-Os`, no LTO | Baseline scheduler on | Baseline scheduler off | 0064 scheduler on | 0064 scheduler off |
|---|---:|---:|---:|---:|
| Three-access sum | 409 B | 289 B | **248 B** | 289 B |
| Three-access rotate | 385 B | 313 B | **285 B** | 313 B |

A16 and XY16 give the same function sizes. Disabling only post-RA scheduling
leaves the baseline unchanged. Default 8-bit mode cannot legalize these far
32-bit-index inputs; those failures are retained, not counted as scheduling
passes. The sum's carry materializations fall **17 → 0**, and its compare-#1
restores **18 → 0**; rotate falls **12 → 0** for both. REP/SEP counts stay at
6 and 8 respectively. [Exact runs](../defects/evidence/2026-09-26-mos-carry-scheduling/dynamic-runs.json)
and [sequence counts](../defects/evidence/2026-09-26-mos-carry-scheduling/carry-sequence-counts.json)
retain the disassembly evidence.

MIR before/after scheduling exposes the interleaved ASL/ROL and ADC carry
values. Generated register information confirms that TableGen reads
`IsPressureFineGrained` but does not propagate it to initial register-unit
sets, allowing the carry subset to be pruned. This diagnosis used source,
generated tables, and replayable MIR on a Release build with assertions off;
an assertions-enabled candidate-reason trace was not produced.

### Selected policy and rejected candidates

[Patch 0064](../../patches/llvm-mos/0064-mos-computed-carry-scheduling.patch)
changes `MOSMachineScheduler.{cpp,h}` and adds
`CodeGen/MOS/carry-pressure-schedule.mir`:

- Track each computed virtual `Cc` value by its defining scheduling node and
  data-dependency users. Two-address chains can redefine one virtual register,
  so a register ID alone does not identify the value.
- Maintain live counts across both scheduling boundaries. Compare the change
  in excess above one live computed carry before the physical-register costs.
- Exclude `LDImm1` constants: CLC/SEC can rematerialize them. Update only values
  referenced by the candidate node.
- Preserve the legal DAG and normal tie-breaking after equal costs. Necessary
  carry overlap remains legal. Physical carry values entering a region are
  outside this additional model.

The implementation applies to ordinary MOS as well as native-width modes.
It has no native opcode or SNES platform dependency; native-width test RUNs
belong to the downstream coverage. Upstream extraction still needs an exact
current destination audit and review.

| Candidate | Decision and evidence |
|---|---|
| Restore all fine-grained TableGen pressure sets | Rejected: native `-Os` aggregate **+40,483 B**, 214 growing files, and five additional lit failures. |
| Restore only the carry set | Rejected: native aggregate −2,400 B but 144 growing files, including `a16mixfold` 59 → 196 B and `a16thread` 53 → 110 B. |
| Count computed carries at the scheduling boundaries | Selected: removes the original materializations and improves all measured corpus totals. |
| Put computed-carry cost after physical-register heuristics | No improvement: all nine Os/Oz growing sources were byte-identical across three modes and both optimization levels. |

The [canonical record](../defects/mos-carry-scheduling-pressure.json) is
**workaround**, because its frozen TableGen contract test still fails with the
selected compiler. The scheduler regression has separate matching-input
[red/green evidence](../defects/evidence/2026-09-26-mos-carry-scheduling/scheduler-red-green.json).
The broader pressure-model failure is not marked fixed.

### Corpus results and accepted costs

[The census runner](../../dev/measure-carry-scheduling.py) compiles all 409 C
sources in the three planned directories with the same SDK/assets, machine
verification, and no LTO. Pairs count inputs that compile on both tools.
There are **zero unmatched compilation outcomes** in every row; other inputs
fail on both tools and remain in the retained reports.

| Optimization | Mode | Paired / inputs | Smaller | Larger | Aggregate text delta |
|---|---|---:|---:|---:|---:|
| Os | default | 372 / 409 | 220 | 2 | −43,332 B |
| Os | a16 | 408 / 409 | 64 | 6 | −8,088 B |
| Os | xy16 | 408 / 409 | 62 | 6 | −8,059 B |
| Oz | default | 372 / 409 | 226 | 3 | −46,317 B |
| Oz | a16 | 404 / 409 | 66 | 2 | −7,190 B |
| Oz | xy16 | 404 / 409 | 63 | 4 | −7,090 B |
| O2, union of changed inputs | default | 240 / 252 | 218 | 1 | −50,731 B |
| O2, union of changed inputs | a16 | 250 / 252 | 72 | 3 | −14,386 B |
| O2, union of changed inputs | xy16 | 248 / 252 | 71 | 3 | −13,921 B |

Thirteen ordinary NMOS 6502 fixtures were adapted only by replacing their
terminal SNES `wai` with an empty volatile asm; all 13 compile on both tools.
Os/Oz/O2 totals improve by **970/996/941 B**. One fixture grows 1 B at Os/Oz;
none grow at O2. Adapted inputs and the initial unsupported-WAI attempts are
retained separately.

[All 32 growing configurations](../defects/evidence/2026-09-26-mos-carry-scheduling/growth-review.json)
are enumerated with function deltas and archived disassembly. Nine unique
Os/Oz sources grow:

| Source family | Largest growth | Inspected cost |
|---|---:|---|
| `lsystem_sim` | 41 B (Oz xy16, 2.04%) | Different frame allocation adds indirect frame traffic in the turtle loop; two fewer REP/SEP instructions. Os/O2 increases are 5–8 B. |
| `rcundef2` | 17 B | ASR/rotate ordering changes scratch allocation and, at Oz xy16, static-stack spill routing. Os/O2 increases are 3 B. |
| `spirograph` | 15 B | Earlier HUD offset computation adds ZP saves/reloads; xy16 adds one mode-change instruction. Other functions retain their sizes. |
| `avalanche` | 11 B | Palette setup uses additional ZP shifts and reloads; core named worker function sizes stay unchanged. |
| `lsystem` | 9 B | Different scratch allocation adds transfers around multiplication, shifts, and lookup work. |
| `dctbloom` | 4 B | Four additional transfers in `fill_cell` setup, before its nested loops. |
| `bf_vm_sim`, `rotkal_sim`, `seqvm_sim` | 1 B each | Loading the high pointer byte into X/Y early adds TXA/TYA when consuming it. |

These bounded losses are accepted for the local optimization after inspecting
all growing cases and rejecting the broader models. This is a documented
tradeoff, not a claim of universal profitability. **Hot-loop cycles and compile
time were not measured**; runtime checks establish correctness, not speed.
The zero-regression criterion for measured cycles therefore has no supporting
cycle experiment. In particular, the L-system frame traffic and XY16 HUD mode
change remain candidates for later profitability work.

## 8. Completed validation and packaging

- **Matching-input scheduler check:** baseline fails and 0064 passes for normal,
  top-down, and bottom-up scheduling on 6502, a16, and xy16: nine red/green pairs.
  Single-chain/dead-carry and necessary-overlap controls pass. The final MIR
  also lowers through the remaining pipeline with machine verification.
- **Full MOS CodeGen + MC lit:** **177 passed, 2 unsupported, 0 failed**.
  The original baseline MOS tests pass. The TableGen-only experimental test
  is retained as evidence and is not shipped in 0064.
- **Runtime corpus:** all **79 native corpus cases + 50 fixed fuzz seeds** pass
  the manifest/generated oracle, MAME default/a16/xy16, and bsnes a16 checks.
  [Results](../defects/evidence/2026-09-26-mos-carry-scheduling/runtime-results.json)
  and complete emulator logs are retained.
- **Original C functions:** both tools, both functions, and a16/xy16 function
  modes pass 24 iterations over six bank-boundary index triples with a common
  a16 driver: eight ROMs × two emulators = **16 passes**. Functions compile
  separately without LTO. Sum/rotate oracle hashes are `0x7BF2E264` /
  `0xAF1D6A7D`. The first all-XY16-driver attempt fails on both tools; its
  distinct wrong values are preserved and its cause is not yet isolated.
- **Focused gates:** `farindex`, `farbank`, BankWalk, `a16storebytes`,
  `a16indirectstore`, `a16shift`, and `a16ashift` pass. The normal SDK-linked
  BankWalk/far-index gates cover their default LTO configuration in addition
  to explicit non-LTO objects.
- **Inherited blocker:** `farblit` fails before scheduling while legalizing an
  s8 `G_LOAD_FAR_ABS` at 8355871, on both preserved baseline and candidate.
  [Separate canonical record](../defects/mos-farblit-byte-load-legalization.json)
  preserves source, preprocessing, IR/MIR, commands, and diagnostics. The patch
  interaction is unisolated; this is not a passing runtime gate.
- **Assembly roundtrip:** default **97 identical / 25 skipped**, a16 and xy16
  each **121 identical / 1 skipped**, zero divergent. XY16 was repeated after
  an initial `/tmp` capacity failure; both logs are retained.
- **Patch roundtrip:** `dev/regen-patch.sh` passes against a pristine vendor
  worktree plus the patch stack. **0002 is byte-identical** to its starting
  version. 0064 is registered in toolchain application, standalone exclusions,
  and focused-test regeneration. The initial `/tmp` capacity failure and
  successful workspace-TMPDIR retry are both retained.
- The final cleanup rebuild is byte-identical to the installed candidate used
  for the census and runtime checks. [Candidate identity](../defects/evidence/2026-09-26-mos-carry-scheduling/candidate-identity.json)
  records Clang, llc, linker, and patch hashes. No candidate compiler was
  installed over main's differently based compiler.

## 9. Upstream PR preparation

The standalone [PR packet](../pr-preparations/2026-09-26/0064-pr-body.md) is
ready for upstream review on llvm-mos main
`7bd67c0ae4e8bb65a3f980912bf201df22131e34`. Local branch
`mos-computed-carry-scheduling` in `.scratch/carry-pr/source` contains commit
`155e209c4cee8eeac01397aac3542e76841a9856`. At completion of local preparation, no branch had been pushed or PR posted.
[Destination and profitability review](../pr-preparations/2026-09-26/0064-review.md)
and [exact validation](../pr-preparations/2026-09-26/0064-validation.md) distinguish
this extraction from the earlier downstream stack.

- The original grouped MIR already passes at this upstream revision. A valid
  interleaved shift/add input supplies the current regression: five scheduling
  checks fail on baseline, all ten candidate RUNs pass; top-down is an existing
  passing control. Native feature RUNs are replaced by ordinary 6502, 65C02,
  65CE02 and stock 65816 checks; multiple carry users are also covered.
- The 6502 kernel shrinks **133 → 59 bytes**, removing six materializations.
  Baseline and candidate each pass **512 frozen Python-oracle vectors** in
  mos-sim. Full candidate MOS suites: **132 passed / one unsupported**.
- With a fixed downstream frontend, 13 ordinary near-code fixtures across
  three CPUs and Os/Oz/O2 give **117 identical object disassemblies**. This is
  neutral current-upstream backend coverage, not a broad upstream size gain.
- The recorded downstream 1–41-byte losses remain accepted in the proposal.
  Extra loop frame traffic and the HUD mode transition are explicit costs;
  neither cycles nor compiler overhead was measured.
- Review is by the implementation agent, **not independent review**. Attribution:
  OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning
  effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.

**PASS — upstream candidate MOS CodeGen + MC suite.** The retained
[suite log](../pr-preparations/2026-09-26/validation/runs/carry-0064-upstream/final-suite.log)
records:

```text
Total Discovered Tests: 133
  Unsupported:   1 (0.75%)
  Passed     : 132 (99.25%)
```

This result covers the exact upstream extraction above. The inherited farblit,
all-XY16 driver, and diagnostic-only null-emission observations retain their
separate qualified status below.

## 10. Remaining work

Recheck the destination if it moves before publication, then submit the prepared
packet when requested. The generic TableGen pressure-contract repair, inherited
farblit legalization failure, and unisolated all-XY16 driver observation remain
separate follow-ups. Cycle and compile-time measurements are needed before
making speed or compiler-overhead claims. The upstream validation record also
retains an unisolated diagnostic-only null-emission failure on both builds;
normal object emission passes, and this preparation does not attempt its repair.

## 11. Publication

Following the user’s commit/push instruction, compiler commit `155e209c4cee`
is pushed to the [fork branch](https://github.com/wbniv/llvm-mos/tree/mos-computed-carry-scheduling).
The downstream patch, retained evidence and PR packet are committed on
`carry-scheduling-preparation`, based on repository `origin/main` at `b3938bda`.
The shared checkout and unrelated staged work are preserved. No PR has been
opened. The earlier local-preparation statements describe their dated state.

Publication: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.
