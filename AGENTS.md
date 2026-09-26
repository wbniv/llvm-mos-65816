# Code comments

Explain the current contract, invariant, algorithm, or non-obvious reason in code
and test comments. Do not narrate previous implementations, past bugs, before/after
fixes, review conversations, or test-writing history there. Put that history and
validation evidence in commit messages, PR descriptions, or investigation docs.
Regression comments should explain the input, the behavior being checked, and why
the check matters today. This applies to source changes carried in patch bundles too.

The pre-commit hook runs `python3 dev/check-comment-history.py` against staged
changes. Fix flagged comments instead of bypassing the check. The check catches
common wording; passing it does not replace reviewing comments against this rule.

# AI attribution

Every AI attribution in commit messages, PR descriptions, review records, plans,
and investigation or defect records must name the actual agent/tool and version,
exact model name/ID (including its version), and reasoning effort level. A bare
"Codex" or "Claude" credit is insufficient. Verify these details from the session
metadata for the work being credited; do not substitute current defaults or copy
another agent's attribution. If a detail cannot be recovered, mark it unknown
instead of guessing. Preserve earlier contributors' recorded credits.

# Document dependencies

Follow [the document dependency workflow](docs/howto-document-dependencies.md)
for all documentation work. Before finishing a document change, run
`python3 dev/docs-deps.py --impact <changed-source>` and review the affected
current summaries, plans, PR drafts, previews, and follow-up records. Register
new generated views and maintained summaries in `docs/document-dependencies.json`.
Regenerate derivatives, record substantive summary reviews, and refresh the
inventory. Preserve dated evidence and earlier attribution; do not silently
rewrite historical records to match a current result.

The pre-commit hook runs `python3 dev/docs-deps.py --staged`. Stage the sources,
dependent outputs, review receipts, and inventory together. Do not acknowledge
an unreviewed document just to clear a stale-dependency check.

# Defect evidence and closure

Before treating a compiler failure as new or starting a fix, reconcile prior work:
search structured defects, original reports and follow-up plans, TODO/upstream
summaries, Git history, standalone patches, and the live compiler source. Search
both the symptom and the responsible operation/pass/runtime symbol. A standalone
patch may already be folded into `0002`; inspect its implementation and identify
the tested binary instead of relying on patch names or an old "open" status.
Record the reconciliation in `prior_work` as specified by the workflow below.

Use one canonical defect record per causal defect. A repeat sighting, another
input, or another build belongs in that record's observations/additional runs;
do not open a duplicate to preserve a new baseline. Keep earlier baselines
immutable. A separate record requires an explicit explanation of the distinct
mechanism or contract. Migrating an unstructured historical report into its first
structured record is not a new discovery. If an existing patch appears relevant,
test that hypothesis and qualify unknowns before claiming new work or a fix.

When resolving a report, update its original entry point as well as the canonical
record and dependent current summaries. Label retained historical status text as
dated evidence and link it to current status. Do not leave an unqualified "open"
or "fix not attempted" heading on a report whose repair is established elsewhere.

Follow [the defect evidence workflow](docs/howto-defect-evidence.md). A passing
reproduction attempt means **not reproduced on that build**, not fixed or invalid.
Do not close a historical report, remove its reproducer, or retire its XFAIL solely
because a current or reconstructed input passes. Preserve the original evidence
and attribution; label reconstructed inputs explicitly.

For every new compiler defect or status change, maintain a structured record in
`docs/defects/*.json` and link it from the investigation. Capture the exact source
and preprocessed input, failing compiler/toolchain identity, command/configuration,
diagnostics, and relevant IR/MIR before attempting a fix. Keep the failing baseline
immutable. If it cannot be recovered, record the missing evidence and leave the
root-cause status qualified.

Mark a defect **fixed** only when the same regression input fails on the preserved
baseline for the recorded reason and passes with an identified change. Require a
causal explanation and relevant regression/runtime checks; a frontend change that
hides a backend trigger does not prove the backend contract repaired.

The pre-commit hook runs `dev/check-defect-evidence.py --staged`: fixed records
require matching-input red/green evidence, toolchain identities, retained logs,
and a regression artifact. It verifies staged artifact hashes and protects
captured baselines from editing or deletion. Do not bypass it. Its structural
checks do not replace reviewing whether the test actually exercises the defect.
