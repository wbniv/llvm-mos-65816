# Optimization-level gating of the native-width pressure sets

Canonical record: [`mos-native-width-pressure-sets`](../../../mos-native-width-pressure-sets.json). Plan section: [Optimization-level gating](../../../../plans/2026-09-30-native-register-pressure-sets.md#optimization-level-gating). The Phase A and [T4 design](../t4-design/README.md) evidence is unchanged; this directory only adds to it. Nothing was applied to the split series or `0002`.

Attribution: Claude Code 2.1.285 (`claude --version`), model Claude Opus 5.5 (`claude-opus-5-5`), `high` reasoning effort (t4-opus-high agent definition; not readable from session metadata); session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F).

## Question

The T4 design was measured only as `llc -O2` bytes. Does it win at each level on that level's objective (bytes at `-Os`/`-Oz`, master clocks at `-O2`/`-O3`)? If not, can the appended `A16`/`X16`/`Y16` sets be switched per function?

## How the levels reach codegen

`clang -O2`, `-Os` and `-Oz` all run codegen at `CodeGenOptLevel::Default` (`llc -O2`); `-Os` adds the `optsize` function attribute and `-Oz` adds `minsize` and `optsize`. `-O3` runs codegen at `llc -O3`. The frozen fixed set was already mixed: all 52 corpus IRs carry `optsize` (they are clang `-Os` output), and 5 of the 38 MOS CodeGen tests do. The earlier "−78 B / −162 B at `-O2`" was therefore mostly an `-Os` measurement.

Two input families, both with target attributes stripped as in the frozen set:

- **Sizes: the frozen set with only size attributes changed** (`tools/make-level-inputs.sh`). opt's `forceattrs` pass adds `optsize` (`Os`) or `optsize minsize` (`Oz`) to every definition, or removes both (`O2`, also used with `llc -O3` as `O3`). 584 of 585 definitions change; the one `optnone` function in lzss‑gallery is left alone, as clang would. This keeps the exact frozen inputs (the MOS tests have no source) and isolates the codegen effect of the level. Hashes: `level-inputs.sha256`.
- **Clocks: the 17 corpus sims of the fixed set rebuilt from source at each level** (`tools/runtime-clocks.py`), because a speed build needs `-O2`/`-O3` middle-end IR. The frontend is the installed project clang (sha256 in `runtime/identity.json`); the IR is kept in `runtime/ir/`.

The SDK and corpus ROMs build at `-Os`: `dev/corpus.sh` passes `-Os`, the `dev/*.sh` demos pass `-Os`, and the SDK's own CMake defaults to `MinSizeRel`. `mos-snes.cfg`/`mos-common.cfg` set no `-O` (clang's default is `-O0`) and add `-flto`.

## Tools (`tools/`)

- `make-level-inputs.sh LEVEL OUTDIR`: the per-level input sets.
- `sizes-level.sh`, `mode-hashes-level.sh`: the frozen `t4-design/tools/sizes.sh` and `tools/mode-hashes.sh` with an `OLEVEL` parameter for `llc -O` and `ulimit -v 2000000`. At `OLEVEL=2` on the original inputs, `sizes-level.sh` reproduces the frozen `t4-design/final-321-16/t4.native.tsv` byte for byte.
- `run-matrix.sh`: the job runner (`sizes/jobs.txt`, at most 4 parallel runs).
- `summarize.sh`: native sizes with the frozen `size-diff.py`, and default identity with the frozen `compare-hashes.py` (`sizes/summary.txt`, exit 0).
- `runtime-clocks.py`, `clocks-summary.py`: master clocks (`runtime/results.tsv`, `runtime/summary.txt`). The region is Policy 0070's, from `main`'s entry to the instruction that writes the expected `corpus_result`, measured by a freshly built bsnes‑jg cycle probe (`dev/build-cycle-probe.py`; `cycle-probe-identity.json`). Each ROM runs twice, and every passing pair is identical. The link uses the installed SDK at `-Os`, so library code is the same for every variant.

## Variants (`binaries.sha256`)

| Name | llc | Native modelling |
|---|---|---|
| `head` | unchanged `321-16` | head's generated sets |
| `t4` | `321-16-t4` | the chosen design, ungated |
| `gate1` | gate probe, `-mos-native-pset-gate-probe=1` | appended sets off when the function has `optsize` (size gate) |
| `gate2` | gate probe, `-mos-native-pset-gate-probe=2` | appended sets off when it lacks `optsize` (speed gate) |
| `memb1` | T4 `head-probe`, `-mos-native-pressure-probe=1` | no appended sets at all; the native class charges its low byte's sets (a membership gate's result) |
| `cand1` | `321-16-cand1` | Phase A flag only |

The gate probe (`gate-probe/gate-probe-full.diff`; its delta over the design is `gate-probe/gate-probe-vs-t4.diff`) is measurement-only: "off" returns an unbounded limit (`1 << 16`) from `getRegPressureSetLimit(MF, Idx)` for the appended sets. With the option at 0 it is asm-identical to `321-16-t4` (`sizes/Os.gate0.tsv` = `sizes/Os.t4.tsv`). After the probe build, `build/pressure-sets/source-head` was restored to `t4-design/change/change-321-16.diff` and rebuilt; `build-head/bin/llc` is again `0f3f63bf…054d` (`gate-probe/build-restore.log`).

## Results

### Bytes, fixed set, native modes, against unchanged `321-16` (`sizes/summary.txt`)

| Level | Mode | `321-16` bytes | `t4` (ungated) | gate off at this level | `memb1` |
|---|---|---|---|---|---|
| `-Os` | `+mos-a16` | 321,430 | **−78** (16 larger / 4 smaller) | −10 (21 / 11) | −10 |
| `-Os` | `+mos-a16,+mos-xy16` | 299,953 | **−162** (15 / 5) | −147 (19 / 9) | −147 |
| `-Oz` | `+mos-a16` | 321,320 | **−78** (16 / 4) | −13 (21 / 11) | −13 |
| `-Oz` | `+mos-a16,+mos-xy16` | 299,842 | **−162** (15 / 5) | −150 (19 / 9) | −150 |
| `-O2` | `+mos-a16` | 324,317 | −84 (16 / 4) | −29 (21 / 11) | −29 |
| `-O2` | `+mos-a16,+mos-xy16` | 302,699 | −166 (15 / 5) | −175 (19 / 9) | −175 |
| `-O3` | `+mos-a16` | 326,054 | −214 (17 / 3) | −429 (20 / 12) | −429 |
| `-O3` | `+mos-a16,+mos-xy16` | 304,371 | −296 (16 / 4) | −552 (19 / 9) | −552 |

"Gate off at this level" is `gate1` at `-Os`/`-Oz` and `gate2` at `-O2`/`-O3`. 80 (`+mos-a16`) and 79 inputs compile on both sides at every level. The limit gate and `memb1` give the same totals; their asm differs on one input/mode (lzdec `+mos-a16` at `-Os`, same size).

### Master clocks, 17 corpus sims from source (`runtime/summary.txt`)

Totals over the sims that pass under every variant: 15 at `-O2`/`-Os`/`-Oz`, 14 at `-O3`.

| Level | Mode | `321-16` clocks | `t4` vs `321-16` | appended sets off (`gate2` = `memb1`) vs `321-16` | off vs `t4`, sims faster / slower |
|---|---|---|---|---|---|
| `-O2` | `+mos-a16` | 311,199,424 | −454,668 (−0.15%) | −1,120,650 (−0.36%) | −665,982 (−0.21%), 8 / 3 |
| `-O2` | `+mos-a16,+mos-xy16` | 308,071,076 | −454,668 (−0.15%) | −1,050,942 (−0.34%) | −596,274 (−0.19%), 7 / 2 |
| `-O3` | `+mos-a16` | 279,331,808 | +41,656 (+0.01%) | −512,170 (−0.18%) | −553,826 (−0.20%), 6 / 2 |
| `-O3` | `+mos-a16,+mos-xy16` | 277,293,744 | +41,656 (+0.02%) | −459,718 (−0.17%) | −501,374 (−0.18%), 5 / 1 |

At `-O2` (`+mos-a16`), switching the appended sets off gains most on nmitally (−416k against `t4`), critters (−129k) and boids (−121k), and loses on grid3d (+34k), avalanche (+32k) and jt256 (+15k). Every run passes and is deterministic.

The same sims' object bytes at the size levels go the other way from the fixed set: at `-Os`, `t4` is 21,725 B and `gate1` 21,581 B against 22,044 B on `321-16` (`+mos-a16`); at `-Oz`, 21,285 B against 21,195 B. The sims are a small subset (nmitally alone is −168 B for `gate1` at `-Os` on the fixed set). Across the 80 fixed-set inputs, which include the large programs dither (+105 B for `gate1`), packrec (+101 B) and mvscrl (+80 B), the ungated design is smaller by 68 B (`-Os`, `+mos-a16`) and 15 B (`+mos-a16,+mos-xy16`).

### Default-mode identity per level (`sizes/summary.txt`)

At every level (`Os`, `Oz`, `O2`, `O3`), in both mos6502 and plain mosw65816, asm and object:

- upstream `06bc967d2668` (`321-00`) vs `321-01-t4`: 90 of 90 identical, `RESULT: IDENTICAL`;
- Phase A candidate `321-16-cand1` vs `321-16-t4`: 90 of 90 identical;
- `321-16-t4` vs the gate probe with that level's gate on: 90 of 90 identical.

## Gate mechanics, verified

- Only `getRegPressureSetLimit(const MachineFunction &, unsigned)` and `getRegPressureSetScore(const MachineFunction &, unsigned)` receive the function (`llvm/include/llvm/CodeGen/TargetRegisterInfo.h:762,785` at `c33eb63d65a3`). The score is only a tie-break rank in `GenericScheduler` (`MachineScheduler.cpp:3812`). `getNumRegPressureSets`, `getRegPressureSetName`, `getLargestRegClassForRegPressureSet`, `getRegClassPressureSets` and `getRegUnitPressureSets` take no function. `MOSTargetMachine::getSubtargetImpl` keys subtargets on `CPU + FS` only (`MOSTargetMachine.cpp:121-133`), so set membership is fixed per subtarget.
- **The limit is not per function in practice.** Every consumer reads it through `RegisterClassInfo::getRegPressureSetLimit`, which caches the target's answer in `PSetLimits` and clears the cache only when the subtarget's register info, the callee-saved list, the CSR allocation-order mask or the reserved registers change (`RegisterClassInfo.cpp:40-119`, `RegisterClassInfo.h:171`). `gate-probe/trace.txt` shows it: in a module with an `-O2` function followed by an `optsize` function (`gate-probe/mixed.ll`), the hook runs only for the first function, and the second inherits its answer; reversing the order (`mixed-rev.ll`) reverses the decision. A limit gate is therefore decided by whichever function of the subtarget RegisterClassInfo sees first. That is harmless in a uniform `-O2` or `-Os` module and wrong in a mixed one, and the SDK's default `-flto` link merges user code with the `MinSizeRel` libraries into one module.
- **An unbounded limit is not the same as no set.** The scheduler's `CurrentMax` pressure check still sees the appended sets. On these inputs the difference is one asm change with the same size.

## Conclusion

- **Size levels (`-Os`, the ROM default, and `-Oz`): keep the design ungated.** It is smaller than a size gate by 68 B / 15 B at `-Os` and 65 B / 12 B at `-Oz` on the fixed set.
- **Speed levels (`-O2`, `-O3`): the appended sets cost about 0.2% of master clocks.** Switching them off wins on the totals in both modes at both levels, with 1–3 sims slower. The ungated design is still faster than unchanged `321-16` at `-O2` (−0.15%) and is flat at `-O3` (+0.01%).
- **A sound speed gate needs a design change.** The only per-function hook, the limit, is cached per subtarget, so a limit gate can misclassify in either direction in a mixed module, which breaks the conservative-gate rule: an `-Os` function could lose the sets and grow. A gate that is reliably per function needs a per-level subtarget (adding `optsize` to the `getSubtargetImpl` key, as X86 keys on some function attributes) or an equivalent invalidation. That is escalated as a decision; nothing was changed here.

## Observed, not acted on

- Pre-existing `Remaining virtual register` aborts (`llc` exit −6) in `321-16` and every variant: perlin (`-O2`, `-O3`, `-Os`), satcast (all levels), domcol (`-Oz`), and grid3d (`-O3`, under `head`/`t4`/`gate1` but not with the sets off). This is the greedy spill-hoist scratch-vreg defect that patch `0033` fixes and `mos-clang` masks with `-disable-spill-hoist` ([upstream note](../../../../upstream-spill-hoist-scratch-vregs-pr.md)); the split series does not carry it. These runs use plain `llc`, as the frozen tools do.
