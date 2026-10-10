# Repeatable compiler re-pin

Requested October 10, 2026. Implement a host command, `task upstream:repin`, which fetches the current upstream compiler `main`, ports the active bootstrap patches, validates an isolated compiler, and only then updates the tracked pin and active patches. Keep the tracked pin and patch stack unchanged during implementation; the subsequent user authorization permits an isolated preparation against the real stack. Compiler #584 is already supplied by the current `f24948c7d1a4` pin; its merge alone requires no new retirement.

Plan and implementation: OpenAI Codex 0.162.1, model `gpt-6.1-sol`, medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`. Existing patch authorship and dated validation records must be preserved.

## Command contract

- Read the actual `apply_patch` calls in `dev/toolchain.sh`, including their order, include filters and reduced context. Do not glob every patch: some are review artifacts or already folded into aggregates.
- Snapshot the old pin, bootstrap script, regeneration script and active patch bytes in a new `.scratch/` run directory. Refuse dirty pin/patch/bootstrap inputs and retain all run artifacts on failure. Shared vendor trees, installed binaries and published PRs are untouched.
- Fetch old and target revisions into an independent repository. Reconstruct each active patch as a commit at the old pin, then replay those commits onto the fetched target using Git's three-way merge. A patch becoming empty is upstream-supplied for this replay, not evidence that a historical compiler defect is fixed. Preserve any excluded hunks in path-filtered patch artifacts.
- Stop on conflicts and print a resume command. Resolve files and stage them in the retained candidate checkout, then resume the same run. Do not guess resolutions, reset shared work, or silently discard a conflicting patch.
- Export the replayed diffs, preserve patch headers, and independently apply them to the new pristine base. Require identical Git trees. Remove empty standalone applications from the bootstrap and regeneration lists; retain original artifacts in the run snapshot. Keep aggregate placeholders when needed by regeneration.
- Build the candidate using `dev/container.sh`, `dev/toolchain.sh` and `dev/lit.sh`, with isolated source/build/install paths. Gate publication of the pin on the build and MOS CodeGen/MC suites. Record exact source trees, commands, input/output hashes and retired applications; this is not a new SNES runtime or performance validation.
- Recheck tracked inputs before publication. Back up every changed file, install the candidate patches and scripts, and write the pin last. Roll back tracked writes if publication fails. Do not commit or push automatically.

## Interfaces

`task upstream:repin` performs the validated update. `task upstream:repin -- --prepare-only` fetches and prepares a verified candidate without building or changing tracked files. `task upstream:repin -- --continue <run-directory>` resumes conflict resolution or validation. `--upstream <URL-or-local-repository>` selects a mirror, and `--ref <branch>` defaults to `main`; record the resolved commit once and reuse it on resume.

After a successful update, inspect the receipt and diff, review affected current summaries with `dev/docs-deps.py --impact`, refresh generated views and the inventory, and record substantive document reviews before committing. The command creates a merge/replay receipt, but cannot infer new maintainer review state or certify prose merely to clear dependency checks.

## Verification

Exercise local upstream fixtures with an independent change, an upstream-supplied patch, partially supplied aggregate changes, path-filtered artifacts, a real conflict and resume, a failing validation gate, and changed inputs before publication. Verify the original pin and patch bytes remain unchanged whenever replay or validation fails. Check that the independently reapplied tree matches the candidate and that retired standalone calls disappear from both bootstrap and regeneration lists. Parse the Task command and check script syntax. The fixture suite uses local Git repositories and a mock compiler gate. Separately exercise the real compiler stack with `--prepare-only`, which fetches upstream without publishing the pin or patches.

## Completion evidence

**PASS:** all 12 local Git fixture tests and the real-stack prepare-only replay/tree-equality checks. The real compiler build and MOS lit gates remain pending until a pin update is requested.

Implemented in `dev/repin-llvm-mos.py`, with Task commands in `Taskfile.yml` and 12 passing local Git fixture tests in `dev/test-repin-llvm-mos.py` (`task upstream:repin:test`). The tests cover partial and whole retirement, excluded hunks, conflict resolution and resume, failed validation and retry, dirty or changed inputs, changed exports or verification source, empty aggregates, exact baseline cache reads, executable modes and publication rollback. Their container runner is a mock: this validates the workflow, not a compiler build.

The authorized real-stack preparation replayed all 51 active applications from `f24948c7d1a4b9f162d4d0192ccceecab1e441ff` onto the fetched `main` at `0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63`. No whole application became empty. Independent application of the exported patches produced the identical full Git tree, `065937b873d8229d96932f59f0141724ccd0c9a9`. All 54 input hashes remained unchanged. The run is retained in `.scratch/repin/20261010T033430Z-ardhs7qy`; [the dated validation record](../test-results/repin/2026-10-10/validation.json) retains input/export hashes, implementation identities and the compressed command log.

Preparation uses sparse checkouts of patch paths and read-only exact-commit baseline blob caches; 76 baseline blobs were available locally in this run. Full source checkout is deferred to the isolated build gate. Real compiler build, MOS lit suites, runtime checks and publication were deliberately not run. A normal invocation still requires the build and MOS suites before changing the tracked pin. Earlier compiler rebase and defect records remain dated evidence.

## Next step

The command implementation and preparation checks are complete. The remaining real-stack validation is the isolated compiler build and MOS CodeGen/MC suites. When a pin update is requested, run `task upstream:repin` to fetch the then-current `main`, or resume the retained candidate with `task upstream:repin -- --continue .scratch/repin/20261010T033430Z-ardhs7qy` to validate the already frozen `0f031168a7cc` target. Both commands publish the pin and replayed patches only after those gates pass; a failed gate retains the run and leaves the tracked inputs unchanged.

After publication, inspect the receipt and patch diff, update the current upstream summaries for any retired applications, review their document dependencies, and commit the resulting pin update separately. The implementation commit contains the command and its preparation evidence; it does not advance the compiler pin. Existing upstream submission and SNES platform prerequisites continue to be tracked in [the pending-work document](../upstream-pending-work.md).
