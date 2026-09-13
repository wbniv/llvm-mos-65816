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
