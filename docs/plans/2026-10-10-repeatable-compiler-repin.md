# Repeatable compiler re-pin

Requested October 10, 2026. Implement a host command, `task upstream:repin`, which fetches the current upstream compiler `main`, ports the active bootstrap patches, validates an isolated compiler, and only then updates the tracked pin and active patches. The initial implementation and preparation kept the tracked pin unchanged; the subsequent user authorization permits full validation, publication, documentation, commit and push. Compiler #584 is already supplied by the initial `f24948c7d1a4` pin; its merge alone requires no new retirement.

Plan and implementation: OpenAI Codex 0.162.1, model `gpt-6.1-sol`, medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`. Existing patch authorship and dated validation records must be preserved.

## Command contract

- Read the actual `apply_patch` calls in `dev/toolchain.sh`, including their order, include filters and reduced context. Do not glob every patch: some are review artifacts or already folded into aggregates.
- Snapshot the old pin, bootstrap script, regeneration script and active patch bytes in a new `.scratch/` run directory. Refuse dirty pin/patch/bootstrap inputs and retain all run artifacts on failure. Shared vendor trees, installed binaries and published PRs are untouched.
- Fetch old and target revisions into an independent repository. Reconstruct each active patch as a commit at the old pin, then replay those commits onto the fetched target using Git's three-way merge. A patch becoming empty is upstream-supplied for this replay, not evidence that a historical compiler defect is fixed. Preserve any excluded hunks in path-filtered patch artifacts.
- Stop on conflicts and print a resume command. Resolve files and stage them in the retained candidate checkout, then resume the same run. Do not guess resolutions, reset shared work, or silently discard a conflicting patch.
- Preserve hashed patch artifacts referenced by structured defect records byte for byte. Publish their active forms as new `-vendor` copies and update bootstrap/regeneration names; refuse an existing destination instead of overwriting it.
- Export the replayed diffs, preserve patch headers, and independently apply them to the new pristine base. Require identical Git trees. Remove empty standalone applications from the bootstrap and regeneration lists; retain original artifacts in the run snapshot. Keep aggregate placeholders when needed by regeneration.
- Before a full checkout, retain copies of available local immutable Git objects inside the run, excluding external alternates. Use relative paths between retained object stores so host and container mounts resolve the same objects. If the target still has missing objects, fetch a complete shallow pack for that exact commit with a five-minute low-speed timeout. This avoids a server request listing tens of thousands of missing blobs.
- Build the candidate using `dev/container.sh`, `dev/toolchain.sh` and `dev/lit.sh`, with isolated source/build/install paths. Gate publication of the pin on the build and MOS CodeGen/MC suites. Record exact source trees, commands, input/output hashes and retired applications; this is not a new SNES runtime or performance validation.
- Recheck tracked inputs before publication. Back up every changed file, install the candidate patches and scripts, and write the pin last. Roll back tracked writes if publication fails. Do not commit or push automatically.

## Interfaces

`task upstream:repin` performs the validated update. `task upstream:repin -- --prepare-only` fetches and prepares a verified candidate without building or changing tracked files. `task upstream:repin -- --continue <run-directory>` resumes conflict resolution or validation. `--upstream <URL-or-local-repository>` selects a mirror, and `--ref <branch>` defaults to `main`; record the resolved commit once and reuse it on resume.

After a successful update, inspect the receipt and diff, review affected current summaries with `dev/docs-deps.py --impact`, refresh generated views and the inventory, and record substantive document reviews before committing. The command creates a merge/replay receipt, but cannot infer new maintainer review state or certify prose merely to clear dependency checks.

## Verification

Exercise local upstream fixtures with an independent change, an upstream-supplied patch, partially supplied aggregate changes, path-filtered artifacts, a real conflict and resume, a failing validation gate, and changed inputs before publication. Verify the original pin and patch bytes remain unchanged whenever replay or validation fails. Check that the independently reapplied tree matches the candidate and that retired standalone calls disappear from both bootstrap and regeneration lists. Parse the Task command and check script syntax. The fixture suite uses local Git repositories and a mock compiler gate. Separately exercise the real compiler stack with `--prepare-only`, which fetches upstream without publishing the pin or patches.

## Initial preparation evidence, October 10

**PASS at the initial preparation stage:** all 12 local Git fixture tests and the real-stack prepare-only replay/tree-equality checks. The subsequent full validation is recorded below.

Implemented in `dev/repin-llvm-mos.py`, with Task commands in `Taskfile.yml` and 12 passing local Git fixture tests in `dev/test-repin-llvm-mos.py` (`task upstream:repin:test`). The tests cover partial and whole retirement, excluded hunks, conflict resolution and resume, failed validation and retry, dirty or changed inputs, changed exports or verification source, empty aggregates, exact baseline cache reads, executable modes and publication rollback. Their container runner is a mock: this validates the workflow, not a compiler build.

The authorized real-stack preparation replayed all 51 active applications from `f24948c7d1a4b9f162d4d0192ccceecab1e441ff` onto the fetched `main` at `0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63`. No whole application became empty. Independent application of the exported patches produced the identical full Git tree, `065937b873d8229d96932f59f0141724ccd0c9a9`. All 54 input hashes remained unchanged. The run is retained in `.scratch/repin/20261010T033430Z-ardhs7qy`; [the dated validation record](../test-results/repin/2026-10-10/validation.json) retains input/export hashes, implementation identities and the compressed command log.

Preparation uses sparse checkouts of patch paths and read-only exact-commit baseline blob caches; 76 baseline blobs were available locally in this run. Full source checkout is deferred to the isolated build gate. At this initial preparation stage, the real compiler build, MOS lit suites, runtime checks and publication were deliberately not run. A normal invocation still requires the build and MOS suites before changing the tracked pin. Earlier compiler rebase and defect records remain dated evidence.

## Full validation and publication, October 10

The user authorized resuming the prepared candidate, validating and publishing the pin update, and then updating tracking docs, committing and pushing. Three initial full-checkout attempts failed with GitHub missing-object fetch timeouts before compilation. The command now retains local Git object stores without their external alternates, and fetches a complete shallow pack for the exact target if any objects remain missing. The complete pack downloaded successfully, compiler configuration and the isolated build passed. The local Git workflow suite now also checks that the retained cache supplies objects after the shared cache moves and that a thin repository with missing base objects is completed by the shallow-pack fetch. A direct container Git check also exposed host-absolute alternate-object paths. The command now uses relative paths within the run; a subsequent container check resolves the target commit without fetching, and the workflow suite adds relocation coverage. These preparation failures are infrastructure evidence, not new compiler defects.

**PASS:** the Release distribution build, installation and MOS suites passed: 204 tests passed, four unsupported, zero failures. Assertions and LTO were off. All 17 local Git workflow fixtures passed, including object-cache retention, missing-object pack recovery, relocation, protected-artifact preservation and vendor-destination collision refusal. The command published `0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63` and all 51 exported active patch artifacts after the independent replay produced the same tree. No whole application was retired.

The [full validation record](../test-results/repin/2026-10-10/full-validation.json) retains compiler identities, build configuration, exact source adjustment, compressed commands and published state separately from the initial preparation record. The [publication receipt](../upstream-status/repin-20261010T033430Z-ardhs7qy.json) retains all input/output hashes. Nonfatal compiler warnings remain in the log. No new runtime/performance result, assertions-build result, global compiler promotion, historical defect closure or upstream packet review is implied.

The staged defect-evidence check identified three closure artifacts needing preservation; the same audit also found a hashed historical far-memops artifact. The command now preserves 0013/0057/0058/0059 and publishes their rebased forms as `-vendor` copies. The final bootstrap was independently applied again and produced the identical tested tree. The original publication receipt and state remain dated evidence in the full validation record. No historical defect record or baseline was changed.

## Current follow-up

The authorized re-pin and validation are complete. Current tracking summaries now identify the new pin and this evidence; earlier compiler and upstream submission records retain their original destination revisions and measurements. Future re-pins use `task upstream:repin`; each invocation must pass its own build and MOS gates. Remaining upstream submission and SNES platform prerequisites stay in [the pending-work document](../upstream-pending-work.md).
