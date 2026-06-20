#!/usr/bin/env bash
# .claude/hooks/guard-worktree-teardown.sh — PreToolUse(Bash) guard.
#
# Blocks a RAW `git worktree remove …` / `git branch -[dD] wt/…` that Claude tries to
# run, and redirects to dev/worktree-teardown.sh (which preserves the durable
# scripts/verdicts and reclaims only the vendor/+build/ dupes — the
# worktree-teardown-keep-durable-artifacts policy). The wrapper's OWN internal git
# removes are a subprocess of a non-matching Bash call, so this guard never fires on
# them — no bypass flag is needed.
#
# PreToolUse(Bash) fires on EVERY Bash call, so this early-exits fast for the 99% case.
# Wired via .claude/settings.json. Deny mechanism = JSON on stdout + exit 0 (the
# permissionDecisionReason is shown to the user and fed back to the model).
set -euo pipefail

# Read the PreToolUse payload; pass through cleanly if we can't parse it (never wedge
# unrelated Bash). jq is the parser; if absent, fall through to allow.
payload="$(cat 2>/dev/null || true)"
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -n "$cmd" ] || exit 0

# Match raw teardown ONLY at a command position (start, or after a ; && || | ( separator)
# so we block an actual `git worktree remove …` / `git branch -D wt/…` but NOT a mention
# of the string inside a quoted arg, an echo/grep, or a doc edit. `git[[:space:]][^;&|()]*`
# allows intervening opts (e.g. `git -C path worktree remove`). A determined bypass
# (`bash -c "…"`, aliases) still slips — the goal is preventing an ACCIDENTAL raw teardown.
if printf '%s' "$cmd" | grep -qE '(^|[;&|(])[[:space:]]*git[[:space:]][^;&|()]*worktree[[:space:]]+remove([[:space:]]|$)|(^|[;&|(])[[:space:]]*git[[:space:]][^;&|()]*branch[[:space:]]+-[dD][[:space:]]+wt/'; then
  reason='Raw worktree teardown is blocked. Use `dev/worktree-teardown.sh <slug>` instead — it merges the durable keepers (measure scripts, plans/verdicts) to main, hard-aborts if any tracked work is not yet on main, then removes the worktree and reclaims only the vendor/+build/ dupes (the worktree-teardown-keep-durable-artifacts policy; retain worktrees until upstream merge). Dry-run first: `dev/worktree-teardown.sh <slug> --dry-run`.'
  jq -n --arg r "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
fi

exit 0
