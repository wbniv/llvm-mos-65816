---
name: keep-fork-branches-until-merged
description: "Don't propose deleting the user's fork branches; they keep them around until merged upstream"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ef32f1c7-f6a4-4854-a22a-787b91100a54
---

The user keeps `wbniv/llvm-mos` fork branches around until the related work is merged upstream — as a
habit / safety net — and does NOT want agents auto-proposing deletion of them. Said this when a hygiene
note flagged `revert-540-fix/soft-stack-spill-crash` (a revert of already-merged upstream PR #540) as
"stale cruft, safe to delete."

**Why:** Branch cleanup reads as tidy but the user values having the branch as a recoverable reference
until they're satisfied the work has landed upstream; a deleted fork branch is friction to recreate.

**How to apply:** Don't list fork-branch deletion as a recommended hygiene action. Leave them. Only delete
on an explicit, case-by-case request from the user. Docs that track upstream contribution state should
frame leftover fork branches as "retained by preference," not "stale / safe to delete"
(`docs/upstream-contribution-status.md` updated 2026-06-21 to reflect this).

**Keeping the branch ≠ keeping its bulky duplicated files.** Retaining a branch/worktree as a recoverable
reference does NOT mean hoarding its on-disk `build/`+`vendor/` dupes — those are restorable and are the
majority of disk usage, so reclaim them (the branch ref + tracked diff is the cheap, recoverable part).
See [[worktree-teardown-keep-durable-artifacts]] for the safe-reclaim mechanics and `build/`-vs-`vendor/`
safety asymmetry.
