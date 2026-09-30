# Carry scheduling's pressure contract — evidence (2026‑10‑01)

Plan and conclusions: [`docs/plans/2026-10-01-carry-pressure-contract.md`](../../../plans/2026-10-01-carry-pressure-contract.md). Canonical record: [`mos-carry-scheduling-pressure`](../../mos-carry-scheduling-pressure.json).

Attribution: Claude Code 2.1.285, model Claude Opus 5.5 (`claude-opus-5-5`), `high` reasoning effort; session `310aee67-a99e-4b78-ba48-c560322fe80d`, agent `a0bbc91b2d36f234d`.

## Compilers

| Name | Path | `sha256` | What it is |
|---|---|---|---|
| base | `build/far-review-defects/candidate/llc` | `f1fa50a225c36607…` | Current downstream (also the shared `build/llvm-mos/bin/llc`) |
| up | `build/pressure-sets/final/downstream/llc` | `9f9b74f91eab29e1…` | Upstream native-width design applied downstream (2026‑09‑30) |
| x1–x4 | `build/carry-press-ir/llc/llc-x1` … `llc-x4` | see [`identity.sha256`](identity.sha256) | The upstream design plus hidden exploration options (x4's source: [`explore-MOSRegisterInfo.diff`](explore-MOSRegisterInfo.diff) against the upstream design); with default options they give "up"'s size for every input |
| candidate | `build/carry-press-ir/cand/llc` (with its `clang-23`, `lld`, `llvm-objdump`) | `6f303945beb17ab3…` | The upstream design plus [`candidate-accumulator-pressure-set.patch`](candidate-accumulator-pressure-set.patch), built in the worktree `/home/will/llvm-mos-65816-carrypress` |

Frontend IR: `build/carry-press-ir/{Os,Oz,O2,O3}/*.{default,a16,a16xy16}.ll`, from the installed `clang-23` `254624ba26462f49…` ([`tools/gen-ir.sh`](tools/gen-ir.sh)). The `-Os` IR equals `build/pressure-sets/final/downstream/codegen/ir/` byte for byte.

Exploration options (in `x3`/`x4` only): `-mos-default-gpr-psets=none|a|axy|axyj` and `-mos-native-gpr-psets=…` (appended groups per mode), `-mos-gpr-pset-a-limit=N` (default-mode `A16` limit), `-mos-gpr-pset-xy-limit=N`, `-mos-gpr-psets-first` (number the appended sets before the generated ones), `-mos-gpr-psets-low-score`, `-mos-native-borrow=false`, `-mos-default-gpr-psets-o3`, `-mos-native-gpr-psets-o3`.

## Files

- [`identity.sha256`](identity.sha256): every compiler above, and the frontend `clang-23` and `llvm-size` used.
- [`candidate-accumulator-pressure-set.patch`](candidate-accumulator-pressure-set.patch): the candidate as a standalone patch on top of `0002` with the upstream design (`MOSRegisterInfo.{h,cpp}`, the new `accumulator-pressure-set.ll`, and regenerated expectations for `char-stats.ll` and `native-width-default-pressure.ll`). It applies to the upstream-design sources and reproduces the built tree file for file. Not in `patches/llvm-mos/`: nothing is landed.
- [`explore-MOSRegisterInfo.diff`](explore-MOSRegisterInfo.diff): the exploration options, against the upstream design.
- [`default-decomposition.txt`](default-decomposition.txt): default mode, `-Os`, by pressure consumer (MachineLICM, MachineSink, scheduler pressure tracking, carry scheduling) and by appended set, limit and numbering.
- [`native-decomposition.txt`](native-decomposition.txt): the same for `+mos-a16`, and the native-residue variants.
- [`sizes.tar.gz`](sizes.tar.gz): every per-input size table behind the numbers (`exploration/`, `matrix/` for the four levels and three modes, `fixed/`, `verify/`), the configurations, the 277-source list and `ir.sha256` for all 3,324 IR files.
- [`clocks/`](clocks/): `results.tsv` (408 runs, all pass and deterministic), `identity.json` and `summary.txt`, from [`tools/runtime-clocks.py`](tools/runtime-clocks.py) (a copy of the 2026‑09‑30 harness that accepts several llc flags per variant).
- [`truchet-o3-xy16/`](truchet-o3-xy16/): the one verifier-only failure of the sweep, identical on the current downstream and the candidate, filed as a repeat sighting on [`mos-xy16-preserve-x-p-save`](../../mos-xy16-preserve-x-p-save.json).
- `test-red-green.log`, `lit.log`, `verify-summary.txt`, `corpus-a16.log`: the suite runs of plan step 6.
- [`tools/`](tools/): `gen-ir.sh`, `llc-sizes.sh`, `size-cmp.py`, `size-matrix.sh`, `matrix-summary.py`, `runtime-clocks.py`, `clocks-summary.py`.
