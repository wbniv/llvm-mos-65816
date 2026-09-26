# Preserve a defect so it remains diagnosable

Adopted during the 2026-09-25 older-report recheck, following the user's challenge
that failure to reproduce is not evidence of a fix. Workflow and documentation:
OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`), `xhigh` reasoning
effort. [Motivating investigation](investigations/2026-09-25-older-defect-recheck.md).

## Reconcile prior work before opening or fixing a defect

Do this before labeling a failure new, writing a new defect plan, or changing
compiler code. A user may be pointing at stale discovery prose for an existing
repair. The [far-memset revalidation](investigations/2026-09-26-far-memset-revalidation.md)
demonstrates that case: the June report still said "not attempted" although its
repair and passing results were recorded elsewhere the same day.

1. Search `docs/defects/*.json`, investigations, plans, original reports, TODO,
   and upstream summaries using both the diagnostic/symptom and the relevant
   pass, operation, or runtime symbol. Read matching follow-ups and resolutions.
2. Search Git history and `patches/llvm-mos/` for those symbols and changes.
   Inspect the implementation in `vendor/llvm-mos/`, including the large 0002
   patch: standalone artifacts may already be folded into it. Patch numbering
   and document dates do not establish absence from the compiler.
3. Identify the actual executable, source pin and dirty changes, and applicable
   patch contents. Distinguish "patch exists", "source contains it", "binary
   contains it", and "same input passes because of it". Keep uncertain links
   explicit; a file timestamp alone does not prove binary contents.
4. Choose the canonical record. Extend a matching record with dated observations
   and `additional_runs`, keeping its captured `baseline` unchanged. Create a
   record only for a distinct defect or to migrate a historical report that has
   no structured record. Explain the difference from related defects. Preserve
   earlier evidence and attribution instead of issuing a new discovery claim.
5. If a candidate repair already exists, compare the preserved trigger with and
   without that change when feasible. A current pass alone remains qualified.
   Report the result as revalidation of the existing change when established.
6. On closure, update the original report's visible current status and link it
   to the canonical record, then review dependent summaries and generated views.
   Register that original entry point as a maintained summary. Historical
   passages may remain verbatim under an explicit historical heading.

Useful starting searches (replace the concrete terms for each report):

```sh
rg -n -i 'far.?memset|wrong.bank|createFarMemLibcall|__memset_far' docs TODO.md patches dev
git log --all --oneline --grep='far.*mem' -i
git log --all -S'createFarMemLibcall' -- patches/llvm-mos
rg -n 'createFarMemLibcall|anyFarPointerOperand' vendor/llvm-mos/llvm/lib/Target/MOS
```

Every newly created structured record requires `prior_work`:

```json
{
  "prior_work": {
    "disposition": "historical_migration",
    "search_terms": ["far memset", "__memset_far", "createFarMemLibcall"],
    "related_records": [],
    "related_reports": ["docs/320-far-memset-miscompile.md"],
    "related_changes": ["a81874d", "patches/llvm-mos/0013-320-far-memops.patch"],
    "source_assessment": "Describe applicable changes present in the inspected source.",
    "binary_assessment": "Identify the binary and its verified or unknown relationship to that source.",
    "decision": "Explain why this is the canonical record and how related defects differ.",
    "evidence": {"path": "retained prior-work audit", "sha256": "64 lowercase hexadecimal digits"}
  }
}
```

Allowed dispositions are `new_defect`, `historical_migration`, and
`distinct_from_related`; the last requires a related canonical record and a
decision explaining the distinction. A duplicate sighting must update the
existing record. Related records/reports must exist in the staged tree. The
audit artifact retains the searches and findings; empty search results are valid
evidence, not a reason to invent a match.

The checker has an explicit list of the 14 records already present when this
requirement was adopted, including pending uncommitted records. Those may retain
their schema-1 evidence without a fabricated retrospective audit. New IDs must
provide the audit, and an audit cannot be removed once committed. This is a
structural gate: it checks that reconciliation is recorded, not that a search
was exhaustive or a semantic distinction is sound. Do not add new IDs to the
legacy list to clear the gate.

The tracked `.github/workflows/defect-evidence.yml` runs the checker and its tests
on pull requests and pushes to main without a compiler build or secrets. Local
hooks are enabled in this checkout (`core.hooksPath=.githooks`); Git does not
install them automatically in another clone. The workflow takes effect after
publication of the files. Making its status required for merging is a separate
repository-rules setting; do not claim branch protection merely because the
workflow exists.

Prior-work and canonical-record process, checker enforcement, and tests:
OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning
effort; verified session `01a0db16-f6a0-7e32-ada6-0c8098813933`.

## Capture a failing baseline before changing anything

Keep one immutable evidence directory per report. Do not overwrite it with a
later successful run. Record:

- The exact command, working directory, optimization level, target CPU/features,
  LTO setting, environment affecting the build, exit status, and full diagnostics.
- Compiler/tool versions and binary hashes, source revision and dirty diff,
  patch-stack hashes, and container image ID when used. Keep the failing binaries
  and their resource headers, or a preserved build/container that can reproduce
  them. A commit ID alone does not describe this project's dirty vendor tree.
- Original source, relevant headers, and preprocessed translation unit. Include
  generated files, linker inputs, SDK versions, and emulator configuration when
  the failure depends on them.
- The input to the failing compiler pass: LLVM IR for translation/legalization
  failures, and MIR with the necessary pass properties for register allocation
  or scheduling failures. Retain the original full input alongside reductions.
- For wrong-code failures, a deterministic host oracle, seed/input, expected and
  observed values, linked ROM/map hashes, and emulator logs. A verifier failure
  and a runtime mismatch are different observations; record each accurately.

First replay the captured command against the preserved baseline and confirm the
same failure signature. A reduction is useful only if it still triggers that
failure. A different crash, missing dependency, or skipped test is not a valid red
baseline. Document edits used to reconstruct a lost input; never label that input
as the exact original.

## Keep both the entry point and the mechanism under test

Retain a C integration reproducer for the real program and, where practical, a
small IR/MIR regression for the failing backend contract. A frontend optimization
can stop generating the problematic machine instruction without repairing its
backend implementation. The two tests cover different boundaries.

Check that the intended trigger is present: narrow count types, live operations,
inlined helpers, register pressure, addressing mode, or relevant pass sequence.
Compile a non-LTO object when LTO could mask the issue. Test the exact failing
configuration first; expand to the relevant feature/optimization modes afterward.
Runtime tests must execute the trigger and consume its result.

## Use evidence-based statuses

| Status | Required evidence |
|---|---|
| Confirmed | A retained input and identified compiler reproduce the recorded failure. |
| Not reproduced on build X | Specified inputs pass on X; historical validity and root cause remain open. |
| Workaround | A documented input/configuration change avoids the failure; no backend repair is established. |
| Fixed by change Y | The same regression fails on the captured baseline and passes with Y, with a causal explanation and relevant regression checks. |
| Invalid report | Evidence demonstrates an invalid input, unsound oracle, or other specific reporting error. Failure to reproduce alone is insufficient. |
| Contract clarification | Behavior is reproduced, but the required semantics have not been established. |

If a historical input passes today and the repair is unknown, bisect between the
captured failing build and a passing build when feasible. A change that merely
stops producing a failing MIR pattern should be described as such; keep the
backend regression open if that pattern remains valid and still fails.

Do not remove an issue or XFAIL solely because a replacement fixture passes.
Preserve the history and original attribution. Before retiring a reproducer,
identify the fix or record an explicit evidence-backed disposition and retain a
positive regression gate that checks the original behavior.

## Repository enforcement

`AGENTS.md` requires a `docs/defects/<id>.json` record for every new compiler
defect or status change. Existing historical documents can be migrated when
revisited; this does not retroactively certify their closure claims.
Investigations link to their records. Use `schema: 1`, an `id` matching the file
name, `title`, `summary`, `report` (repository path), `attribution` (list), and
`reproducer_origin` (`original`, `reduced`, `reconstructed`, or `unknown`).
`observations` is a nonempty list of `{ "path": "...", "sha256": "..." }`
artifacts retained in Git. The [current records](defects/) include examples
of qualified statuses; `not_reproduced` requires an explicit `unknowns` field.

Statuses are `confirmed`, `not_reproduced`, `workaround`, `fixed`, `invalid`, and
`contract_clarification`. Confirmed/workaround/fixed records require a `baseline`
run. A run records:

```json
{
  "command": "exact regression-runner command",
  "working_directory": "recorded working directory",
  "configuration": {"cpu": "mos6502", "optimization": "Os", "lto": false},
  "toolchain_location": "immutable archive location or preserved build recipe",
  "toolchain_sha256": "64 lowercase hexadecimal digits",
  "input": {"path": "retained regression input", "sha256": "its hash"},
  "log": {"path": "retained run log", "sha256": "its hash"},
  "exit_code": 1,
  "failure_signature": "specific text present in the baseline log"
}
```

The exit code belongs to the regression runner. For wrong-code defects, that
runner must compare the observed value with the oracle and fail on mismatch;
successful compilation alone is not a green correctness test. Populate the
configuration with every relevant target feature and pass setting.

`fixed` additionally requires `resolution.change`, `causal_explanation`,
`trigger_check`, a hashed `regression` artifact, and a `candidate` run. The hook
requires a nonzero baseline exit with the expected signature, a zero candidate
exit, identical input hashes/configurations, and different identified toolchains.
`invalid` requires an `invalidation_reason` supported by observation artifacts.

Enable the repository hooks in each clone with
`git config --local core.hooksPath .githooks`. Git does not activate tracked hooks
automatically. Check the setting with `git config --get core.hooksPath`.
The repository pre-commit hook runs `python3 dev/check-defect-evidence.py --staged`.
It checks index blobs, so concurrent unstaged edits cannot substitute evidence.
It rejects changed artifact hashes, missing evidence, deleted records, and edits
to a baseline already recorded in HEAD. Keep the baseline and append later
evidence to the same record. A separate record requires a distinct causal defect,
not merely another input, build, failure log, or reconstructed baseline.

Run `python3 dev/check-defect-evidence.py --worktree` before staging and
`python3 dev/test-defect-evidence.py` when modifying the checker. Do not bypass
the hook to obtain a closure. The checker verifies structural consistency and
retained artifact hashes; it cannot prove causal reasoning, truthfulness of
recorded executions, or availability of an external toolchain archive. Review
and replay remain required. It also does not infer defect statuses from arbitrary
Markdown prose: the agent instructions require the structured record and the
review must check that prose agrees with it.

## Review checklist

Before marking a defect fixed, the review record should answer four questions:

1. Can the captured baseline still reproduce the original failure?
2. Does the regression fail there for the expected reason and pass with the fix?
3. Does the test still exercise the failing operation, and does runtime evidence
   support any correctness claim?
4. Are the code, tests, patch bundle, installed compiler, docs, and attribution
   consistent with that verdict?

If the first two cannot be answered, keep the status qualified. Preserve new
passing evidence as a separate observation instead of replacing the red record.
