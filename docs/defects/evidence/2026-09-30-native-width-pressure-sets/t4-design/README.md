# T4 design: native-width pressure sets that leave default mode alone

Canonical record: [`mos-native-width-pressure-sets`](../../../mos-native-width-pressure-sets.json). Plan section: [T4 design](../../../../plans/2026-09-30-native-register-pressure-sets.md#t4-design). The Phase A evidence one level up is unchanged. This directory only adds to it.

Attribution: Claude Code 2.1.285 (`claude --version`), model Claude Opus 5.5 (`claude-opus-5-5`), `high` reasoning effort (t4-opus-high agent definition); session [session_01HAKZG571yi9zqmAeWQZVtk](https://claude.ai/code/session_01HAKZG571yi9zqmAeWQZVtk).

## Result

| Gate | Result |
|---|---|
| Generated `PressureNameTable`/`PressureLimitTable` at #321‑1 and head | equal upstream `06bc967d2668` (`tables/321-01-t4.txt`, `tables/321-16-t4.txt`); full sections equal the Phase A candidate |
| Default identity at #321‑1, frozen `default-identity.sh` vs upstream | exit 0, `RESULT: IDENTICAL`, 90 of 90 in both modes (`final-321-01/default-vs-upstream/`) |
| Default at head vs the Phase A candidate at head | exit 0, `RESULT: IDENTICAL` (`final-321-16/default-vs-cand1/`) |
| `+mos-a16` at head vs unchanged `321-16` | 321,489 → 321,411 B (−78; 16 larger, 4 smaller, 10 excluded on both sides) |
| `+mos-a16,+mos-xy16` at head vs unchanged `321-16` | 300,012 → 299,850 B (−162; 15 larger, 5 smaller, 11 excluded on both sides) |
| MOS CodeGen+MC lit | #321‑1: 132 pass, 1 unsupported; head: 143 pass, 1 unsupported; no MOS warnings |
| `-verify-machineinstrs`, native modes, fixed set | same 152 clean / 28 failing inputs as unchanged head, with the same failure signatures (`verify/`) |
| bsnes‑jg runtime, 9 corpus sims × 3 modes | 23 PASS; the same 4 llc failures (domcol default, perlin ×3) occur on unchanged head (`runtime/`) |

The native sizes come from `final-321-16/native/size.txt` (Phase A's frozen `size-compare.sh`), and `final-321-16/native/compare.txt` lists the 20 changed inputs per mode. No compile status changes.

## Root cause (native mode)

1. **Every pressure consumer carries part of it.** `consumers/summary.txt` compares unchanged head (`321-16`) with the Phase A candidate (`321-16-cand1`) with each consumer disabled:

    | Disabled | `+mos-a16` Δ | `+mos-a16,+mos-xy16` Δ |
    |---|---|---|
    | nothing | +539 | +217 |
    | MachineLICM | +466 | +72 |
    | MachineSink | +356 | +19 |
    | machine scheduler | +178 | +215 |
    | all three | 0 (79/79 asm-identical) | 0 (78/78) |

    No single consumer explains the growth. The three together account for all of it, as in default mode in Phase A.

2. **The sets that matter are the native classes' own.** With `GeneratePressureSet = 0`, `Ac16`, `Xc16` and `Yc16` get an empty pressure-set list (`tables/decoded-candidate.txt`). A 16‑bit virtual register then costs nothing in any set. The scheduler freely keeps an 8‑bit `Ac` value live across a 16‑bit accumulator chain, which clobbers A. MachineLICM sees cheap `Ac16` definitions as free to hoist. In unchanged head, `Ac16` counts toward the `Ac16` set (limit 2) and the inferred `GPR_LSB_with_*`/`Anyi1_with_*` sets, and the 8‑bit `Ac` class counts toward `Ac16` too (`tables/decoded-321-16-unchanged.txt`). Probe variants (`variants/summary.txt`; the probe build is `variants/probe.diff`) isolate this:

    | Probe | Native-class modelling | a16 Δ vs head | xy16 Δ vs head |
    |---|---|---|---|
    | 0 | none (Phase A) | +539 | +217 |
    | 1 | charge the low byte's generated sets (`Ac`/`Xc`/`Yc`), weight 2 | −10 | −147 |
    | 2 | 1 + high-byte units `B`/`XH`/`YH` charge the low byte's unit sets | −10 | −132 |
    | 3 | 1 with weight 1 | +531 | +206 |
    | 1 with weight 3 / 4 / 6 / 8 | | +622 / +426 / +165 / +752 | +515 / +1,460 / +1,297 / +1,643 |
    | 4 | 1 + appended per-register sets `A16`/`X16`/`Y16` (limit 2), charged by the native classes and high-byte units | −53 | −196 |
    | 5 | 4 + the 8‑bit `Ac`/`Xc`/`Yc` classes and `A`/`X`/`Y` low units also charge them | −78 | −162 |

    Giving the native classes pressure removes the whole growth (probes 1, 2, 4 and 5). The natural class weight of 2 is required, and weight 1 brings the growth back (probe 3). The remaining wins over head, such as `tea_sim` (1,077 → 788 B) and `avalanche_sim` (1,058 → 1,031 B), come from the 8‑bit set structure returning to upstream's (`MOSAsmParamRegClass` limit 3 instead of the merged `Xc16`/`Yc16` sets, limit 4). That is the same effect that shrinks default mode at head by 3,515 / 3,379 B.

3. **Concrete diffs.**
    - `mir/mv_step.{head,p0,p1}.after.mir` (mvscrl): the candidate schedules `%11:ac = COPY; ANDImm` before the `LDAImag16`/`ADCImag16`/`STAImag16` chain, so the byte lives across the 16‑bit A. In the assembly it becomes `sta __rc10 … lda __rc10`. Head and probe 1 keep it after the chain.
    - `mir/stats.*`: regalloc spills inserted for packrec are 30 in head, 45 in the candidate and 40 in probe 1. For mvscrl they are 24 / 35 / 25, and for dither 64 / 73 / 68.
    - Per function: `mvscrl` `build_bands` is 942 → 1,039 B in the candidate and 982 B in probe 1. `packrec` `pk_parse_at` is 1,042 → 1,143 B in the candidate and 1,119 B in the chosen design.

## Chosen design (probe 5, implemented without the probe option)

`change/change-321-01.diff` and `change/change-321-16.diff` hold the same change applied at each commit; the only difference is one include line of context.

- `MOSRegisterInfo.td`: `let GeneratePressureSet = 0 in { Ac16, Xc16, Yc16 }`, the Phase A change. The generated tables stay upstream's.
- `MOSRegisterInfo` takes the subtarget: `MOSRegisterInfo(const MOSSubtarget &)`, constructed as `RegInfo(*this)`. Features are read lazily, after `ParseSubtargetFeatures` has run.
- It overrides `getNumRegPressureSets`, `getRegPressureSetName`, `getRegPressureSetLimit`, `getLargestRegClassForRegPressureSet`, `getRegClassPressureSets` and `getRegUnitPressureSets`. When `hasAccum16()` is true, it appends one set per 16‑bit register (`A16`, `X16`, `Y16`). Each set's limit is its unit count, 2. The two byte units count toward it, as do the classes whose registers all lie inside the wide register (`Ac` and `Ac16`, `Xc` and `Xc16`, `Yc` and `Yc16`). The native class also counts toward its low byte's generated sets. The lists are derived in the constructor from the generated tables. Otherwise every hook defers to the generated code, so any subtarget without `+mos-a16` sees upstream's tables exactly.

Frozen llcs (`frozen-llc.sha256`, under `build/pressure-sets/t4/llc/`): `321-01-t4` `ab1c56fd…fedfb`, `321-16-t4` `0f3f63bf…054d`. On the native set, `321-16-t4` is asm-identical to probe 5 on 80 of 80 and 79 of 79 inputs (`final-321-16/t4.native.tsv` vs `variants/probe5.tsv`).

## Rejected alternatives

- **Probe 1, borrowing the low byte's generated sets without dispatching on the subtarget.** It is the smallest change, with no subtarget dependence, because the native classes only exist under `+mos-a16`. But it clears the bar by only 10 B for `+mos-a16`, and 21 inputs grow.
- **Probe 4, where only native registers charge the appended sets.** Its total is almost the same (−249 B vs −240 B). It confines the effect to functions that contain native virtual registers, and at #321‑1 it should leave native output equal to upstream mosw65816 (not measured). But more inputs change (20 larger, 10 smaller), and the per-input regressions are larger (dither +105, packrec +97, mvscrl +80, against probe 5's largest, packrec +86).
- **Hand-encoding head's full 14 sets in native mode.** This would make native output byte-identical to head, with no growth anywhere. But it gives up the net win (`tea_sim` −289 B), and it means a large hand-written table that an upstream reviewer would have to audit.
- **Weights other than 2 (probes 3 and 1 with weights 3–8).** All of them are worse.

## Open points

- **Per-input growth under the total.** At head, 16 (`+mos-a16`) and 15 (`+mos-a16,+mos-xy16`) inputs still grow. The largest is packrec at +86 B, and the next are +17 B. The totals shrink.
- **Placement at #321‑1.** In commit 1, `+mos-a16` has no native codegen yet, but the appended sets already affect 8‑bit code under `+mos-a16`. The result is 293,975 → 292,264 B against unchanged #321‑1, but +1,491 B against upstream mosw65816, which Phase A's flag-only change matched (`final-321-01/native-summary.txt`). The hooks could instead go into the first commit that selects `Ac16`, with the flag staying in commit 1.
- **Side finding, not acted on.** Disabling MachineLICM on unchanged head shrinks native output by 9,664 B / 8,809 B (`consumers/summary.txt`), with 2 more compile failures.

## Tools (`tools/`)

- `sizes.sh`: per-input size and hashes for one llc, with extra llc flags.
- `size-diff.py`: totals, counts and movers from two `sizes.sh` outputs.
- `run-consumers.sh`: the consumer ablation.
- `run-probe.sh`: the probe variants.
- `decode-psets.py`: readable per-class and per-unit sets from the generated `.inc`.
- `verify-sweep.sh`: the `-verify-machineinstrs` sweep.
- `runtime-check.sh`: fixed-set corpus IR → llc → SDK link → bsnes‑jg `corpus_result`.

MAME legs were not run, because they need the SPC700 IPL secret.
