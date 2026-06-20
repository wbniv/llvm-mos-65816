#!/usr/bin/env bash
# dev/test-worktree-teardown.sh — regression test for the worktree-teardown enforcement
# (the PreToolUse guard .claude/hooks/guard-worktree-teardown.sh + dev/worktree-teardown.sh).
#
# Pipes synthetic PreToolUse payloads through the guard and asserts the deny/passthrough
# matrix, then exercises the wrapper's --dry-run durability gates. Read-only: removes no
# worktree (the wrapper is run only with --dry-run). Run: dev/test-worktree-teardown.sh
set -euo pipefail

usage() { echo "Usage: dev/test-worktree-teardown.sh   # assert the worktree-teardown guard hook + wrapper gates"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
H=".claude/hooks/guard-worktree-teardown.sh"
[ -x "$H" ] || { echo "FATAL: no guard hook at $H"; exit 1; }

pass=0; fail=0
check() { # <desc> <expect DENY|PASS> <command-string>
  local desc="$1" expect="$2" cmd="$3" payload out got
  payload="$(printf '%s' "$cmd" | python3 -c 'import json,sys;print(json.dumps({"tool_input":{"command":sys.stdin.read()}}))')"
  out="$(printf '%s' "$payload" | bash "$H" 2>&1 || true)"
  got=PASS; printf '%s' "$out" | grep -q '"permissionDecision": *"deny"' && got=DENY
  if [ "$got" = "$expect" ]; then printf '  \xe2\x9c\x93 [%s] %s\n' "$got" "$desc"; pass=$((pass + 1))
  else printf '  \xe2\x9c\x97 expected %s got %s: %s\n' "$expect" "$got" "$desc"; fail=$((fail + 1)); fi
}

echo "=== guard hook: deny (real teardown) vs passthrough (everything else) ==="
check "raw remove ../foo"            DENY 'git worktree remove ../llvm-mos-65816-foo'
check "raw remove --force path"      DENY 'git worktree remove --force /home/x/wt'
check "cd y && remove z"             DENY 'cd /tmp && git worktree remove /tmp/z'
check "git -C path worktree remove"  DENY 'git -C /repo worktree remove /wt'
check "branch -D wt/foo"             DENY 'git branch -D wt/321-foo'
check "branch -d wt/foo"             DENY 'git branch -d wt/321-foo'
check "worktree list"                PASS 'git worktree list'
check "worktree add"                 PASS 'git worktree add ../wt main'
check "git status"                   PASS 'git status'
check "branch -D (not wt/)"          PASS 'git branch -D feature/foo'
check "mention in echo"              PASS 'echo "to clean up run git worktree remove foo"'
check "mention in grep"             PASS 'grep "git worktree remove" docs/x.md'
check "the wrapper itself"           PASS 'dev/worktree-teardown.sh 321-track-a --dry-run'

echo ""
echo "=== wrapper: -h + bad-arg handling ==="
if dev/worktree-teardown.sh -h >/dev/null 2>&1; then echo "  ✓ -h exits 0"; pass=$((pass + 1)); else echo "  ✗ -h"; fail=$((fail + 1)); fi
badout="$(dev/worktree-teardown.sh wt/does-not-exist --dry-run 2>&1 || true)"
if printf '%s' "$badout" | grep -q "FATAL: no worktree"; then echo "  ✓ bad arg → FATAL (exit 1)"; pass=$((pass + 1)); else echo "  ✗ bad arg"; fail=$((fail + 1)); fi

echo ""
echo "(For a live durability-gate demo, run on a real worktree:"
echo "   dev/worktree-teardown.sh <slug> --dry-run   # PASS if all tracked work is on main, else ABORT listing it)"
echo ""
echo "=== RESULT: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
