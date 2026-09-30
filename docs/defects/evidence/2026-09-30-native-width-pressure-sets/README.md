# Evidence: native-width classes change default-mode pressure sets

Canonical record: [`mos-native-width-pressure-sets`](../../mos-native-width-pressure-sets.json). Plan: [2026‑09‑30 native register pressure sets](../../../plans/2026-09-30-native-register-pressure-sets.md).

## Frozen tools (outside Git, by SHA-256)

All under `/home/will/llvm-mos-65816/build/pressure-sets/llc/`, read-only. Hashes are in `frozen-llc.sha256`.

| File | Source | SHA-256 |
|---|---|---|
| `321-00` | upstream llvm-mos `06bc967d2668` (copied from the split's frozen llc) | `2f5c1768…a39a7` |
| `321-01` | split #321‑1 `a359c6b1d73c`, unchanged (baseline) | `2422c068…df50` |
| `321-01-cand1` | `a359c6b1d73c` + `candidate-321-01/change.diff` | `e8130e32…7f3e` |
| `321-16` | split #321‑16 `c33eb63d65a3`, unchanged (copied from the split) | `b8006489…8e45` |
| `321-16-cand1` | `c33eb63d65a3` + the same change | `70595c35…bbf0` |

Rebuilding `a359c6b1d73c` here reproduced the split agent's deleted 321‑01 llc bit for bit, and rebuilding unchanged `c33eb63d65a3` reproduced `321-16` bit for bit (`head-321-16/unmodified-rebuild.sha256`). The builds are assertions-enabled Release builds in the dev container (image `sha256:d0aea4bc…c84b`): a full copy of `build/far-word-rebase/build` in `build/pressure-sets/build` (and `build-head`), with sources in private worktrees `build/pressure-sets/source` and `source-head`. The recipes are `tools/build-and-test.sh` and `tools/build-and-test-head.sh`.

## Input

The split's fixed set: 38 MOS CodeGen `.ll` tests at `06bc967d2668` plus 52 frozen corpus IRs with their target attributes stripped. It is frozen read-only at `build/pressure-sets/default-inputs/`, and `inputs.sha256` lists every file's hash. The manifest is the regression input.

## Layout

- `tools/`: the regression runner `default-identity.sh`, plus `mode-hashes.sh`, `compare-hashes.py`, `size-compare.sh` (derived from the split's `spec/` scripts), `pressure-tables.sh`, the build recipes and the run drivers.
- `baseline/`: red run, upstream vs unchanged `a359c6b1d73c`, with its build log and lit summary.
- `candidate-321-01/`: green run, upstream vs `a359c6b1d73c` + change, with the change, build log and lit summary.
- `native-321-01/`: `+mos-a16` and `+mos-a16,+mos-xy16` hashes and sizes, unchanged vs changed `a359c6b1d73c`.
- `head-321-16/`: the change on series head `c33eb63d65a3`: default vs upstream, default vs unchanged head, native vs unchanged head, lit, and the reproducibility rebuild.
- `tables/`: TableGen `PressureNameTable`/`PressureLimitTable` (and `*.full.txt` pressure sections) for upstream, the baseline, each candidate, series head, and the downstream `build/llvm-mos` build.
- `split-observation/`: the split agent's original 321‑01 observations.
- `prior-work-audit.md`: reconciliation before the change.

## Replay

```sh
cd /home/will/llvm-mos-65816-pressure
bash docs/defects/evidence/2026-09-30-native-width-pressure-sets/tools/default-identity.sh \
  /home/will/llvm-mos-65816/build/pressure-sets/llc/321-00 \
  /home/will/llvm-mos-65816/build/pressure-sets/llc/321-01 \
  /home/will/llvm-mos-65816/build/pressure-sets/runs/baseline   # exit 1: RESULT: DIFFER (51 ...)
```

Replace `321-01` with `321-01-cand1` for the green run (exit 0, `RESULT: IDENTICAL`).
