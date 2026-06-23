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
# Matching PARSES the command with Python shlex (quote-aware) and inspects only the
# COMMAND-POSITION tokens of each shell segment. So the phrase inside a quoted arg —
# a `git commit -m "…"` body, an echo/grep, a doc edit, even a `;` or newline INSIDE
# the quotes — never false-positives. (The prior line-based `grep` matched the phrase
# anywhere a line started with it, blocking legit commits/docs that merely mention it.)
# Best-effort only: a newline-separated `…<newline>git worktree remove`, a `bash -c "…"`,
# or an alias still slips — the goal is preventing an ACCIDENTAL raw teardown, not a
# determined one. The wrapper's durability gates remain the real protection.
#
# PreToolUse(Bash) fires on EVERY Bash call; this early-exits fast for the 99% case.
# Wired via .claude/settings.json. Deny = JSON on stdout + exit 0 (the
# permissionDecisionReason is shown to the user and fed back to the model). If python3
# is absent, the payload is empty, or the command can't be parsed, fail OPEN (never
# wedge unrelated Bash) and always exit 0 (a non-zero hook exit could itself block).
set -euo pipefail

payload="$(cat 2>/dev/null || true)"
command -v python3 >/dev/null 2>&1 || exit 0
[ -n "$payload" ] || exit 0

GUARD_PAYLOAD="$payload" python3 <<'PY' || true
import os, json, shlex

SEP = set(";&|()<>")                          # shell control / redirection punctuation
VALUE_OPTS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
              "--exec-path", "--super-prefix"}   # git global opts that consume a value

def segments(cmd):
    """Quote-aware split into command segments (operators end a segment)."""
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=";&|()<>")
    lex.whitespace_split = True
    seg, out = [], []
    for t in list(lex):                       # quoted strings collapse to ONE token
        if t and all(c in SEP for c in t):    # an operator token (&&, ||, |, ;, (, ), …)
            if seg:
                out.append(seg); seg = []
        else:
            seg.append(t)
    if seg:
        out.append(seg)
    return out

def is_teardown(seg):
    i = 0
    # skip a leading `env` and any VAR=val assignment prefix
    while i < len(seg) and (seg[i] == "env" or
                            ("=" in seg[i] and not seg[i].startswith("-")
                             and "/" not in seg[i].split("=", 1)[0])):
        i += 1
    if i >= len(seg) or (seg[i] != "git" and not seg[i].endswith("/git")):
        return False
    i += 1
    while i < len(seg) and seg[i].startswith("-"):    # skip git global options
        opt = seg[i]; i += 1
        if opt in VALUE_OPTS:
            i += 1                                     # …and the value it consumes
    if i >= len(seg):
        return False
    sub, rest = seg[i], seg[i + 1:]
    if sub == "worktree":
        for t in rest:                                 # first non-opt arg must be `remove`
            if t.startswith("-"):
                continue
            return t == "remove"
        return False
    if sub == "branch":
        deletes = any(o == "--delete" or
                      (o.startswith("-") and not o.startswith("--")
                       and ("d" in o[1:] or "D" in o[1:]))
                      for o in rest)
        targets_wt = any((not t.startswith("-")) and t.startswith("wt/") for t in rest)
        return deletes and targets_wt
    return False

try:
    cmd = (json.loads(os.environ.get("GUARD_PAYLOAD", "{}")).get("tool_input", {})
           or {}).get("command", "") or ""
except Exception:
    raise SystemExit(0)
if not cmd:
    raise SystemExit(0)
try:
    blocked = any(is_teardown(s) for s in segments(cmd))
except ValueError:
    raise SystemExit(0)                                # unbalanced quotes etc. -> fail open

if blocked:
    reason = ("Raw worktree teardown is blocked. Use `dev/worktree-teardown.sh <slug>` "
              "instead — it merges the durable keepers (measure scripts, plans/verdicts) "
              "to main, hard-aborts if any tracked work is not yet on main, then removes "
              "the worktree and reclaims only the vendor/+build/ dupes (the "
              "worktree-teardown-keep-durable-artifacts policy; retain worktrees until "
              "upstream merge). It accepts throwaway/<slug> too (disposable; --yes still "
              "required). Dry-run first: `dev/worktree-teardown.sh <slug> --dry-run`.")
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason}}))
PY
exit 0
