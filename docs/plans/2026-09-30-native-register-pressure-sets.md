# Keep the native-width registers out of default-mode register pressure

Status: **fixed in the split series; downstream deliberately held** (2026‑10‑01). The T4 design with the user's `-O3` gate is [applied](#application) to the #320/#321 split series, and verification steps 1–5 and 7 pass. The canonical record is closed as `fixed` with the split's red/green. Applied downstream, the same change makes default-mode code 0.58% larger, because the downstream carry scheduling depends on the pressure sets it removes (step 6). The user chose to keep `0002`'s current sets for now (option c). Downstream converges through the retune of carry scheduling (option b), which is tracked on the [carry-scheduling record](../defects/mos-carry-scheduling-pressure.json) and its TODO item. Earlier: Phase A done. The [T4 design](#t4-design) is done and measured, and its bar and placement are [decided](#decision-after-the-t4-design). [Optimization-level gating](#optimization-level-gating) is measured: ungated wins at `-Os`/`-Oz`, and a sound `-O2`/`-O3` gate needs a per-level subtarget, which was escalated for a decision. The T4 design followed the [decision](#decision-after-phase-a), after one escalation (see [Phase A results](#phase-a-results)). Canonical record: [`mos-native-width-pressure-sets`](../defects/mos-native-width-pressure-sets.json). The user approved this on 2026‑09‑30 ("Go ahead with it at T3?" — "yes"). The #320/#321 split found it: the first #321 commit only adds opt-in registers, but it changes default-mode code. On the split's fixed input set (38 MOS `.ll` tests plus 52 corpus IRs), mos6502 output grows 278,940 → 282,418 bytes (+3,478; 17 inputs larger, 1 smaller) and plain mosw65816 grows 290,773 → 293,975 bytes (+3,202; 24 larger, 8 smaller). Evidence: `build/split-320-321/evidence/321-01/{size-vs-base.txt,pressure-sets.txt,default-compare.txt}`, copied into the [split packet](../pr-preparations/2026-09-30/split-320-321/README.md).

Attribution: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`.

No visible surface: compiler change, no mockups.

## Cause

The commit ("[MOS] Model 65816 native-width registers and feature gates", split commit `a359c6b1d73c`) adds the registers `A16`, `X16` and `Y16`, the byte halves `B`, `XH` and `YH`, and the single-member classes `Ac16`, `Xc16` and `Yc16`. TableGen derives register pressure sets from every register class. The generated `PressureNameTable` and `PressureLimitTable` gain `Ac16`, `Xc16` and `Yc16` sets and the inferred `GPR_LSB_with_*` and `Anyi1_with_*` sets, and lose `MOSAsmParamRegClass`. MachineLICM, MachineSink and the machine scheduler read those tables in every mode. With all three disabled, default outputs match. The opt-in feature therefore changes default heuristics, which breaks this project's gating rule: an opt-in native form must not change code for programs that don't use it.

## Contract

- **Defect record first.** Before changing the compiler, create a canonical `docs/defects/` record following the [defect workflow](../howto-defect-evidence.md). It needs a prior-work audit and a failing baseline: a comparison that exits non-zero when default-mode output differs between upstream `06bc967d2668` and the commit. Freeze the baseline tools.
- **Hypothesis:** set `GeneratePressureSet = 0` on `Ac16`, `Xc16` and `Yc16`, the idiom AArch64 and AMDGPU use for classes that must not create pressure sets.
- **Success:**
  - The generated pressure tables equal upstream's.
  - Default mos6502 and plain mosw65816 output on the fixed input set is byte-identical to upstream `06bc967d2668`.
  - `+mos-a16` and `+mos-a16,+mos-xy16` output does not grow. Report any change with its size, and explain any that grows.
- **If the flag alone is not neutral** (for example, inferred classes keep their own sets), try the smallest follow-up, such as marking the inferred classes or adjusting register-unit weights. If it is still not neutral, stop and report `ESCALATE:` with the tables. This then becomes a T4 design question.

## Phases

1. **Phase A: isolated experiment, now.** Work in a worktree of the upstream source at the split's #321-1 commit, with its own warm build directory. Do not touch `vendor/`, the `split-320-321` branch or its build directories: two other agents hold them. Produce the defect record, the baseline, the candidate change and the comparisons. Stop and report.
2. **Phase B: apply, after the other agents finish.**
    - Apply the change to #321 commit 1 of the split series, and recheck the later packet patches and the per-commit suites.
    - Apply it downstream in `vendor/llvm-mos`, regenerate `0002`, rebuild, and run the project differential.
    - Close the record with a same-input red/green.

## Phase A results

**2026‑09‑30, isolated experiment.** Claude Code 2.1.285, model Claude Opus 5.5 (`claude-opus-5-5`), medium reasoning effort (t3-opus-med subagent). Evidence: [`docs/defects/evidence/2026-09-30-native-width-pressure-sets/`](../defects/evidence/2026-09-30-native-width-pressure-sets/README.md).

- **Baseline (red).** `tools/default-identity.sh` compares upstream `06bc967d2668` with unchanged `a359c6b1d73c`. It exits 1 with `RESULT: DIFFER (51 input/mode results changed)`: mos6502 has 18 of 90 inputs with asm differences and mosw65816 has 33 of 90. The rebuilt `a359c6b1d73c` llc is bit-identical to the split's deleted 321‑1 llc.
- **Change.** `let GeneratePressureSet = 0 in { … }` around `Ac16`, `Xc16` and `Yc16`, with no other edits.
- **Pressure tables.** `PressureNameTable` and `PressureLimitTable` equal upstream's at `a359c6b1d73c` and at series head `c33eb63d65a3`. The remaining full-section differences are the three new classes and the three new units (`B`, `XH`, `YH`), which are appended to existing set lists.
- **Default mode (green).** The change at `a359c6b1d73c` gives exit 0 and `RESULT: IDENTICAL`: 90 of 90 inputs are identical in both modes, in asm and object.
- **Native mode at #321‑1.** `+mos-a16` and `+mos-a16,+mos-xy16` output equals upstream plain mosw65816 output on 90 of 90 inputs, a change of −3,202 B against unchanged `a359c6b1d73c`.
- **Series head `c33eb63d65a3`.** Default-mode code shrinks by 3,515 B on mos6502 and 3,379 B on mosw65816 compared with unchanged head. Native code grows by 539 B for `+mos-a16` (80 inputs: 21 larger, 13 smaller) and by 217 B for `+mos-a16,+mos-xy16` (79 inputs: 21 larger, 10 smaller). No compile status changes. **The growth is not yet explained. Verification step 4 is escalated to T4** as a design question: whether native mode needs its own pressure modeling.
- **Lit.** MOS CodeGen+MC pass: 132 pass and 1 unsupported at `a359c6b1d73c` with and without the change, and 143 pass and 1 unsupported at head with the change.

## Decision after Phase A

The user chose **"Hold both, T4 first"**. Apply nothing to the split series or `0002` yet. The flag makes default mode neutral but costs native mode, with no cause known. At the series head `c33eb63d65a3`, `+mos-a16` grows 321,489 → 322,028 B (+539; 21 larger, 13 smaller) and `+mos-a16,+mos-xy16` grows 300,012 → 300,229 B (+217). A T4 investigation now owns the design:

- **Find the cause.** Identify which heuristic — MachineLICM, MachineSink, the machine scheduler or another pressure consumer — and which generated sets (`Ac16`, `Xc16`, `Yc16` and the inferred `GPR_LSB_with_*`/`Anyi1_with_*` sets) produce the native-mode benefit. Confirm it on the largest movers (dither, mvscrl, boids, sodo, packrec growth; tea_sim and nmitally_sim shrinkage).
- **Design one change that meets both bars.** Default mos6502 and plain mosw65816 output must be byte-identical to upstream `06bc967d2668` at #321-1, as the flag already achieves. Native `+mos-a16` and `+mos-a16,+mos-xy16` output at the series head must not grow against the unmodified head (`build/pressure-sets/llc/321-16`). Candidates include subtarget-dependent pressure-set limits or scores through the `TargetRegisterInfo` pressure hooks, and native-only modelling of the scarce 16-bit registers. The T4 agent chooses, with evidence.
- **Then apply one change everywhere.** Put it in #321 commit 1 of the split, or the commit that owns the modelling if that reads better, and in downstream `0002`. Phase B's verification (steps 5–6) then applies unchanged.

## T4 design

**2026‑09‑30.** Claude Code 2.1.285, model Claude Opus 5.5 (`claude-opus-5-5`), `high` reasoning effort (t4-opus-high subagent). Evidence: [`t4-design/`](../defects/evidence/2026-09-30-native-width-pressure-sets/t4-design/README.md).

- **Cause.** Under the flag, the native classes `Ac16`, `Xc16` and `Yc16` have no pressure sets at all. A 16‑bit virtual register therefore costs nothing to the scheduler, MachineLICM or MachineSink. In the MIR diffs, the scheduler keeps an 8‑bit A value live across a 16‑bit accumulator chain, and regalloc spills go up; packrec, for example, goes from 30 spills to 45. Disabling any one consumer leaves most of the growth. Disabling all three removes it. Giving the native classes pressure again removes the growth completely. The remaining native wins over head come from restoring upstream's 8‑bit set structure, the same effect that shrinks default mode.
- **Design.** The TableGen flag stays, so the generated tables are upstream's. `MOSRegisterInfo` takes the subtarget and overrides the six pressure-set hooks. Under `+mos-a16`, it appends sets `A16`, `X16` and `Y16`, each with limit 2. These are charged by each wide register's byte units and by the classes that lie inside it (`Ac`/`Ac16`, `Xc`/`Xc16`, `Yc`/`Yc16`). The native class also charges its low byte's generated sets. Without `+mos-a16`, every hook returns the generated table.
- **Results.** Default output is identical to upstream at #321‑1: exit 0, 90 of 90 inputs in both modes. At head, default output is identical to Phase A's. Native output at head against unchanged `321-16`:

    | Mode | Bytes | Change | Inputs larger / smaller |
    |---|---|---|---|
    | `+mos-a16` | 321,489 → 321,411 | −78 B | 16 / 4 |
    | `+mos-a16,+mos-xy16` | 300,012 → 299,850 | −162 B | 15 / 5 |

    - Lit: 132 pass and 1 unsupported at #321‑1; 143 pass and 1 unsupported at head.
    - `-verify-machineinstrs`: the same results as unchanged head.
    - bsnes‑jg: 23 of 23 runtime legs pass, with the same four pre-existing llc failures as head.
- **Rejected.**
    - Borrowing only the low byte's generated sets (−10 B / −147 B) clears the `+mos-a16` bar by just 10 B.
    - Charging the appended sets with native registers only is almost as good (−53 B / −196 B), with larger per-input regressions.
    - Hand-encoding head's 14 sets in native mode would reproduce head exactly, but gives up the net win and adds a large table.
- **Open for the application dispatch.**
    - Placement: in #321 commit 1, the appended sets already move 8‑bit `+mos-a16` code before any native codegen exists (+1,491 B against upstream mosw65816, −1,711 B against unchanged #321‑1). The alternative is to put the hooks in the first commit that selects `Ac16`.
    - Per-input growth under the shrinking totals: packrec grows by up to +86 B.

## Decision after the T4 design

**2026‑09‑30.** The user decided:

1. **Bar: totals.** The native result of −78 B (`+mos-a16`) and −162 B (`+mos-a16,+mos-xy16`) meets the bar. Per-input growth, up to +86 B for packrec, is recorded but does not block.
2. **Placement.** The TableGen `GeneratePressureSet = 0` flag goes in #321 commit 1, which keeps default output identical to upstream there. The `MOSRegisterInfo` hook overrides and the subtarget-taking constructor go in the first #321 commit that selects `Ac16`, so each commit's size change sits beside the code that causes it.
3. **Gate by optimization level first.** The user asked whether the change can be enabled or disabled per optimization setting, and made that question standing (project [CLAUDE.md](../../CLAUDE.md), lesson 4). Every measurement above is `-O2` bytes. A T4 dispatch now measures `-Os`/`-Oz` size and `-O2` cycles, including a per-function gate through `getRegPressureSetLimit(MF, …)`. That is the only overridden hook that receives the function; the membership lists are fixed per subtarget. Its result goes in an "Optimization-level gating" section below. Application follows, with the placement in item 2.
4. **Gate: option (c), `-O3` only (user, 2026‑09‑30).** The measurement ruled out a per-function gate, because `RegisterClassInfo` caches the limits per subtarget. The chosen gate reads the TargetMachine's codegen level instead, which is the same for the whole module:
    - At `-O3` (Aggressive), the appended `A16`/`X16`/`Y16` sets are off. The native classes still charge their low byte's generated sets, which is the measured "sets off" form. It wins both objectives there: −429 B (`+mos-a16`) and −552 B (`+mos-a16,+mos-xy16`) against unchanged `321-16`, and about 0.2% fewer clocks than ungated.
    - At every other level the design is ungated. `-O2`, `-Os` and `-Oz` share one codegen level and differ only by per-function attributes, so they cannot be told apart soundly without a per-level subtarget.
    - If a link never reaches codegen at `-O3`, the gate does not fire and the ungated design applies, so a miss only forgoes a win.
    - The application dispatch confirms the gate on real `llc`, `clang` and LTO builds.

### Deferred

- Measure the `-O2` speed gate on the large programs before building it: a per-level subtarget (`optsize` in the `getSubtargetImpl` key) would win about 0.2% of clocks at `-O2`, measured on only 15 small sims; give dither, packrec and mvscrl a runtime harness and re-measure, and build the subtarget change only if the gain holds.

## Optimization-level gating

**2026‑09‑30.** Claude Code 2.1.285, model Claude Opus 5.5 (`claude-opus-5-5`), `high` reasoning effort (t4-opus-high agent definition); session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F). Evidence: [`opt-levels/`](../defects/evidence/2026-09-30-native-width-pressure-sets/opt-levels/README.md). Nothing is applied to the split series or `0002`.

- **Method.** `clang -O2`, `-Os` and `-Oz` all codegen at `llc -O2`; `-Os` adds `optsize` and `-Oz` adds `minsize optsize`. The frozen fixed set was already mixed: all 52 corpus IRs carry `optsize`, so the earlier "`-O2`" bytes were mostly `-Os` bytes. Sizes use the frozen set with only those attributes changed (opt's `forceattrs`; 584 of 585 definitions, the `optnone` one left alone), which keeps the exact inputs and isolates the codegen effect. Clocks use the fixed set's 17 corpus sims rebuilt from source at each level, measured as bsnes master clocks from `main` to the `corpus_result` write (Policy 0070's region). Each ROM runs twice, and every pair is identical. The ROM default is `-Os`: `dev/corpus.sh` and the demos pass `-Os`, and the SDK builds `MinSizeRel`.
- **Bytes, fixed set, against unchanged `321-16`.** A size gate turns the appended sets off at `-Os`/`-Oz`; a speed gate turns them off at `-O2`/`-O3`.

    | Level | `+mos-a16`: ungated / sets off | `+mos-a16,+mos-xy16`: ungated / sets off |
    |---|---|---|
    | `-Os` | **−78** / −10 B | **−162** / −147 B |
    | `-Oz` | **−78** / −13 B | **−162** / −150 B |
    | `-O2` | −84 / −29 B | −166 / −175 B |
    | `-O3` | −214 / −429 B | −296 / −552 B |

- **Master clocks, 15 sims (14 at `-O3`), against unchanged `321-16`.**

    | Level | Mode | Ungated | Sets off | Sets off vs ungated (sims faster / slower) |
    |---|---|---|---|---|
    | `-O2` | `+mos-a16` | −0.15% | −0.36% | −0.21% (8 / 3) |
    | `-O2` | `+mos-a16,+mos-xy16` | −0.15% | −0.34% | −0.19% (7 / 2) |
    | `-O3` | `+mos-a16` | +0.01% | −0.18% | −0.20% (6 / 2) |
    | `-O3` | `+mos-a16,+mos-xy16` | +0.02% | −0.17% | −0.18% (5 / 1) |

- **Default identity holds at every level.** At `Os`, `Oz`, `O2` and `O3`, upstream `06bc967d2668` and the design at #321‑1 give 90 of 90 identical inputs in both mos6502 and mosw65816. At head, the design equals the Phase A candidate, and the gate probe equals the design.
- **Gate mechanics.** Only `getRegPressureSetLimit(MF, …)` and `getRegPressureSetScore(MF, …)` see the function; set membership is fixed per subtarget, and subtargets are keyed on CPU and features only. The limit is also not per function in practice. `RegisterClassInfo` caches it, and clears the cache only when the register info, callee-saved list, allocation-order mask or reserved registers change. A trace shows that in a module with an `-O2` function and then an `optsize` function, only the first reaches the hook, and reversing the order reverses the decision. An unbounded limit also leaves the set visible to the scheduler's `CurrentMax` check. It still gave the same totals as removing the sets.
- **Decision by the project rule.**
    - **Size levels:** keep the design ungated. It wins at `-Os`, the ROM default, and at `-Oz`.
    - **Speed levels:** switching the appended sets off wins about 0.2% of clocks at `-O2` and `-O3`. But a limit gate is decided by the first function the cache sees. In a mixed module, such as the SDK's default `-flto` link of user code with `MinSizeRel` libraries, it can switch the sets off for `-Os` functions, which then grow. That breaks the conservative-gate rule.
    - A sound speed gate needs a per-level subtarget (`optsize` in the `getSubtargetImpl` key, as X86 keys on `prefer-vector-width`) or an equivalent. That is a design change, **escalated for a decision**.
    - Without it, the recommendation is the ungated design, unchanged. It is still faster than unchanged head at `-O2` (−0.15%) and flat at `-O3`.
- **Seen, not acted on.** Pre-existing `Remaining virtual register` aborts (perlin, satcast, domcol at `-Oz`, grid3d at `-O3`) appear in unchanged `321-16` and in every variant. They are the spill-hoist defect that patch `0033` fixes and `mos-clang` masks with `-disable-spill-hoist`. The split series does not carry that patch.

## Application

**2026‑09‑30.** Claude Code 2.1.285, model Claude Opus 5.5 (`claude-opus-5-5`), `high` reasoning effort (t4-opus-high agent definition); session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F). Evidence: [`final/`](../defects/evidence/2026-09-30-native-width-pressure-sets/final/README.md).

- **Code.** The T4 design plus the gate. `MOSSubtarget` builds `RegInfo(*this, TM.getOptLevel())`. `MOSRegisterInfo` sets `AppendNativePressureSets = OptLevel != CodeGenOptLevel::Aggressive` in its constructor and, when it is false, gives Ac16/Xc16/Yc16 their low byte's generated sets and appends nothing. That is exactly `memb1`, and every `-O3` row of the fixed set is byte-identical to it. `hasAccum16()` is still read lazily, because `RegInfo` is built before the subtarget parses its features.
- **Soundness.** The level is read once, when the subtarget is built. `RegisterClassInfo` caches the limits per register info, and the pressure trackers size their tables from `getNumRegPressureSets`, so the answer must not change during the subtarget's lifetime. The only codegen caller of `TargetMachine::setOptLevel` is SelectionDAGISel's per-function `optnone` override. MOS selects with GlobalISel with aborts enabled, so that override never runs. The LTO code generators set the level before the target machine exists. The same holds in `vendor/llvm-mos`. Nothing needed escalating.
- **Where it fires.**
    - It fires at `llc -O3`, at `clang -O3`, and in an LTO link that passes `-O3` (`-plugin-opt=O3`, so lld's LTO codegen level is `clamp(3, 2, 3) = Aggressive`).
    - The SDK's `-flto` link passes no `-plugin-opt=O` without an `-O` flag and `O2` for `-Os`, `-Oz` and `-O2`. lld then codegens at `Default`. The SDK, corpus and demo ROM builds therefore keep the appended sets, which is the accepted conservative outcome.
    - An `-O3` link codegens the whole merged module, including `MinSizeRel` library bitcode, without the appended sets.
- **Split series.** The flag is in #321‑1. The hooks, the constructor and the gate are in #321‑8, the first commit that creates `Ac16` virtual registers from IR. The series is rebuilt from the [split packet's](../pr-preparations/2026-09-30/split-320-321/README.md) `spec/`: the reference trees are the monolithic trees plus the change, `remap-spec.py` carries the stage specs across, and the messages of commits 1, 8, 12 and 13 are updated. All 20 commits build and pass. #321‑1 is default-identical to upstream, and the three downstream packets apply unchanged.
- **Downstream: built, measured, not landed.**
    - The same code, minus the `getLargestRegClassForRegPressureSet` override that the downstream LLVM lacks, was applied to `vendor/llvm-mos` and built (`llc` `9f9b74f9…`, `clang-23` `4c2d5ceb…`). The regenerated `0002` round-tripped, and its delta held only this change ([`0002-candidate-delta.diff`](../defects/evidence/2026-09-30-native-width-pressure-sets/final/downstream/0002-candidate-delta.diff)).
    - The MOS suites pass: 191 passed and 4 unsupported, including the new `-debug-only` test. `-verify-machineinstrs` gives the same results as before, and the gate fires in real `clang -O3` and `-O3` LTO builds.
    - But codegen of 262 SNES corpus and demo sources at `-Os` grows. Default mode goes from 2,315,097 to 2,328,524 B (+13,427 B, +0.58%; 207 larger, 35 smaller). `+mos-a16` gains 3,003 B and `+mos-a16,+mos-xy16` 3,070 B ([`codegen-summary.txt`](../defects/evidence/2026-09-30-native-width-pressure-sets/final/downstream/codegen-summary.txt)).
    - The cause is the downstream computed-carry scheduling (`0064`/`0067`, `-mos-carry-sched=always`), which the split does not carry. With `-mos-carry-sched=off`, the same change shrinks default code by 25,290 B, as in the split. With the old sets, carry scheduling saves 39,209 B; with upstream's sets it saves 492 B. So the carry model relies on the Ac16/Xc16/Yc16-derived sets ([`carry-sched-interaction.txt`](../defects/evidence/2026-09-30-native-width-pressure-sets/final/downstream/carry-sched-interaction.txt)). An 11-input sample is identical with the pressure consumers disabled, so the change acts only through pressure.
    - Landing it would regress default code, so `vendor/llvm-mos` was restored and `0002` is unchanged. The frozen candidate tools stay in `build/pressure-sets/final/downstream/`.
- **Tests** (in the split series; not in `0002` while downstream is held).
    - `native-width-default-pressure.ll` checks default mos6502 and mosw65816 code for `llvm.scmp.i16.i32`. It fails on the preserved baseline `321-01` and on unchanged `321-16`, and passes with the change.
    - `native-width-pressure-opt-level.ll` (`REQUIRES: asserts`) checks the scheduler's pressure sets at `-O2` and `-O3`. It fails on unchanged `321-16`, on the ungated design at `-O3`, and on #321‑7, and passes with the change.

## Verification

Run 2026‑09‑30 on the final binaries (evidence: [`final/`](../defects/evidence/2026-09-30-native-width-pressure-sets/final/README.md)).

1. The baseline comparison fails on the unchanged commit with the recorded signature.

    ```text
    $ bash docs/defects/evidence/2026-09-30-native-width-pressure-sets/tools/default-identity.sh \
        .../build/pressure-sets/llc/321-00 .../build/pressure-sets/llc/321-01 .../final/runs/baseline-rerun
    mos6502: 90 inputs (54 compile before), 72 identical, 18 asm differ, 0 object-only differ
    mosw65816: 90 inputs (78 compile before), 57 identical, 33 asm differ, 0 object-only differ
    RESULT: DIFFER (51 input/mode results changed)
    exit=1
    ```

    PASS: exit 1 with the recorded signature.

2. With the change, the generated pressure tables equal upstream `06bc967d2668`'s.

    ```text
    $ for n in 321-01 321-16 320-04 downstream; do cmp 321-00.txt $n.txt && echo ...; done   # tools/pressure-tables.sh output
    321-01: PressureNameTable/PressureLimitTable == upstream 06bc967d2668
    321-16: PressureNameTable/PressureLimitTable == upstream 06bc967d2668
    320-04: PressureNameTable/PressureLimitTable == upstream 06bc967d2668
    downstream: PressureNameTable/PressureLimitTable == upstream 06bc967d2668
    ```

    PASS: at #321‑1, #321‑16, #320‑4 and in `vendor/llvm-mos`, the tables are upstream's six sets (`MOSAsmParamRegClass`, `Pc`, `GPR_LSB`, `GPR_LSB_with_Pc`, `Anyi1`, `Anyi1_with_Pc`).

3. Default mos6502 and mosw65816 output on the fixed input set is byte-identical to upstream.

    ```text
    $ bash .../tools/default-identity.sh .../llc/321-00 .../final/llc/321-01 .../final/runs/default-321-01
    mos6502: 90 inputs (54 compile before), 90 identical, 0 asm differ, 0 object-only differ
    mosw65816: 90 inputs (78 compile before), 90 identical, 0 asm differ, 0 object-only differ
    RESULT: IDENTICAL
    exit=0
    $ grep ... final/sizes/summary.txt     # per level; final #321-1 vs upstream, final #321-16 vs Phase A candidate and design
    level Os upstream -> final01 RESULT: IDENTICAL exit 0 cand1 -> final RESULT: IDENTICAL exit 0 t4 -> final RESULT: IDENTICAL exit 0
    level Oz upstream -> final01 RESULT: IDENTICAL exit 0 cand1 -> final RESULT: IDENTICAL exit 0 t4 -> final RESULT: IDENTICAL exit 0
    level O2 upstream -> final01 RESULT: IDENTICAL exit 0 cand1 -> final RESULT: IDENTICAL exit 0 t4 -> final RESULT: IDENTICAL exit 0
    level O3 upstream -> final01 RESULT: IDENTICAL exit 0 cand1 -> final RESULT: IDENTICAL exit 0 t4 -> final RESULT: IDENTICAL exit 0
    ```

    PASS: identical at every level. The final #321‑1 `llc` (`e8130e32…`) is bit-identical to Phase A's `321-01-cand1`.

4. Native-mode (`+mos-a16`, `+mos-a16,+mos-xy16`) output on the same inputs has no unexplained growth.

    ```text
    $ grep -A2 'native bytes' final/sizes/summary.txt     # final #321-16 vs unchanged 321-16
    Os  a16: 80 inputs, bytes 321430 -> 321352 (delta -78), larger 16, smaller 4
        a16xy16: 79 inputs, bytes 299953 -> 299791 (delta -162), larger 15, smaller 5
    Oz  a16: 80 inputs, bytes 321320 -> 321242 (delta -78), larger 16, smaller 4
        a16xy16: 79 inputs, bytes 299842 -> 299680 (delta -162), larger 15, smaller 5
    O2  a16: 80 inputs, bytes 324317 -> 324233 (delta -84), larger 16, smaller 4
        a16xy16: 79 inputs, bytes 302699 -> 302533 (delta -166), larger 15, smaller 5
    O3  a16: 80 inputs, bytes 326054 -> 325625 (delta -429), larger 20, smaller 12
        a16xy16: 79 inputs, bytes 304371 -> 303819 (delta -552), larger 19, smaller 9
    native asm+obj: Os, Oz, O2 vs t4 180/180 identical; O3 vs memb1 180/180 identical (vs t4 119/180)
    ```

    PASS: the totals shrink at every level and equal the measured design (the ungated design below `-O3`, `memb1` at `-O3`). Per-input growth is the design's, recorded and non-blocking by the user's bar.

5. The split series still meets its gates after the change (per-commit build and suites; later packet patches apply).

    ```text
    $ cut -f1,4 evidence/series-evidence.tsv      # split packet; assertions build + MOS CodeGen/MC per commit
    321-01 PASS=134 · 321-02 135 · 321-03 137 · 321-04 139 · 321-05 140 · 321-06 141 · 321-07 142 · 321-08 144
    321-09 146 · 321-10 148 · 321-11 149 · 321-12 151 · 321-13 152 · 321-14 153 · 321-15 154 · 321-16 155
    320-01 161 · 320-02 163 · 320-03 164 · 320-04 165      (each UNSUPPORTED=1; base 132, MC top 160)
    $ cat p-3{21,20}-*/mos-warnings.txt | wc -l
    0
    TREE-INVARIANT OK: 0a9dad44a2d9^{tree} + 12 added llvm/test files
    TREE-INVARIANT OK: fa1928c8b9ca^{tree} + 13 added llvm/test files
    $ red-green.py evidence p-
    ... 11 earlier tests: FAIL on parent, PASS on own..end (OK)
    llvm/test/CodeGen/MOS/native-width-default-pressure.ll     321-01  PASS  PASS x21  CHECK
    llvm/test/CodeGen/MOS/native-width-pressure-opt-level.ll   321-08  FAIL  PASS x14  OK
    $ packet.sh (git am -3 of each packet's later patches, build, MOS CodeGen/MC)
    far-word 5-14: applied, PASS=174 UNSUPPORTED=1 · near-index recovery: applied, PASS=157 · 0063+0065: applied, PASS=158
    ```

    PASS. Every commit builds and passes, with no new MOS warnings. #321‑1, #321‑2 and #321‑4 through #321‑8 are default-identical to their parents. #321‑3 differs only in object mapping symbols, as before. The later packet patches apply without conflicts. `native-width-default-pressure.ll` passes on its upstream parent by design; its red is the unchanged #321‑1 and #321‑16 (step 7).

6. Downstream `0002` round-trips. The project differential and MOS suites pass. The defect record closes as `fixed`, and `dev/check-defect-evidence.py` accepts it.

    ```text
    $ dev/run.sh toolchain   (vendor/llvm-mos with the change; getLargestRegClassForRegPressureSet dropped: not in the downstream TRI)
    toolchain rc=0   clang-23 21:18:59 · llc 9f9b74f91eab29e1 · clang-23 4c2d5ceb7212deaa · lld 538a938bf6ba9703
    $ dev/regen-patch.sh
        wrote patches/llvm-mos/0002-321-accum16.patch (9645 lines, 54 files)
    RESULT: PASS — 0002 round-trips (MOS dir + focused tests == live vendor)
    # 0002 post-image delta vs origin: MOSRegisterInfo.cpp +139, MOSRegisterInfo.h +36 (before the hook was dropped),
    #   MOSRegisterInfo.td +6, MOSSubtarget.cpp, native-width-default-pressure.ll, native-width-pressure-opt-level.ll; no foreign file
    $ dev/run.sh lit
      Unsupported:   4 (2.05%)
      Passed     : 191 (97.95%)
    lit rc=0
    $ test-red-green.sh (native-width-default-pressure.ll)   baseline f1fa50a2: FAIL / FAIL   candidate 9f9b74f9: PASS / PASS
    $ verify-sweep-level.sh (fixed set, native modes)   O2: identical verifier results (2 failing before and after)
                                                         O3: identical verifier results (2 failing before and after)
    $ downstream-codegen.sh f1fa50a2 9f9b74f9   (277 SNES corpus + demo sources, same -Os frontend IR, llc -O2)
    default: {'changed': 251, 'identical': 11, 'llc-fail(base=1,cand=1)': 15}; bytes 2315097 -> 2328524 (+13427), larger 207, smaller 35
    a16: {'changed': 168, 'identical': 108, 'llc-fail(base=1,cand=1)': 1}; bytes 2441232 -> 2444235 (+3003), larger 148, smaller 13
    a16xy16: {'changed': 167, 'identical': 109, 'llc-fail(base=1,cand=1)': 1}; bytes 2431285 -> 2434355 (+3070), larger 143, smaller 12
    $ downstream-sizes-flags.sh default -mos-carry-sched=off | gated ; a16 -mos-carry-sched=off
    default flags[-mos-carry-sched=off]: 262 inputs, 2354306 -> 2329016 (-25290), larger 52, smaller 192
    default flags[-mos-carry-sched=gated]: 262 inputs, 2319044 -> 2328737 (9693), larger 186, smaller 56
    a16 flags[-mos-carry-sched=off]: 276 inputs, 2448479 -> 2450117 (1638), larger 139, smaller 25
    # 11 changed default inputs: identical with -disable-machine-licm -disable-machine-sink -enable-misched=false -enable-post-misched=false
    $ dev/run.sh corpus-a16   (candidate toolchain; host == default == +mos-a16 == +mos-xy16 on MAME and bsnes-jg; SPC700 IPL present, no MAME skips)
    progress snapshot: A16 [####################] 100% 83/83 complete | 0 remaining | 1819s | finished | PASS 83 FAIL 0 XFAIL 0
    corpus-a16 rc=0
    # vendor restored from 0001 + origin 0002 + standalone patches (only the four files differed), tests removed:
    $ dev/regen-patch.sh   ->   RESULT: PASS — 0002 round-trips; git diff patches/ (empty)
    $ dev/run.sh toolchain   (restored vendor)   ->   toolchain rc=0
    llc f1fa50a225c36607 · clang-23 254624ba26462f49 · lld c89b04cb2fb93cd3   (= the baseline tools, bit for bit)
    ```

    **FAIL, escalated.** `0002` round-trips and the MOS suites pass, but applying the change downstream grows default-mode code by 13,427 B (+0.58%) at `-Os`. The regression comes from the downstream computed-carry scheduling (`0064`/`0067`), whose savings (39,209 B with the old sets, 492 B with upstream's) rest on the Ac16/Xc16/Yc16-derived pressure sets. Landing the change would break the rule that a change must not regress default code, so `0002` is unchanged, `vendor/llvm-mos` is restored, and the record stays `confirmed` with its closure-ready run recorded ([`final/downstream/`](../defects/evidence/2026-09-30-native-width-pressure-sets/final/README.md#downstream)).

7. (Added 2026‑09‑30 for the user's gate.) The appended sets are off exactly at `CodeGenOptLevel::Aggressive`: at `llc -O3`, `clang -O3` and an `-O3` LTO link. The level cannot change after the subtarget is built. A default SDK link keeps the sets.

    ```text
    $ test-red-green.sh FileCheck <llcs>        # the two new tests' RUN lines, same inputs
                                   default 6502/65816   +a16 -O2 sets   +a16 -O3 no sets
    321-01 (preserved baseline)    FAIL / FAIL          FAIL            FAIL
    321-16 (unchanged head)        FAIL / FAIL          FAIL            FAIL
    321-16-t4 (ungated design)     PASS / PASS          PASS            FAIL
    p-321-07 (parent of #321-8)    PASS / PASS          FAIL            FAIL
    final 321-16                   PASS / PASS          PASS            PASS
    $ gate-real-builds.sh (downstream toolchain, nmitally_sim.c, +mos-a16)
    clang -O3 object code 72ff33ee02eebc1e | llc -O3 on its IR 72ff33ee02eebc1e | llc -O2 on its IR 5f411f0389f6e791
    -flto link -O3 (plugin-opt=O3): LTO object 18b5b6e985bb8442 | llc -O3 18b5b6e985bb8442 | llc -O2 599062bcb132e3c7
    -flto link -Os (plugin-opt=O2): LTO object 599062bcb132e3c7 | llc -O3 18b5b6e985bb8442 | llc -O2 599062bcb132e3c7
    baseline llc (before the change), same inputs: clang -O3 IR: -O3 5f411f0389f6e791 = -O2 5f411f0389f6e791;
      -O3 link precodegen: -O3 599062bcb132e3c7 = -O2 599062bcb132e3c7
    $ mos-clang -### link lines: (no -O) no plugin-opt=O · -Os/-Oz/-O2 -plugin-opt=O2 · -O3 -plugin-opt=O3
    $ git grep 'setOptLevel(' (06bc967d2668 and vendor): TargetMachine callers in codegen only SelectionDAGISel.cpp:268,293
      MOSTargetMachine.cpp:113-115 setGlobalISel(true); setGlobalISelAbort(GlobalISelAbortMode::Enable)
    runtime/summary.txt: O3 a16 final = memb1 -512,170 clk (-0.18%) vs 321-16; O3 a16xy16 final = memb1 -459,718 (-0.17%)
    ```

    PASS. On nmitally the baseline compiler's `-O2` and `-O3` code is identical, so the new `-O3` difference is the gate. `clang -O3` and an `-O3` LTO link produce exactly the `llc -O3` code, and an `-Os` LTO link produces exactly the `llc -O2` code. lld maps `-plugin-opt=O<n>` to codegen level `clamp(n, 2, 3)`, so the SDK's default link without `-O`, or with `-Os`, `-Oz` or `-O2`, never reaches `-O3` and keeps the appended sets. That is the accepted conservative outcome. No `setOptLevel` caller runs in the MOS pipeline, so the constructor-time read is sound. At `-O3` the clocks equal `memb1`'s. Logs: [`lto/`](../defects/evidence/2026-09-30-native-width-pressure-sets/final/lto/gate-real-builds.txt), [`test-red-green.log`](../defects/evidence/2026-09-30-native-width-pressure-sets/final/test-red-green.log).
