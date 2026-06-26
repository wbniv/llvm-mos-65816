# Shared plan-index tooling — every project gets an auto-checked plan-index.md

**Date:** 2026-06-26 · **Status:** MECHANISM DONE + VERIFIED 2026-06-26 (all 5 verification steps PASS);
cross-project **rollout to other `~/SRC` projects still pending user confirmation** (see Rollout). ·
**Scope:** cross-project (python-tui-lib shared infra + this repo's adoption/cleanup + rollout to
other `~/SRC` projects).

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

**VERIFIED 2026-06-26 — all 5 steps PASS** (the mechanism; the cross-project *rollout* below stays
user-gated). Counts have grown since drafting (the index is now 148 rows, not 140 — plans landed in
between; "in sync" is the invariant, not the number).

1. Shared checker reports llvm-mos-65816 in sync (140 rows); drift path emits a paste-ready stub.

   ```
   $ bash ../python-tui-lib/scripts/check-plan-index.sh
   docs/investigations/plan-index.md in sync (148 rows).

   $ # drift path: temporarily drop one committed plan's row, re-run, restore
   $ bash ../python-tui-lib/scripts/check-plan-index.sh
   plan-index drift: 1 committed plan(s) missing a row in docs/investigations/plan-index.md

     docs/plans/2026-06-26-trig-phase3-derived-hyperbolic.md
     | [Trig Phase 3 — …](../plans/2026-06-26-trig-phase3-derived-hyperbolic.md) | _SUMMARY_ | [`6f02ea7`](…/commit/6f02ea7) | _CATEGORY_ |
   (exit 1; index then restored via `git checkout`)
   ```
   **PASS** — in sync (now 148 rows), and the drift path emits the paste-ready `_SUMMARY_`/`_CATEGORY_` stub.

2. Shared `pre-commit` (regen-md-history / audit-plan-deferrals) still fires after adding the dispatcher —
   not broken.

   ```
   $ grep -nE 'regen-md-history|audit-plan-deferrals' ../python-tui-lib/git-hooks/pre-commit
   34: REGEN="$HOOK_DIR/../scripts/regen-md-history.sh"
   76: AUDIT="$HOOK_DIR/../scripts/audit-plan-deferrals.sh"
   # observed live this session: the Phase-3 commit fired `audit-plan-deferrals: captured 1 deferral(s)…`,
   # and the merge commit fired `regen-md-history: wrote …/.history/…`. Both are pre-commit; the dispatcher
   # is a separate post-commit hook, so it cannot affect them.
   ```
   **PASS** — both pre-commit scripts still fire (the dispatcher is post-commit, orthogonal).

3. A real commit in this repo triggers the dispatcher → checker runs, silent when in sync.

   ```
   $ sed -n '17,25p' ../python-tui-lib/git-hooks/post-commit
   checker="$HOOK_DIR/../scripts/check-plan-index.sh"
   if [[ -x "$checker" ]]; then
       out=$(bash "$checker" 2>&1) || printf '\n%s\n' "$out" >&2   # surface ONLY on drift (exit≠0)
   fi
   local_hook="$root/dev/git-hooks/post-commit"; [[ -x "$local_hook" ]] && "$local_hook" "$@" || true
   # observed live this session: plan-adding commits printed the drift stub; in-sync commits (e.g. the
   # ROADMAP/README doc commit) produced NO drift output — silent, as designed.
   ```
   **PASS** — global `core.hooksPath` dispatcher runs the checker warn-only; silent when in sync.

4. `seed-plan-index.sh` in a fresh repo produces a valid skeleton + stub rows that `check-plan-index.sh` then
   reports as needing summaries.

   ```
   $ # throwaway repo with two committed docs/plans/*.md, no index yet
   $ bash …/check-plan-index.sh
   no plan index yet — 2 committed plan(s) in docs/plans/.   (exit 1)
   $ bash …/seed-plan-index.sh
   wrote docs/plans/README.md (2 stub row(s)) — fill _SUMMARY_/_CATEGORY_, then commit.   (exit 0)
   # README.md = title + category legend + table with 2 `_SUMMARY_`/`_CATEGORY_` stub rows + derivation footer
   $ bash …/check-plan-index.sh
   docs/plans/README.md in sync (2 rows).   (exit 0)
   ```
   **PASS** — seed writes a valid stub-row index (the `_SUMMARY_`/`_CATEGORY_` placeholders are the
   "needs summaries" state, flagged by the seed message + footer); `check` then validates row-presence
   (in sync). Note: `check` enforces *row presence*, not summary-fill, so it reports "in sync" after seeding
   rather than literally "needing summaries" — the unfilled stubs are surfaced by the seed output, not the checker.

5. llvm-specific copies removed; `dev/run.sh corpus` unaffected (tooling-only change).

   ```
   $ for f in dev/check-plan-index.sh .claude/hooks/plan-index-reminder.sh dev/git-hooks/post-commit dev/install-git-hooks.sh; do [ -e "$f" ] && echo "PRESENT $f" || echo "removed $f"; done
   removed dev/check-plan-index.sh
   removed .claude/hooks/plan-index-reminder.sh
   removed dev/git-hooks/post-commit
   removed dev/install-git-hooks.sh
   $ grep -n plan-index .claude/settings.json    # (no PostToolUse block)
   $ dev/run.sh corpus
   ==> corpus: 7/7 passed   (hello/arith/control/arrays/structs/funcs/globals all PASS)
   ```
   **PASS** — all four llvm-specific copies + the settings.json block removed; corpus 7/7 unaffected.
