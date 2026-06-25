# Shared plan-index tooling — every project gets an auto-checked plan-index.md

**Date:** 2026-06-26 · **Status:** IN PROGRESS · **Scope:** cross-project (python-tui-lib shared
infra + this repo's adoption/cleanup + rollout to other `~/SRC` projects).

## Context / goal

`docs/investigations/plan-index.md` (one hand-authored row per `docs/plans/*.md`, keyed by each plan's
creation commit) drifts as new plans land. The user wants **(a)** it kept current automatically and **(b)**
*every* `~/SRC` project to have one. Git hooks here run from a **global** `core.hooksPath`
(`~/SRC/python-tui-lib/git-hooks/`, home of the shared `pre-commit`), so the right home for the mechanism is
**python-tui-lib (shared infra)**, not a per-project hook.

Hard constraint: the index's **summaries/categories are hand-authored** (a shell hook can't write them). So
the tooling *detects drift* and *pre-computes the mechanical columns* (creation sha + full commit list +
paste-ready stub), mirroring the existing `audit-plan-deferrals` "capture for triage" pattern — it never
fabricates prose or auto-commits a row.

## Design (decided with the user)

1. **`python-tui-lib/scripts/check-plan-index.sh`** — generic drift checker. Derives the commit-link base
   from `origin`; no-op in any repo without committed `docs/plans/`. Exit 1 on drift (missing rows, or
   no index yet); prints paste-ready stub rows. *(written)*
2. **`python-tui-lib/scripts/seed-plan-index.sh`** — scaffold `docs/investigations/plan-index.md` in the
   current repo, pre-filled with a stub row per committed plan (chronological), header + category legend +
   derivation footer. Refuses if it already exists. One-command adoption.
3. **`python-tui-lib/git-hooks/post-commit`** — generic dispatcher (global via `core.hooksPath`): runs the
   shared checker warn-only (surfacing drift on stderr; covers terminal *and* agent commits), then runs the
   committing repo's own `dev/git-hooks/post-commit` if present. Non-blocking. *(written; update to run the
   checker)*
4. **Retire the llvm-mos-65816-specific copies** added earlier this session (superseded by the shared infra):
   `dev/check-plan-index.sh`, `.claude/hooks/plan-index-reminder.sh`, the `.claude/settings.json` PostToolUse
   block, the uncommitted `dev/git-hooks/post-commit` + `dev/install-git-hooks.sh`. Keep this repo's
   (already-rich) `docs/investigations/plan-index.md`.

No per-repo installer is needed: the dispatcher lives at the global `core.hooksPath`, so every repo is covered
the moment python-tui-lib carries it.

## Rollout (needs user confirmation — commits into *other* repos)

Seeding `plan-index.md` into another project commits into *that* repo. Options to confirm: which projects
(those with `docs/plans/`), and whether to seed a skeleton-only vs stub-backfilled index. Default proposal:
run `seed-plan-index.sh` (stub-backfilled) per project, leave it **uncommitted** for the owner to fill
summaries + commit — no unattended commits into other repos.

## Verification

1. Shared checker reports llvm-mos-65816 in sync (140 rows); drift path emits a paste-ready stub. *(PENDING)*
2. Shared `pre-commit` (regen-md-history / audit-plan-deferrals) still fires after adding the dispatcher —
   not broken. *(PENDING)*
3. A real commit in this repo triggers the dispatcher → checker runs, silent when in sync. *(PENDING)*
4. `seed-plan-index.sh` in a fresh repo produces a valid skeleton + stub rows that `check-plan-index.sh` then
   reports as needing summaries. *(PENDING)*
5. llvm-specific copies removed; `dev/run.sh corpus` unaffected (tooling-only change). *(PENDING)*
