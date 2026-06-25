#!/usr/bin/env bash
# plan-index-reminder.sh — PostToolUse[Bash] hook.
#
# When a Bash call is a `git commit`, check whether that commit left a plan in
# docs/plans/ without a row in docs/investigations/plan-index.md, and if so feed
# the drift report (with paste-ready stub rows) back to the model as context.
#
# NON-BLOCKING by design: always exits 0 so it can never fail a commit. The plan
# index has hand-authored summaries, so this reminds + pre-computes the mechanical
# columns rather than auto-editing the file. Mirrors the audit-plan-deferrals
# "capture for triage" pattern.
#
# Reads the PostToolUse JSON payload on stdin (.tool_input.command).
set -euo pipefail

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

input=$(cat 2>/dev/null || true)

# Only act on `git commit` invocations.
cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null <<<"$input" || true)
[[ -n "$cmd" ]] || cmd="$input"
grep -qE 'git[[:space:]]+(-[^[:space:]]+[[:space:]]+)*commit' <<<"$cmd" || exit 0

proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || true)}"
checker="$proj/dev/check-plan-index.sh"
[[ -n "$proj" && -x "$checker" ]] || exit 0

report=$("$checker" 2>/dev/null) && exit 0   # exit 0 from checker == in sync, nothing to say

# Drift: surface the report to the model as additional context (and to the user).
msg="plan-index.md is behind after this commit — update it (summaries are hand-authored):

$report"
printf '%s\n' "$msg" >&2
if command -v jq >/dev/null 2>&1; then
    jq -cn --arg c "$msg" \
        '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
fi
exit 0
