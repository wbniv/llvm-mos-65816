---
name: worktree-teardown-keep-durable-artifacts
description: "On worktree teardown reclaim the 95%+ build/vendor dupes, but never delete the scripts/verdicts needed to reconstruct a test conclusion. Retain worktrees until upstream merge."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 747e735e-b2ab-491f-9a81-61b2273c4bb5
---

When eventually tearing down a feature/investigation worktree, reclaim the **95%+** that is pure
duplication — the `cp -a`'d `vendor/llvm-mos` + `build/` trees, generated ROMs/maps, `build/fuzz-triage/`,
and any other regenerable artifacts — **but never delete the core scripts used to determine things.** Keep
exactly what's needed to **reconstruct the test conclusion**: the measurement/audit harnesses
(`dev/measure-*.sh`, probe scripts) and the recorded verdicts (the plan's filled-in verification, a
results doc).

Also (companion policy): **retain worktrees until the work merges upstream** — do not tear a worktree down
merely because its durable artifacts already landed on `main` (user, 2026-06-21).

**Why:** the scripts ARE the reproducible evidence behind a measured win/loss/won't-do decision; deleting
them forces re-deriving the conclusion from scratch next time the question comes up. The build/vendor copies
are dupes of infrastructure that already exists on `main` (regenerable), so they are precisely the space to
reclaim — discarding them loses nothing.

**How to apply:** before `git worktree remove --force` + `git branch -D`, (1) merge/cherry-pick the durable
scripts + verdict docs to `main`; (2) confirm they're committed; (3) only then remove the worktree (reclaims
the ~11 GB of dupes). Mirrors docs/howto-feature-worktree.md §Disposition ("Keep → merge the durable
artifacts; throw the rest away"). See [[investigations-on-throwaway-branches]].
