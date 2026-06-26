---
name: landing-on-hot-main-rebase-loop
description: main is a very hot shared tree; FF-merging a doc-touching commit races concurrent agents on TODO.md + plan-index.md — use an atomic rebase→resolve→--ff-only loop
metadata: 
  node_type: memory
  type: project
  originSessionId: beeb8e76-6dbf-4f73-8a17-a724ca5443ef
---

`main` in llvm-mos-65816 is worked by several agents at once — it advanced ~4 times (every
1–2 min, plus a mid-flight `git merge` by another agent) during one feature's landing. Almost
every commit appends to two coordination files — **`TODO.md`** (the `## Done` section) and
**`docs/investigations/plan-index.md`** (a table row + the footer count) — so *any* commit that
also touches them conflicts with concurrent ones, and a plain `rebase` then `git merge --ff-only`
loses the race (main moves between the two steps).

**The robust landing** (won on attempt 1 once atomic): do rebase → resolve → `--ff-only` in **one
bash call**, looping until it wins:
```
for attempt in 1..6:
  H=$(git -C $MAIN rev-parse HEAD)
  git rebase $H || { python3 resolver.py; git add TODO.md docs/investigations/plan-index.md; GIT_EDITOR=true git rebase --continue; }
  git -C $MAIN merge --ff-only <branch> && break   # immediate, no gap
```
Gotchas: **`git add -A` is hook-blocked** ("stage specific files") — list the two files. The
deterministic resolver: TODO `## Done` = keep both entries (mine on top); plan-index row = keep
both; plan-index **footer = take HEAD verbatim** (drop your own count edit — the count is
hand-maintained and self-heals on the next index refresh, which regenerates the commit column
from `git log --follow`, so a stale/orphaned SHA in your row also self-corrects). Don't do the
resolve across multiple tool calls — the think-time gap is exactly when main moves.

Other landing steps that DID matter: the new plan needs a `plan-index.md` row (a post-commit hook
flags drift); after editing `vendor/`, the regenerated **`0001`** must also be applied to **main's
vendor** (sync the one edited file) or a future `regen-patch-0001.sh` on main reverts your change;
then rebuild main's toolchain + re-run the gate. Worktree disposition follows the **2026-06-25
"collapse worktrees, get things on main"** user directive (see [[investigations-on-throwaway-branches]]):
land + `dev/worktree-teardown.sh <branch> --yes` once durable artifacts are on main, not retain.
