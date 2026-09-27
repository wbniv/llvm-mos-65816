# Carry-scheduler profitability: objective switches, pressure estimates and completed-output selection

**Investigation for LLVM and LLVM-MOS discussion — 2026-09-27.** Follow-up to the [competing-carry report](2026-09-27-competing-carry-gate.md), using the same downstream compiler stack and preserved census.

Size-versus-speed policy plumbing is straightforward and already exists in MOS. The harder part is estimating the effects of a schedule on allocation and final instructions. Three pre-allocation models were implemented and screened here. Each gives up aggregate savings and increases total positive growth; with the gate, none reduces the number of growing objects. With the original policy, fewer objects grow but the increases are larger in total. A separate prototype makes a concrete size decision by compiling complete alternatives and selecting an object. These results do not determine an upstream default.

## Size and speed objectives

The inspected `MOSInstrCost::getModeFor` selects these objectives from function attributes:

| Function / usual flag | MOS objective |
| --- | --- |
| `minsize` / `-Oz` | Bytes first, cycles as a tie-break |
| `optsize` / `-Os` | Sum of the byte and cycle estimates |
| Ordinary optimized function / `-O2` | Cycles first, bytes as a tie-break |

`optnone` also selects the average, although this investigation concerns optimized scheduling. This is existing MOS cost-policy behavior, not a claim about every LLVM target. The shipped carry preference does not consult this cost selector. The experimental weighted models reuse it and add `-mos-carry-objective=auto|size|speed` overrides. No new public Clang optimization-level switch is needed. [Source and file hashes](../defects/evidence/2026-09-27-carry-profitability/objective-source.txt)

A speed objective still needs a credible cycle estimate. Avoiding a carry materialization can add other moves, width changes or memory traffic; SNES bus timing also depends on placement and access type. Choosing a cycle-weighted score does not itself establish faster execution.

## Pre-allocation models tested

An isolated compiler worktree was based on downstream `b65bb853`. The controls retain 0064's `always` and 0067's `gated` policies. The new `-mos-carry-cost` option defaults to `legacy` in the experimental builds. The installed compiler and shipped patches are unchanged.

1. **Pressure first:** place carry excess after the existing physical-register and generic virtual-register pressure comparisons. The earlier experiment that moved it only below physical-register pressure had already shown no effect; this trial includes generic excess, critical-maximum and current-maximum pressure.
2. **Weighted:** combine carry excess with one generic pressure delta: excess if available, otherwise critical maximum, otherwise current maximum. Use an eight-byte/eight-cycle carry-preservation proxy and a four-byte/six-cycle zero-page spill/reload proxy per pressure unit. The eight bytes describe a six-byte carry diamond plus a two-byte compare; the cycle coefficient is approximate. Pressure units are not independently proven spill counts, and the generic sets can combine resources.
3. **Conditional trade-off:** use the weighted comparison only when candidates have different carry-excess deltas. Otherwise retain the existing comparisons. This isolates the cost trade-off from the weighted model's extra reordering on carry ties.

The screen contains **139 configurations**: the union of every growing object under either existing policy and the 100 largest savings lost by the gate. It deliberately stresses known difficulties. It is not a random sample, a held-out evaluation or the full census. Explicit `always` and `gated` controls reproduce all 139 retained disassemblies, respectively, in the corrected experimental build.

| Model | `always`: saving vs `off` | Growing objects / positive growth | `gated`: saving vs `off` | Growing objects / positive growth |
| --- | ---: | ---: | ---: | ---: |
| Existing preference | 28,003 B | 39 / 258 B | 18,376 B | 6 / 59 B |
| Pressure first | 9,677 B | 21 / 322 B | 5,843 B | 11 / 244 B |
| Weighted | 22,274 B | 28 / 1,171 B | 15,281 B | 17 / 1,036 B |
| Conditional trade-off | 24,897 B | 27 / 766 B | 17,534 B | 6 / 672 B |

All compilations pass machine verification. Explicit size and speed objectives produce identical disassembly throughout this screen for both weighted variants. That is a result for these coefficients and candidates, not evidence that size and speed generally agree. No coefficients were fitted to the screen, and these unsuccessful predictors were not promoted to a full-census or default-policy evaluation.

Farblit XY16 O2 illustrates the estimation problem. `off` produces 3,166 bytes and 27 counted carry materializations; the existing gate produces 3,211 bytes and five. Pressure first produces 3,336 bytes and 31 materializations, weighted produces 3,826 bytes and 31, and the conditional model produces 3,824 bytes and 31. The generic pressure proxy displaces profitable carry scheduling on this input. A sum of those pressure summaries is not an adequate final-cost estimate here. Pre/post-scheduling MIR, disassembly and the existing sequence counter's results are retained.

The first prototype incorrectly narrowed a 64-bit lexicographic score through LLVM's integer comparison helper. It was corrected before the reported weighted results, rebuilt, and rerun. Its earlier measurements are excluded. The corrected patch compares at full width and passes only the comparison ordering to the helper. The separate runtime binary was frozen before measurement.

## A working completed-object selector

[The prototype](../../dev/select-carry-object.py) takes one saved Clang compile command, compiles `off` and the requested candidate policies through complete object emission, and copies the selected complete object to the requested output. It keeps `off` on equal size; equal smaller candidates retain the requested policy order. A candidate compilation failure is recorded and excluded; a baseline failure propagates. It accepts ordinary non-LTO object compilation and rejects common side-output options. It is an investigation tool, not an integrated compiler driver or per-function rollback implementation.

For example, save one existing compile command as a JSON argument array in `command.json`, then run:

```sh
python3 dev/select-carry-object.py \
  --compiler build/llvm-mos-install/bin/mos-clang \
  --command-json command.json --output selected.o --report selection.json
```

The command's existing `-Os`, `-Oz` or other optimization flag remains in force. Selection is explicitly size-oriented even when evaluating an O2-generated candidate. Use `--policies gated` for the two-way `off`/`gated` experiment, or the default `always gated` for all three alternatives.

The size metric sums file-backed `SHF_ALLOC` sections, including code and initialized data. Debug information and object-file metadata do not contribute. The default prototype also caps writable allocated-section bytes at `off`; `--allow-writable-growth` removes that separate constraint. The latter exposes the code/storage trade-off rather than assuming a single universal meaning of “smaller.” Neither metric includes final linker padding or every form of runtime storage.

The full evaluation reads and verifies the hashes of **10,776 existing objects**, applies the selector to all **3,592 successful census configurations**, and writes 3,592 selected objects. The 128 common compile rejections remain excluded. This adds real section inspection and object selection to the earlier arithmetic analysis; it does not claim 3,592 fresh compilations or linked programs. Fresh compilation is exercised separately by the overhead experiment.

| Alternatives | Saving with file-byte objective | Configurations with writable growth | Saving with writable bytes capped at `off` |
| --- | ---: | ---: | ---: |
| `off`, `always` | 214,124 B | 7 | 211,754 B |
| `off`, `gated` | 199,368 B | 9 | 195,011 B |
| `off`, `always`, `gated` | 214,344 B | 7 | 211,974 B |

Every selected object meets the chosen file-byte criterion. The capped variants also have zero writable-section growth. The three-way file-only selection increases writable storage by a combined 17 bytes across its seven exceptions. Preventing those increases gives up 2,370 bytes of code saving. These sums describe repeated configurations, not one program's memory use.

**Contribution of the competing-carry gate:** adding `gated` to `off`/`always` selects it in 55 configurations and gains another **220 bytes** under either storage policy. This supplies a useful role for the gate as an alternative to evaluate. It does not imply that the gate should become the universal default. With the writable cap, the final choices are 2,492 `off`, 1,045 `always` and 55 `gated`.

Compilation-unit selection still hides individual function growth: **18 function/configuration pairs** grow inside selected objects that meet the object-level criterion. A per-function guarantee would need a different implementation that reconciles MOS's module-wide zero-page allocation. The selector does not splice function bodies.

## Execution and linked output

The completed-object choice, pressure-first model and weighted-size model were timed on **41 configurations**: the four original sum/rotate controls, 30 original SNES growth cases, six remaining gated growth cases and the compare-audit fixture. The compare audit also tests explicit speed and `off`; the conditional model has a separate five-case timing check. In total, **260 emulator executions** comprise two identical repetitions of each measurement, all passing their result oracles. Object selection across these 41 configurations uses the writable-storage cap. Existing preserved `off` runs supply the baseline except the compare audit, whose `off` run is new.

| Interval | `off` | Existing gate | Object selection | Pressure first | Weighted size | Conditional trade-off |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sum, 24 calls, A16 or XY16 | 106,784 | 74,264 | 74,264 | 103,600 | 84,624 | 74,264 |
| Rotate, 24 calls, A16 or XY16 | 111,192 | 91,608 | 91,608 | 106,288 | 108,360 | 91,608 |
| Farblit main, XY16 O2 | 298,012 | 300,276 | 298,012 | 300,516 | 312,440 | 316,900 |
| Matcascade main, default Os | 6,015,316 | 6,018,796 | 5,999,420 | 6,015,316 | 6,009,404 | — |

Values are SNES master clocks, not processor cycles. The object selector keeps the sum/rotate improvements of 30.45%/17.61%, matches `off` in all 30 original SNES growth cases, and chooses the faster `always` alternative for matcascade. No selected interval is slower than `off` in these 41 cases. Weighted and conditional pressure estimates make farblit **4.84%** and **6.34%** slower, respectively. These are bounded measurements; object selection itself contains no speed criterion.

All 41 selected programs were linked. Their allocated file-backed section sizes are no larger than the corresponding `off` programs: eight shrink and 33 are equal. This checks actual linked sections for the measured subset. Fixed-size ROM files include padding, and section-byte sums do not count every gap between sections or establish a guarantee for different link compositions. The remaining census configurations were not linked in this follow-up.

## Compilation cost

Six inputs were compiled sequentially after the other compiler, runtime and compression jobs finished, with one warmup and seven measured rounds per arm. Arm order rotates by input and round. The same preserved compiler handles every arm on the shared i7-1185G7 host. All **144 selector invocations** choose the expected policy and section costs; all **336 alternative objects** match the corresponding frozen census object hashes exactly.

| Input | Mode / opt | Single `always` median wall s | Select `off`/`always` | Select `off`/`gated` | Select all three |
| --- | --- | ---: | ---: | ---: | ---: |
| Farblit | XY16 O2 | 0.1846 | 0.8369 | 0.8748 | 0.9769 |
| rcundef2 | XY16 Os | 0.2131 | 0.8955 | 0.8931 | 1.0247 |
| L-system corpus | XY16 Oz | 0.2498 | 0.9586 | 0.8613 | 1.0786 |
| DCT bloom | A16 Os | 0.9338 | 2.2880 | 2.2214 | 3.0619 |
| Avalanche | default Os | 0.4910 | 1.4318 | 1.4531 | 1.9613 |
| Arithmetic corpus | default Os | 0.0442 | 0.5636 | 0.5669 | 0.6208 |
| Sum of medians | | **2.1164** | **6.9744** | **6.8706** | **8.7243** |

The two-way prototypes take **3.30× / 3.25×** the single-`always` wall time; three-way selection takes **4.12×**. Corresponding sums of CPU-time medians are 2.0823 / 6.9145 / 6.8049 / 8.6629 seconds. Single `off` totals 2.0141 wall seconds. These ratios describe this executable prototype and these six inputs, not whole-project builds or backend-only work.

The prototype repeats full frontend/backend compilation and also starts Python, hashes the compiler, queries object sections and writes evidence on each invocation. Summing only the measured compiler subprocesses gives **4.1308 / 4.0030 / 5.8919 seconds** for the three selection arms. The gap to end-to-end time makes the additional prototype overhead visible. An integrated implementation that shares frontend work and avoids repeated evidence collection has not been built or timed; these results do not establish its overhead.

## Interpretation and next implementation steps

The objective switch is easy to wire. The tested pressure summaries do not provide a reliable estimate of the marginal allocation cost: prioritizing them loses useful carry savings, and restricting the comparison to carry-changing candidates does not resolve farblit. This is evidence against these particular models on the measured sample, not a proof that a better predictor is impossible.

Completed-output comparison answers a narrower size question directly and gives the competing gate a measurable additional role. Its costs and limits remain relevant: repeated frontend/backend work, incomplete final-link knowledge, and function growth hidden by whole-object savings. The experiments do not justify selecting a new default from a local aggregate-savings threshold.

**Recommendation for discussion:** use the retained completed-output choices as a reference when developing a cheaper predictor. A next pre-allocation model should distinguish the actual resources represented by pressure changes, carry rematerialization and clobbers, and native-width preservation costs; calibrate predicted changes against emitted saves, reloads and width transitions. Evaluate it on previously unseen sources before making a default-policy proposal. For an optional size-oriented implementation, investigate sharing frontend work while retaining whole-module allocation state, then compare final linked used space. Speed policy needs workload or profile evidence in addition to size selection.

## Reproducibility and status

The corrected and conditional experimental builds each pass **181 MOS CodeGen/MC tests**, with two unsupported. The selector’s four contract tests pass. Original baseline inputs, tests and defect status remain intact.

The [evidence receipt](../defects/evidence/2026-09-27-carry-profitability/receipt.json) records patches, source and binary identities, commands, MIR, object archives, timing logs and compile-time samples. The [plan](../plans/2026-09-27-carry-profitability-model.md) records the implementation and verification scope. The [canonical pressure record](../defects/mos-carry-scheduling-pressure.json) remains a **workaround**; no generic TableGen contract repair, XY16 VLA repair, upstream default change or submission is claimed. Earlier evidence and the withdrawn PR #609 body remain intact.

Implementation, measurements and report: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`.
