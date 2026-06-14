# Move the plan-deferral commit to its own branch (python-tui-lib)

**Date:** 2026-06-15
**Repo affected:** `~/SRC/python-tui-lib` (NOT llvm-mos-65816 — this plan just lives here)

## Goal

Relocate the plan-deferral auto-capture commit onto a dedicated feature branch so it
is independent of the unrelated md-history/md-to-html work it currently sits on top of.

## Context (verified state before the change)

```
python-tui-lib, branch: fix/md-history-footer-all-docs   (tracks origin/…, pushed at c2ff278)
  ● 9eb66c3  git-hooks: auto-capture plan deferrals into TODO   ← MINE — unpushed, move this
  ● df7dd15  fix(md-to-html): autolink bare http(s) URLs        ← not mine — unpushed, keep
  ● c2ff278  fix(md-to-html): escape backticks in heredoc       ← origin tip
```

- Local is **2 ahead** of `origin/fix/md-history-footer-all-docs` (`df7dd15`, `9eb66c3`).
- `9eb66c3` is on **no remote** → moving it rewrites only unpushed local history (safe; no force-push).
- Working tree has one **unrelated unstaged edit** (`docs/transcripts/2026-06-13-session.md`) to preserve.
- `feat/plan-deferral-audit` does **not** yet exist.

## Why

- The branch name (`md-history-footer`) no longer matches its contents (two unrelated features).
- If `fix/md-history-footer-all-docs` becomes a PR, my commit shouldn't ride along.
- Each feature can then be reviewed / merged independently.

## Target state

```
feat/plan-deferral-audit        →  ● 9eb66c3  (my commit, alone on top of c2ff278)
fix/md-history-footer-all-docs   →  ● df7dd15  (md work only; still 1 ahead of origin)
```

## Steps

1. Create the new branch pointer at the current commit (no checkout, working tree untouched):
   `git -C ~/SRC/python-tui-lib branch feat/plan-deferral-audit`
2. Drop my commit from the current branch tip, keeping `df7dd15`:
   `git -C ~/SRC/python-tui-lib reset --keep HEAD~1`
   (`--keep`, not `--hard`: aborts rather than clobbering the unstaged transcript edit; that edit is
   on a file untouched by either commit, so the reset preserves it.)

## Safety

- `9eb66c3` is unpushed → no published history is rewritten; no force-push to origin.
- `reset --keep` refuses to run if it would discard local working-tree changes, protecting the
  unrelated transcript edit.
- Fully reversible: `git checkout fix/md-history-footer-all-docs && git reset --keep 9eb66c3`
  (the commit also survives on `feat/plan-deferral-audit`).

## Verification

### 1. `feat/plan-deferral-audit` points at my commit (`9eb66c3`).
```
9eb66c3 git-hooks: auto-capture plan deferrals into TODO at commit time
```
**PASS.**

### 2. `fix/md-history-footer-all-docs` no longer contains my commit; tip is `df7dd15`.
```
df7dd15 fix(md-to-html): autolink bare http(s) URLs (GitHub-style)
c2ff278 fix(md-to-html): escape backticks in heredoc comments (bash command-sub leak)
```
**PASS.**

### 3. The unrelated working-tree edit (`docs/transcripts/…`) is preserved.
```
 M docs/transcripts/2026-06-13-session.md
```
**PASS.**

### 4. `9eb66c3` lives on exactly one local branch (`feat/plan-deferral-audit`).
```
  feat/plan-deferral-audit
```
**PASS.**

## Consequence — the feature is now isolated but NOT live

`python-tui-lib` still has `fix/md-history-footer-all-docs` checked out, which does **not** contain
`9eb66c3`. So the working-tree copies reverted:

```
$ ls scripts/audit-plan-deferrals.sh   →  ABSENT (lives only on feat/plan-deferral-audit)
$ grep -c audit-plan-deferrals git-hooks/pre-commit   →  0
```

Because git hooks resolve through `core.hooksPath = ~/SRC/python-tui-lib/git-hooks` (the **working
tree**), the auto-capture hook is **inactive** until a branch containing `9eb66c3` is checked out.
The seeded ledger commit (`eca2c8d` in llvm-mos-65816) is unaffected.

**To make it live again, pick one (user's call):**
- **Merge to mainline** — `git checkout main && git merge feat/plan-deferral-audit` (proper home for
  a shared-lib feature; makes it live for every SRC project). Recommended.
- **Check out the feature branch** — `git checkout feat/plan-deferral-audit` (live, but parks the
  md-history work and runs the shared lib off a feature branch).
- **Leave it** — keep it isolated for review; activate later by merging.
