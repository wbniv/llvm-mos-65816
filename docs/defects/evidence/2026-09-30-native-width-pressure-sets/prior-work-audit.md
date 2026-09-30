# Prior-work audit: native-width classes change default-mode pressure sets

Performed 2026‑09‑30 before any compiler change, per [the defect workflow](../../../howto-defect-evidence.md#reconcile-prior-work-before-opening-or-fixing-a-defect).
Auditor: Claude Code 2.1.285 (`claude --version` at audit time; t3-opus-med subagent of the planning session), model Claude Opus 5.5 (`claude-opus-5-5`), medium reasoning effort (agent definition); session [session_01HAKZG571yi9zqmAeWQZVtk](https://claude.ai/code/session_01HAKZG571yi9zqmAeWQZVtk).

## Searches

Run in the `wt/native-pressure-sets` worktree at `129ae82f` over `docs/`, `TODO.md`, `patches/`, `dev/`, Git history, and `vendor/llvm-mos/llvm/lib/Target/MOS`.

| Term | docs/defects | docs | TODO.md | patches | dev |
|---|---|---|---|---|---|
| `GeneratePressureSet` | 0 | 1 (this plan) | 1 (this item) | 0 | 0 |
| `PressureNameTable\|PressureLimitTable` | 9 | 10 | 0 | 0 | 0 |
| `getRegPressureSetLimit` | 10 | 10 | 0 | 0 | 0 |
| `MOSAsmParamRegClass` | 1 | 4 | 0 | 0 | 0 |
| `pressure.?set` | 15 | 24 | 2 | 0 | 0 |
| `default-mode` | 3 | 13 | 1 | 0 | 0 |
| `278,940\|282,418\|290,773\|293,975` | 0 | 1 (this plan) | 0 | 0 | 0 |

- Every `docs/defects` hit for the pressure-table terms belongs to [`mos-carry-scheduling-pressure`](../../mos-carry-scheduling-pressure.json) and its evidence directory. The other `pressure.?set` documents are the carry-scheduling plans, reviews and dashboard exports, plus this plan and TODO item.
- The `default-mode` hits outside this plan describe unrelated legality rules (shift64, ANYEXT), the historical-baseline labeling note and the split plan's per-commit rule. None records a default-mode size change from the native-width register classes.
- `git log --all -i -E --grep='pressure.?set|GeneratePressureSet'` finds only `804875c5` (triage of the 0064 carry gate inbox). Upstream history at `06bc967d2668` for `llvm/lib/Target/MOS` has no such commit.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.td` (downstream pin `8be0546128a5`) defines `Ac16`, `Xc16` and `Yc16` without `GeneratePressureSet`; it uses only `isPressureFineGrained` elsewhere.

## Related record

`mos-carry-scheduling-pressure` (status `workaround`) is about TableGen not propagating `isPressureFineGrained` into the initial pressure sets, which loses carry pressure; patch 0064 works around it in the MOS scheduler. That record concerns how existing sets model carry. This defect concerns opt-in classes adding sets that change default-mode heuristics. The mechanisms and the repairs differ.

## Source and binary

- Split commit `a359c6b1d73c` ("[MOS] Model 65816 native-width registers and feature gates", #321‑1 on upstream `06bc967d2668`) adds `A16`/`X16`/`Y16`, their high bytes `B`/`XH`/`YH`, and the classes `Ac16`/`Xc16`/`Yc16`. Series head `c33eb63d65a3` (#321‑16) defines the same classes unchanged and generates the same pressure tables as `a359c6b1d73c`.
- The split agent's `build/split-320-321/evidence/321-01/{pressure-sets.txt,size-vs-base.txt,default-compare.txt}` (retained in `split-observation/`) first recorded the effect: 14 pressure sets instead of 6, and default-mode growth of +3,478 bytes on mos6502 and +3,202 bytes on plain mosw65816.
- Rebuilt `a359c6b1d73c` llc in an isolated build: SHA-256 `2422c068…df50`, identical to the split agent's deleted 321‑01 llc (recorded in `321-01/llc.sha256`). Its default-mode hash table is byte-identical to the split agent's `321-01/default-hashes.tsv`; the upstream llc (`2f5c1768…a39a7`) reproduces `321-00/default-hashes.tsv` byte for byte.
- Downstream: `build/llvm-mos/lib/Target/MOS/MOSGenRegisterInfoTargetDesc.inc` (SHA-256 `d5c3510d…d1fa`, unchanged since 2026‑07‑26 under `--write-if-changed`) has the same 14-entry `PressureNameTable`/`PressureLimitTable` as `a359c6b1d73c` (`tables/downstream-build-llvm-mos.txt`). The downstream compiler therefore carries the same pressure sets. Its default-mode byte effect has not been measured, because no downstream build without the classes exists. Phase B measures it.

## Decision

No structured record, report, patch or commit covers this. It is a distinct defect from `mos-carry-scheduling-pressure`, so this is a new canonical record with disposition `distinct_from_related`.
