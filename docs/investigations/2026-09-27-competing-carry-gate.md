# Computed-carry scheduling in LLVM-MOS: measurements and implementation options

**Investigative report for LLVM and LLVM-MOS code-generation discussion — 2026-09-27.**

A target-specific preference for reducing overlapping carry values produces substantial size and execution-time improvements on several MOS inputs. It also changes allocation in ways that can increase size or execution time elsewhere. This report compares that preference with a more selective region gate, presents the measured trade-offs, and outlines ways to select profitable cases.

Across 3,592 successful three-policy comparisons, the original carry preference saves 213,866 bytes relative to disabling that preference; the gate saves 199,309 bytes. The gate produces fewer growing objects, **6 versus 39**, and recovers all 32 previously identified growth cases. Its aggregate saving is 14,557 bytes smaller, or **6.81% of the original saving**. This percentage is not an increase in total program size. Targeted sum/rotate timing gains remain, while individual exceptions show that neither policy improves every measured input.

These results describe a trade-off for review. They do not select or reject an upstream default. The local experiment plan used a 5% limit on lost aggregate savings; that was a project-specific evaluation threshold, not an LLVM acceptance criterion. The current downstream compiler exposes `off`, `always` and `gated`, with `always` as its existing default.

**Profitability follow-up:** [Objective switches, three pressure-model trials and a working object selector](2026-09-27-carry-profitability-model.md). MOS already has size/speed cost objectives. The tested pressure models lose aggregate savings and increase total positive growth in the screen. Complete-object selection is now implemented: file-byte selection saves 214,344 B, or 211,974 B with writable storage capped at `off`. Adding the gate to `off`/`always` gains 220 B in 55 configurations. The follow-up records fresh execution and compilation-cost measurements and retains the limits of object-level selection.

## Motivation and policies

The underlying [pressure-set investigation](../defects/mos-carry-scheduling-pressure.json) found that the retained TableGen implementation reads `IsPressureFineGrained` but does not propagate it to initial register-unit pressure sets. The experiments here use a MOS scheduler workaround that counts carry values directly. They do not establish a generic pressure-contract repair or its suitability for other targets.

| Policy | Behavior |
| --- | --- |
| `off` | Ordinary MOS scheduling, with the additional computed-carry preference disabled. Instruction scheduling itself remains enabled. |
| `always` | Track virtual computed carry values and prefer candidates that reduce carry pressure above one before the existing physical-register pressure preferences. Exclude `LDImm1` initializers. |
| `gated` | Restrict the tracked values and apply the additional preference only when two eligible computed carries can overlap in the scheduling region. |

The original preference is carried in downstream [patch 0064](../../patches/llvm-mos/0064-mos-computed-carry-scheduling.patch); the three-policy experiment is [patch 0067](../../patches/llvm-mos/0067-mos-competing-carry-gate.patch). Those numbers identify this repository's patch bundle, not LLVM revisions or proposed upstream patch ordering.

## Why the gate removes the incidental regressions

The 6502 and 65816 have one carry flag. When two computed carry values must stay live at once, one may need to be materialized as a byte and later restored. The three-instruction materialization in the preserved 8-bit controls occupies six bytes (2 + 2 + 2); the original plan’s five-byte note was incorrect. Patch 0064 gives the scheduler an extra preference for avoiding that overlap. Its original model excludes `LDImm1`, but also counts `LDCImm` constants, provisional frame-address carries and carries with users outside the scheduling region. Those values do not establish that changing the local order will avoid an expensive carry save.

This distinction matters because instruction order affects register allocation. A schedule chosen to reduce the modeled carry pressure can require more register moves, zero-page saves/reloads, frame space or accumulator/index-width changes. The retained disassembly shows that none of the 32 growing configurations removes a carry materialization in its growing function. Their combined 208-byte cost therefore has no compensating reduction in these carry-save sequences.

The experimental `gated` policy restricts both the values being tracked and the regions where the extra preference applies:

- Exclude `LDImm1` and `LDCImm`: their carry constants can be rematerialized with `CLC` or `SEC`.
- Exclude `AddrLostk` and `AddrHistk`: frame layout can turn these pseudos into copies or constant carry loads. Their provisional carry is not enough evidence of an expensive computed value.
- Exclude values with a scheduling-boundary user: their complete lifetime is not represented by the local scheduling region.
- Require two remaining computed carry values whose lifetimes can overlap under the dependency graph. If every use of one must precede the other's definition, that pair does not compete. A use at the next definition ends the first range.

When no eligible pair competes, the extra carry preference is skipped and the ordinary MOS pressure heuristics choose the order. Across the 32 original growing configurations, the gated object disassembly matches `off` exactly. This explains why the HUD and DCT instruction costs disappear: the gate avoids the incidental schedule changes that introduced them. The runtime measurements separately check that recovery; matching byte size alone would not establish equal execution time.

This is a conservative heuristic, not a proof that every activated region gets smaller or faster. Farblit XY16 O2 removes 22 carry materializations, so the gate still activates. Its other allocation and instruction costs outweigh that saving: 45 extra bytes and 298,012 → 300,276 master clocks, a 0.76% slowdown in the measured `main` interval. This is a measured counterexample to using fewer carry saves alone as a sufficient size or speed criterion.

## Experimental scope and limitations

`off`, `always` and `gated` are selected with `-mos-carry-sched` in one identified compiler build. `always` retains the original 0064 policy. All other compiler changes, linker inputs and runtime drivers are held fixed within each comparison. The downstream stack includes native-width work and separate near-store profitability and far-load legalization changes. The census is evidence about that stack; it is not a three-policy measurement of an otherwise unmodified upstream compiler. Earlier preserved-build timing remains dated evidence in [the original timing report](2026-09-27-mos-carry-timing.md).

These configurations reuse sources and are not independent programs. Aggregate byte totals weight each configuration equally; they do not represent a workload-weighted benefit or the size of one ROM. Inputs that fail in all three policies are excluded from the size comparison. The selected runtime intervals do not cover all census inputs. The exact upstream extraction has its own size and correctness evidence and was not retimed here.

The census covers Os/Oz/O2 in default, A16 and XY16 modes, plus the ordinary-6502 adapted fixtures. For the 65816, A16 enables the downstream `+mos-a16` accumulator-width feature; XY16 enables both `+mos-a16` and `+mos-xy16` index-width support. Default enables neither feature. Cycle measurements use the calibrated bsnes-jg probe and repeat each run twice while checking the result oracle. The original sum/rotate functions retain the common A16 driver used in the earlier report. Compiler wall-clock measurements use a separate sequential run; concurrent census durations are not a compile-time benchmark.

The published [SNES L-System Plant](https://biohack.net/snes/lsystem/) provides application context for one measured workload. Its portable logic is shared with a host oracle and corpus slice. The retained ROMs and profiles identify the versions used for the timing comparisons; the published demo is supporting workload context.

## Code-size results

The [census](../defects/evidence/2026-09-27-competing-carry-gate/census-summary.json) contains **3,720 configurations**: 409 sources × Os/Oz/O2 × default/A16/XY16, plus 13 adapted ordinary-6502 inputs × three optimization levels. All three arms compile successfully in **3,592** configurations. The other **128** reject in all three arms; there are **zero policy-specific compile failures**. O2 now covers all 409 sources, expanding the original 252-source O2 sweep.

| Policy | Aggregate text change versus `off` | Objects growing versus `off` |
| --- | ---: | ---: |
| `always` | −213,866 B | 39 |
| `gated` | −199,309 B | 6 |

These are sums across configurations, not one ROM’s size. The original 32-case archive contains 208 bytes of growth; the current combined stack has 194 bytes of growth on those same configurations. `gated` matches `off` disassembly exactly for all 32. The full-census growth counts also include other configurations and should not be read as a recount of just those 32 cases. The four preserved sequence-count controls match 17/18 and 12/12 materializations/`CMP #1` candidates before 0064, and 0/0 afterward. A `CMP #1` count alone does not prove that an instruction restores a saved carry.

The original C controls retain sum 409 → 248 B and rotate 385 → 285 B in A16 and XY16, with zero materializations under `gated`. The retained upstream kernel MIR, compiled on the current downstream stack, is 115 → 51 B, also with zero saves. Its earlier 133 → 59 B result belongs to the earlier upstream build.

### Six whole-object growth cases under `gated`

| Input | Mode / opt | Bytes | Carry materializations | `off` → `gated` master clocks |
| --- | --- | ---: | --- | ---: |
| `matcascade_sim` (`mat_mul`) | default / O2 | +4 | 2 → 2 | 6,015,932 → 6,019,372 |
| `farblit` (`main`) | xy16 / O2 | +45 | 27 → 5 | 298,012 → 300,276 |
| `avalanche` (`main`) | default / Os | +1 | 1 → 0 | 194,399,540 → 194,399,582 |
| `matcascade_sim` (`mat_mul`) | default / Os | +4 | 2 → 2 | 6,015,316 → 6,018,796 |
| `avalanche` (`main`) | default / Oz | +1 | 1 → 1 | 195,115,060 → 195,115,058 |
| `matcascade_sim` (`mat_mul`) | default / Oz | +4 | 2 → 2 | 6,032,318 → 6,035,758 |

`matcascade_sim` grows four bytes at each optimization level, with two materializations in `mat_mul` in every arm. Its `main` also forfeits the 64-byte saving and eight removed materializations achieved by `always`. Avalanche `-Oz` grows one byte without removing a materialization. Thus four of these six configurations grow without removing a carry materialization in the growing function. The tiny Avalanche timing deltas include layout/refresh effects and are not isolated hashing benchmarks. The matcascade intervals cover `main` through the oracle store.

### Mode subsets and function-level growth

A [derived analysis](../defects/evidence/2026-09-27-carry-selection-options/analysis.json) examines the same retained census at object and function granularity. It adds no compiler or runtime runs. All three policies have matching function-name sets in each comparable object.

| Mode | Comparable configurations | `always` saving vs `off` | `gated` saving vs `off` | Growing gated objects | Growing gated function/configuration pairs |
| --- | ---: | ---: | ---: | ---: | ---: |
| Ordinary 6502 fixtures | 39 | 2,907 B | 2,909 B | 0 | 0 |
| 65816 default | 1,117 | 153,149 B | 140,514 B | 5 | 21 |
| 65816 A16 | 1,219 | 29,330 B | 28,237 B | 0 | 0 |
| 65816 XY16 | 1,217 | 28,480 B | 27,649 B | 1 | 1 |

A16 retains **96.3%** of `always`'s aggregate saving in that mode, with no observed function or object growth. The ordinary-6502 sample likewise has no growth, but contains only 13 adapted sources at three optimization levels. These are post-hoc observations that motivate further testing; they do not establish a universally profitable mode restriction or a timing guarantee.

Whole-object totals can hide function growth. For example, default O2 `wire3d_sim` shrinks by 112 bytes while `mat3_mul` grows by nine. In total, `gated` has 22 growing function/configuration pairs across six growing objects and additional objects that shrink overall. The carry-save counts and timings in the preceding table cover its six named cases; the newly enumerated function increases have not all received that analysis.

### Alternative gates explored

The initial constant-only exclusion recovered HUD/DCT growth but left 22 original regressions. Excluding provisional frame values and boundary users recovered all 32, producing the experimental policy retained here. Additional trials compared the 32 controls and the largest lost wins:

- Allow arithmetic carries with boundary uses: recovered no bytes in the 100 selected lost-win configurations.
- Use local carries only to activate the gate, then track provisional/boundary values too: recovered 5,939 bytes in that sample, but restored 20 original regressions.
- Allow all boundary carries while excluding frame pseudos: recovered 796 bytes but restored 14 original regressions.
- Track constants only after computed carries activate the gate: recovered only 61 bytes in the expanded sample.
- Require a competing pair to be serializable in at least one direction, excluding forced overlap: changed none of the sampled results. Combining this with the conditional constant tracking still recovered only 61 bytes.

These are sample totals, not full-census estimates. Provisional frame carries can be expensive after layout, so excluding them can also lose useful carry-save reductions. The variants illustrate the tension between avoiding incidental scheduling changes and recognizing profitable carry preservation. They are retained as experimental evidence and are not included in patch 0067.

## Execution-time results

All 34 comparisons from the earlier timing report were replayed with the current stack and all three policies: **102 ROM/policy measurements, each run twice**. The four sum/rotate cases retain the measured **30.45% / 17.61%** speedups. For the 30 originally growing SNES cases, `gated` and `off` have **identical measured clock counts**. The separate XY16 Oz interpreter interval also matches `off`. These results establish recovery for those inputs, not universal non-regression.

| Scope | `off` | `always` | `gated` |
| --- | ---: | ---: | ---: |
| Sum, 24 calls, A16/XY16 | 106,784 | 74,264 | 74,264 |
| Rotate, 24 calls, A16/XY16 | 111,192 | 91,608 | 91,608 |
| First HUD update, A16 Os | 60,534 | 60,664 | 60,534 |
| First HUD update, XY16 Os | 60,414 | 60,598 | 60,414 |
| 128 DCT fill-cell calls, A16 Os | 20,670,778 | 20,678,780 | 20,670,778 |
| L-system interpreter, XY16 Oz | 17,336,362 | 17,109,190 | 17,336,362 |

Values are SNES master clocks. The current stack includes other compiler repairs, so absolute values differ from the preserved September 26 build. In particular, the current `always` interpreter is faster than current `off`; the earlier +2.80% result remains valid for its frozen build pair. The interpreter entry marker is verified at `main + 0x14f` in every arm. Original inputs, ROMs, raw profiles, commands and identities are retained separately for both experiments.

The ordinary-6502 kernel runs the same 512 oracle vectors in every arm. Whole program `mos-sim --cycles --profile` counts are **179,472 / 145,659 / 145,659** for `off` / `always` / `gated`, repeated identically. These include the common driver, startup and result checking; they are CPU cycles, not SNES master clocks. Timing of the two adapted 6502 rotkal census inputs and the exact upstream compiler extraction remains outside this result.

## Compile-time results

Six representative configurations were compiled sequentially after the census, runtime and trial jobs finished, using the final compiler. Each arm/input has one warmup and seven measured runs, rotating arm order by input and round. Both wall time and child-process CPU time are retained. The shared host is an Intel Core i7-1185G7 running Linux; this is a bounded overhead check, not a dedicated benchmark machine.

| Input | Mode / opt | `off` median wall s | `always` | `gated` |
| --- | --- | ---: | ---: | ---: |
| `farblit` | xy16 / O2 | 0.1848 | 0.1897 | 0.1856 |
| `rcundef2` | xy16 / Os | 0.2181 | 0.2097 | 0.2067 |
| `lsystem_sim` | xy16 / Oz | 0.2148 | 0.2031 | 0.2199 |
| `dctbloom` | a16 / Os | 1.0053 | 0.9794 | 1.0117 |
| `avalanche` | default / Os | 0.5298 | 0.5616 | 0.5134 |
| `arith` | default / Os | 0.0468 | 0.0431 | 0.0401 |

The sum of the six medians is **2.1996 / 2.1867 / 2.1774 seconds**. The gated sum is 1.01% below `off`; run ranges overlap in every configuration, so these samples do not establish a compile-speed improvement. The corresponding CPU-time sums are 2.1651 / 2.1552 / 2.1215 seconds. No large compile-time cost is apparent in this sample; neither worst-case graph-query cost nor whole-project build time is bounded by these measurements. These samples run one policy at a time and do not measure the cost of compiling alternatives and choosing between them.

## Implementation options for discussion

### Compare completed alternatives and retain the smaller result

For size-oriented compilation, an implementation could preserve the input before carry scheduling, run `off` and a candidate policy through the remaining backend, and retain the smaller result. Keeping `off` on equal size would avoid changes with no measured size benefit. Comparison must include register allocation, frame lowering, instruction-width setup and branch expansion; a size estimate immediately after scheduling cannot observe the costs at issue here. LLVM's [code-generation pipeline](https://llvm.org/docs/CodeGenerator.html#the-high-level-design-of-the-code-generator) places allocation and other size-changing stages after early scheduling.

Two granularities merit separate prototypes:

- **Compilation-unit selection:** generate complete alternatives from the same input module and compare emitted text. This avoids merging incompatible allocation states and can enforce non-growth for that measured unit. A guarantee about the final program additionally requires a linked-image comparison that includes alignment, relaxation and other affected sections; fixed ROM padding must not conceal growth in used space.
- **Per-function selection:** preserve both candidate code and associated state, including frame objects, symbols, relocations and analysis results. The MOS zero-page allocator is a module pass that uses cross-function information. Independently compiled function bodies cannot simply be spliced together while assuming compatible storage assignments. The design would need to isolate or reconcile that shared state, rerun affected passes, and verify the final result. [Inspected pipeline excerpts](../defects/evidence/2026-09-27-carry-selection-options/pipeline-excerpts.txt)

Recalculating the retained object sizes gives the following potential selections:

| Alternatives available | Sum of whole-object savings vs `off` | Selected objects larger than `off` |
| --- | ---: | ---: |
| `off`, `always` | 214,124 B | 0 |
| `off`, `always`, `gated` | 214,344 B | 0 |

At the initial selection-options stage, these were arithmetic minima of existing outputs. The [subsequent prototype](2026-09-27-carry-profitability-model.md#a-working-completed-object-selector) implements whole-object selection, confirms these file-byte minima, examines writable storage, and links a measured subset. Taking the smaller function independently gives hypothetical sums of 214,323 B and 214,446 B, respectively. Those function totals do not account for recomputing shared allocation and layout. The [analysis script](../../dev/summarize-carry-selection.py) makes these distinctions explicit.

Generating alternatives adds compilation work. Sharing frontend and early backend work might reduce that cost; selecting only functions with eligible carry competition might reduce it further. Sharing frontend or early backend work remains unimplemented. The [subsequent prototype](2026-09-27-carry-profitability-model.md#compilation-cost) measures complete alternative compilations, including driver and evidence-recording overhead; it does not estimate the cost of an integrated LLVM implementation. The earlier local plan's estimate of roughly doubled backend time and categorical statement about upstream suitability were not established by an implementation. A size guarantee would also not establish a speed guarantee: fewer bytes can execute more slowly.

### Restrict the heuristic to a narrower subset

The A16 and ordinary-6502 observations motivate evaluating a mode-restricted gate. They provide a concrete starting point with no function or object growth in this sample and no need to generate both alternatives. A new default policy would still need broader ordinary-6502 inputs, timing coverage and validation on its exact intended compiler revision. Mode membership itself does not prove profitability.

Another possibility is a structural restriction: only change schedules when carry preservation is avoided without increasing the pressure of other resources. That condition would need to be defined and validated against final allocation; a pressure estimate alone is not a final-size proof. A late transformation that removes a specific carry save/restore sequence after allocation might permit a more local cost argument, but its correctness, opportunities and interaction with flags and layout have not been investigated here.

## Interpretation and recommendation for further investigation

The evidence supports two conclusions: directly accounting for computed carries can remove substantial avoidable costs, and carry competition or fewer materializations alone does not guarantee a profitable final schedule. The measurements do not determine the best default across targets, optimization levels and workloads.

**Recommendation for discussion:** use the [completed-object prototype and its measured choices](2026-09-27-carry-profitability-model.md) to evaluate a cheaper predictor and a design that shares frontend work while preserving module-wide allocation state. The tested generic-pressure estimates lose useful carry savings. Broader mode-restricted testing and final-link comparisons remain useful experiments. These recommendations do not select a default or determine upstream acceptability.

Useful review questions are where such a comparison should live in the backend, what shared state it must preserve, whether a cheaper predictor can reproduce most of the measured selections, and how size and execution time should be weighted for each optimization level. The preserved inputs and three-policy controls allow those questions to be tested against the same evidence.

## Correctness and reproducibility

- Final CodeGen/MOS and MC/MOS suites: **181 pass, two unsupported**. The new MIR test covers constants, serial computed chains, a live-out carry and frame address pseudos in both scheduling directions and native mode; it also checks that the default equals `always`. The existing positive carry test also runs explicitly under `gated` in all six configurations.
- The counter’s four tests pass. All 32 `always` outputs match the preserved pre-gate compiler. After setting the implementation default, 64 focused comparisons confirm that default and explicit `gated` match their frozen measured arms. The final scheduler source differs from the measured gate only in its default initializer; the experimental refinements are not in patch 0067.
- Runtime: **78 of 79 corpus cases and all 50 deterministic signed-32-bit fuzz seeds pass** across default/A16/XY16 MAME and A16 bsnes-jg, with machine-verifier checks. Ten initial short-window failures pass 40 rechecks on the exact same ROMs with the documented longer corpus window; both log sets are preserved.
- `vlastack_sim` XY16 returns `0xD3BD` instead of `0xD77B` on the preserved pre-gate compiler and all three policies, in both emulators. Default and A16 return the oracle. This September 27 observation was initially recorded under the canonical carry investigation. The [September 28 causal investigation](2026-09-28-vlastack-xy16-stale-reload.md) isolates an unsafe X-writer replay in `MOSInsertREPSEP` and links the [separate correctness record](../defects/mos-xy16-stale-x-writer-reload.json); the September 28 repair in `0002` preserves X itself, and the unchanged original input now returns `0xD77B` on both emulators. The September 27 measurements remain dated baseline evidence. The mismatch was not a gate-specific failure.
- Patch 0067 applies to the preserved pre-gate scheduler and reproduces the final sources/test exactly. Both toolchain application and 0002 regeneration lists include it. The installed compiler is refreshed with `always` as default.

The [evidence receipt](../defects/evidence/2026-09-27-competing-carry-gate/receipt.json) indexes compiler/source identities, the full census, source snapshots, original and new growth counts, refinement trials, runtime failures and reruns, linked ROMs, profiles, exact replay scripts and compile-time samples. Baseline files, earlier credits and the withdrawn PR #609 packet remain intact. No independent review, generic pressure-contract repair or upstream submission is claimed.

## Provenance

Implementation, measurements, analysis and report preparation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`. Earlier contributors' attribution remains in the linked source reports and evidence.

This report is revised for LLVM discussion from the [initial downstream assessment at c3c1967c](https://github.com/wbniv/llvm-mos-65816/blob/c3c1967c9c54bda475d6bc8b15d3a00281a82901/docs/investigations/2026-09-27-competing-carry-gate.md). That assessment and the frozen measurement receipt recorded rejection under the local plan's threshold. They remain historical evidence of that assessment; the current report presents the measured trade-offs and implementation options without making a default-selection decision. The [original experiment plan](../plans/2026-09-27-0064-competing-carry-gate.md) retains its dated criteria. The selection-options analysis is a subsequent calculation over the immutable census, with the input hash recorded.
