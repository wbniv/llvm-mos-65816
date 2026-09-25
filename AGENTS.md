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

# Defect evidence and closure

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
