# 0029 standalone refresh — October 10, 2026

Status: current-base backend, frontend/C and MOS validation complete; ready for preview review. No upstream branch has been pushed and no PR has been posted. The user requested a preview before posting.

Attribution: OpenAI Codex CLI 0.162.0; model `gpt-6.1-sol`; medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`. Original diagnosis/implementation: OpenAI Codex CLI 0.155.1, model `gpt-6-astra`, xhigh reasoning effort. Original independent review/refinement: Claude Code CLI 2.1.278, model `claude-fable-5-1`, high reasoning effort. Earlier evidence and credits remain unchanged.

## Source and prior work

The [plan](../../../plans/2026-10-10-0029-upstream-refresh.md), [canonical defect](../../../defects/twoaddr-physreg-reschedule-exhaustion.json), [original investigation](../../../investigations/2026-09-16-mos-regalloc-out-of-registers-mixed-width-pointer-plus-call.md), and [prior-work audit](evidence/prior-work.json) reconcile the existing 0029 implementation with upstream. This is the first structured migration of that September defect, not a new discovery.

Exact upstream base: `0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63`, captured in [GitHub main metadata](evidence/upstream-main.json). Local compiler branch: `mos-twoaddr-physreg-reschedule-20261010`, commit `367513ea6a79`, in `.scratch/0029-20261010/source`. The [standalone diff](0029-llvm-mos.patch) changes only the two-address guard and its two MOS tests. The implementation is unchanged from the reviewed 0029 patch. The build's separate MOS.cmake project trim is excluded from the commit/diff.

Upstream `8068182dd6fb1a8efae0291db1d2462d29025cd1` removed the LiveVariables path. The current helper returns early without LiveIntervals, and the default pipeline supplies it. The refreshed MIR test separates no-analysis ordering from LiveIntervals ordering and allocates the LiveIntervals output. Starting before two-address on the original MIR skips the required analysis, so that old command is retained only as a no-analysis control.

## Current verification

Private source/build copies preserve the completed downstream re-pin evidence and installed compiler. Current builds are Release, MOS-only, assertions and LTO disabled. Source base, binaries, command arrays, logs and before/after MIR are retained in this packet.

| Check | Unpatched current backend | Standalone candidate |
|---|---|---|
| Exact retained IR, O0 | Pass | Pass |
| Exact retained IR, O1/O2/O3 with verifier | Register-exhaustion error in `stage` | All pass |
| No-analysis MIR order | Pass | Pass |
| LiveIntervals constrained order | FileCheck fails | Pass |
| Allocate LiveIntervals output | Exhaustion in accumulator and intervening-index cases | Pass |
| Legal move with spare class members | Permitted | Permitted |
| Complete MOS CodeGen/MC | Not run | 140 passed, one unsupported, zero failures |

Read [baseline runs](evidence/baseline-backend.json), [stronger baseline coverage](evidence/baseline-coverage-backend.json), [candidate runs](evidence/candidate-backend.json), and [MOS suite log](evidence/candidate-mos-lit.log). `check-backend.py` captures those commands using the private build mounts; phase names beginning with `baseline` select the preserved unpatched binaries. Do not rerun a captured baseline phase into the same evidence files.

The [current C matrix](evidence/current-c-matrix.json) passes for `mos6502` and `mosw65816`, O0/O1/O2/O3/Os/Oz, with and without the machine verifier: 24 candidate full-driver and 24 candidate-backend checks. The preserved unpatched backend passes four O0 checks and fails all 20 optimized checks with register exhaustion. The frontend is unchanged by this backend patch; each emitted IR input is fed to both retained backends with explicit split-pipeline identities. Do not describe that as a separately rebuilt pristine current-base Clang driver.

September full X86/ARM/AArch64 assertion-enabled suites and runtime measurements remain [dated validation](../../2026-09-22/0029-validation.md) and [independent review](../../2026-09-22/0029-claude-review.md). They have not been rerun on this current MOS-only build. The published [By-Value Boundary Trio demo](https://biohack.net/snes/byvaledge/) supports discovery provenance; its shipped source workaround is not current runtime evidence for the compiler repair.

## Build recipe and retained paths

The private source is `.scratch/0029-20261010/source`; the private build is `build/0029-20261010/compiler`. The copied CMake cache uses the completed re-pin paths, so every container command binds those two private directories onto `/work/.scratch/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw` and `/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw` respectively. The root mount remains `/work`. Shared re-pin source/build/install directories are not changed by these commands.

Run `dev/container.sh` with those two `-v HOST:CONTAINER` arguments, then `-- ninja -C /work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw -j2 llc opt FileCheck llvm-mc llvm-readobj llvm-objdump llvm-readelf count split-file not`. Baseline source is the exact upstream base plus [the project trim](evidence/baseline-source.diff); candidate source adds commit `367513ea6a79`. The [baseline CMake cache](evidence/baseline-CMakeCache.txt) records the configuration. Baseline binaries were copied and hashed before applying the guard.

Use the same container mounts for `python3 /work/docs/pr-preparations/2026-10-10/0029/check-backend.py <new-phase> coverage-twoaddr-reschedule-physreg.mir` and for the `llvm-lit` paths recorded in the suite log. The Clang target completed at `-j3`; `check-c.py` records the full original-C and split-pipeline matrix. A run must use new evidence names to retain captured baselines.

The upstream helper snapshot is documentary `.cpp.txt` evidence, with original source bytes and comments retained; it is not an additional compiler implementation.

The preserved prior-work audit uses the initial `.cpp` capture name. [Snapshot-location metadata](evidence/source-snapshot-location.json) maps it to the documentary `.cpp.txt` filename with identical SHA-256; no baseline source bytes were rewritten.

The current Clang validation build sets `CLANG_ENABLE_STATIC_ANALYZER=OFF` to omit the optional `--analyze` component. Ordinary C compilation remains enabled; the LLVM backend configuration and preserved baseline binaries are unchanged. [Build metadata](evidence/build-metadata.json) records the distinction.
