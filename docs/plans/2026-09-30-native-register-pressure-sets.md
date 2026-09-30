# Keep the native-width registers out of default-mode register pressure

Status: Phase A done. The [T4 design](#t4-design) is done and measured, and its bar and placement are [decided](#decision-after-the-t4-design). Optimization-level gating is being measured before application; nothing is applied to the split series or `0002` yet. The T4 design followed the [decision](#decision-after-phase-a), after one escalation (see [Phase A results](#phase-a-results)). Canonical record: [`mos-native-width-pressure-sets`](../defects/mos-native-width-pressure-sets.json). The user approved this on 2026‑09‑30 ("Go ahead with it at T3?" — "yes"). The #320/#321 split found it: the first #321 commit only adds opt-in registers, but it changes default-mode code. On the split's fixed input set (38 MOS `.ll` tests plus 52 corpus IRs), mos6502 output grows 278,940 → 282,418 bytes (+3,478; 17 inputs larger, 1 smaller) and plain mosw65816 grows 290,773 → 293,975 bytes (+3,202; 24 larger, 8 smaller). Evidence: `build/split-320-321/evidence/321-01/{size-vs-base.txt,pressure-sets.txt,default-compare.txt}`, copied into the [split packet](../pr-preparations/2026-09-30/split-320-321/README.md).

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

## Verification

1. The baseline comparison fails on the unchanged commit with the recorded signature.
2. With the change, the generated pressure tables equal upstream `06bc967d2668`'s.
3. Default mos6502 and mosw65816 output on the fixed input set is byte-identical to upstream.
4. Native-mode (`+mos-a16`, `+mos-a16,+mos-xy16`) output on the same inputs has no unexplained growth.
5. The split series still meets its gates after the change (per-commit build and suites; later packet patches apply).
6. Downstream `0002` round-trips. The project differential and MOS suites pass. The defect record closes as `fixed`, and `dev/check-defect-evidence.py` accepts it.
