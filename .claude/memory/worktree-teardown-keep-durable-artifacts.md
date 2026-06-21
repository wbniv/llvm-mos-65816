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

**Retaining a branch/worktree ≠ keeping its bulky duplicated files on disk** (user, 2026-06-21). The
recoverable reference is the *branch ref + the worktree's tracked diff* — those are cheap. The
`build/` + `vendor/` copies are the dominant disk cost and are restorable on demand, so reclaim them even
on a worktree you're keeping, *without* removing the worktree itself. Measured 2026-06-21:
**~62 GB of ~66 GB** across 6 worktrees was duplicated `build/`+`vendor/` (each ~5.8 GB build + ~5.6 GB
vendor; a single hardlink-deduped `du` still totalled 62 GB → mostly real copied bytes, not shared
hardlinks). Restore later via `cp -al ../<main>/build` / `cp -al ../<main>/vendor` (near-zero disk
hardlinks), a rebuild (`dev/run.sh toolchain`), or re-applying the branch's `0002` patch.
Safety asymmetry: **`build/` is always safe to delete** (pure compiled output, never source);
**`vendor/` can hold uncommitted source edits git cannot see** (it's gitignored, edited in place) — only
delete a worktree's `vendor/` once its work is confirmed captured in the committed `0002` patch. Never
delete `build/`/`vendor/` out from under a *live* worktree (recent build mtime / dirty) on this hot shared
tree.

**Mechanics confirmed (2026-06-21).** A worktree's `vendor/llvm-mos` is its **own shallow git clone**
(HEAD = pristine upstream; backend edits applied via `git apply` and left **uncommitted** by design, so
25–45 "dirty" files + untracked new sources like `MOSInsertREPSEP.cpp/.h` are *expected*, not unique work).
The capture check is concrete: `grep MOSInsertREPSEP patches/llvm-mos/0002-*.patch` (and the round-trip in
`dev/regen-patch.sh`) — verified the untracked new sources ARE in the committed patch series on all dormant
branches; only `vendor/.../docs/transcripts/*` is uncaptured (disposable). **`git gc` is a dead end** here —
the `.git` (~3 GB) is an already-packed shallow clone (loose objects ~3 MiB), so the ONLY way to reclaim
vendor's bulk is delete + later `dev/run.sh toolchain` re-clone. After `build/`, `vendor/` is the *only*
remaining bulk in a worktree (everything else is tiny tracked source).

**Why:** the scripts ARE the reproducible evidence behind a measured win/loss/won't-do decision; deleting
them forces re-deriving the conclusion from scratch next time the question comes up. The build/vendor copies
are dupes of infrastructure that already exists on `main` (regenerable), so they are precisely the space to
reclaim — discarding them loses nothing.

**How to apply:** before `git worktree remove --force` + `git branch -D`, (1) merge/cherry-pick the durable
scripts + verdict docs to `main`; (2) confirm they're committed; (3) only then remove the worktree (reclaims
the ~11 GB of dupes). Mirrors docs/howto-feature-worktree.md §Disposition ("Keep → merge the durable
artifacts; throw the rest away"). See [[investigations-on-throwaway-branches]].
