# Enforce the worktree-teardown keep-durable policy with a hook + wrapper

**One line:** Make `dev/worktree-teardown.sh` the only blessed way to tear down a feature worktree (it merges the
durable keepers to `main`, then `git worktree remove --force` + `git branch -D` and reports the reclaimed GB), and
add a Claude Code **PreToolUse** guard hook that **blocks raw `git worktree remove` / `git branch -D wt/…`** and
redirects to the wrapper — so a teardown can never silently drop the scripts/verdicts that reconstruct a
conclusion.

**Status:** PLANNED (2026-06-21). Implements the [[worktree-teardown-keep-durable-artifacts]] policy (memory,
user 2026-06-21): on teardown reclaim the 95%+ `vendor/`+`build/` dupes, never delete the measure scripts /
recorded verdicts; retain worktrees until upstream merge.

---

## 1. Why a hook (and which one) — the mechanism is forced

**Git cannot enforce this.** Git defines no `worktree remove` hook — its hooks are commit/checkout/push/rewrite
only (the lone worktree-adjacent one is `post-checkout`, fired by `worktree add`). Verified via `git help hooks`.

**So the only thing that can intercept `git worktree remove` is a Claude Code `PreToolUse` hook on the Bash
tool.** Confirmed current schema (via claude-code-guide, 2026-06-21):
- Config lives in `.claude/settings.json` → `hooks.PreToolUse[ {matcher:"Bash", hooks:[{type:"command",
  command:"…", timeout:5}]} ]`. `matcher` is an **exact tool-name** string (so command-content filtering happens
  **inside** the hook script).
- The hook reads JSON on **stdin** (`tool_input.command`, `cwd`, `permission_mode`, …).
- To **deny**: print JSON on stdout + `exit 0`:
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`
  — the reason is shown to the user **and** fed to the model. To **pass through**: `exit 0` with no output.
- Project `.claude/settings.json` hooks **merge with** (run after) the global `~/.claude/settings.json` ones;
  first `deny` wins. PreToolUse(Bash) fires on **every** Bash call → the script must early-exit fast.

**The key simplifier:** the hook fires only on the command **Claude** runs as a Bash tool call. A `git worktree
remove` executed *inside* `dev/worktree-teardown.sh` is a **subprocess**, not a tool call, so it is **invisible to
the hook** — no bypass marker / env flag is needed. The wrapper's internal teardown just works.

## 2. Design — dumb hook + smart wrapper

Split responsibility so the policy lives in one auditable script, not in hook logic:

- **`.claude/hooks/guard-worktree-teardown.sh`** (the *dumb* guard): if Claude's Bash command contains
  `git worktree remove` or `git branch -[dD] wt/`, **deny** with a reason pointing at the wrapper. Everything else
  passes through (`exit 0`). ~15 lines, `grep`-fast.
- **`dev/worktree-teardown.sh <slug|branch> [--yes]`** (the *smart* blessed path): verify nothing durable is lost,
  then tear down + reclaim. Its internal `git worktree remove` is hook-exempt (§1).

### 2.1 What "durable / lost" means — the commit+status check (not a location guess)

The robust definition of "would this teardown lose durable work?" is **not** a path heuristic (`dev/*.sh` +
`docs/plans/*`) — it is simply *"is there tracked work here that isn't on `main`?"* The wrapper hard-aborts if
either:
1. **Unmerged commits:** `git log --oneline main..<branch>` is non-empty → the branch carries commits not on
   `main` (cherry-pick/merge them first).
2. **Uncommitted tracked changes:** `git -C <wt> status --porcelain` shows modified/added **tracked** files
   (commit + land them first).

…and **warns + requires `--yes`** if untracked, non-gitignored files exist under `dev/` or `docs/` (a possibly-
durable script not yet `git add`ed — list them so the user can rescue or confirm-disposable). Everything that is
gitignored (`vendor/`, `build/`, ROMs, `fuzz-triage/`) is *by definition* reclaimable dupe and is ignored by both
checks. This is **more correct** than a location heuristic: it catches *all* durable tracked work, and in this
project's "commit durable artifacts straight to `main`" workflow a build-only worktree (e.g. `wt/321-track-a`)
has zero unique commits + a clean tracked status → it passes and reclaims the ~11 GB cleanly.

### 2.2 The retain-until-upstream gate

The companion half of the policy ("retain worktrees until upstream merge"). The wrapper prints the reminder and
requires an explicit `--yes` (no interactive prompt — the harness shell is non-interactive). It does **not** try to
auto-detect "merged upstream" (not mechanically knowable); `--yes` is the human ack that it's time.

## 3. Build steps

1. **`dev/worktree-teardown.sh`** — `set -euo pipefail`, `-h/--help`; resolve `WT`/`BRANCH` from the arg; the §2.1
   checks (abort on unmerged commits / tracked changes; warn+`--yes` on untracked under `dev/`,`docs/`); `du -sh`
   the worktree for the reclaim figure; `git worktree remove --force` + `git branch -D`; print reclaimed GB + the
   retained durable artifacts (the commits already on `main`).
2. **`.claude/hooks/guard-worktree-teardown.sh`** — read stdin, `jq -r '.tool_input.command'`, `grep -qE
   '(git[[:space:]]+worktree[[:space:]]+remove|git[[:space:]]+branch[[:space:]]+-[dD][[:space:]]+wt/)'` → emit the
   deny JSON (reason: *"Use `dev/worktree-teardown.sh <slug>` — it preserves the durable scripts/verdicts and
   reclaims only the dupes (worktree-teardown-keep-durable-artifacts policy). Raw teardown is blocked."*); else
   `exit 0`. Guard `jq`-absent (fall through allow) so it never wedges unrelated Bash.
3. **`.claude/settings.json`** — create it (project has none) with the `PreToolUse`/`Bash` entry pointing at
   `$CLAUDE_PROJECT_DIR/.claude/hooks/guard-worktree-teardown.sh` (`timeout: 5`). **`.gitignore` fix (key):**
   this project ignores `.claude/*` (only `!.claude/memory/` was excepted), so the hook+settings would be
   *local-only* (lost on a reclone — violates reproducibility). Add `!.claude/settings.json` + `!.claude/hooks/`
   exceptions so the wiring is **tracked** and rebuildable from the repo (the `scheduled_tasks.lock` + transcripts
   stay local). Keeping the hook at its native `.claude/hooks/` path (rather than contorting it into `dev/` +
   an installer) is the simpler reproducible form once `.gitignore` cooperates.
4. **(Optional, follow-up) integrity:** route the hook through the sha256 `.claude/hook-runner.sh` +
   `.claude/hook-checksums.json` wrapper (CLAUDE.md X6 / SplitLedger) so a tampered hook warns. Deferred — this
   project has no hook-runner yet; note it, don't block the first cut on it.

## 4. Limits (state them; don't oversell)

- A PreToolUse hook only guards teardowns **Claude** runs. A manual `git worktree remove` typed in a terminal
  does **not** fire it — so the *real* enforcement is social/convention: `dev/worktree-teardown.sh` is the blessed
  path, the hook just stops Claude from bypassing it. Git can't backstop this (no worktree hook).
- The guard is a **string match** on the command; an obfuscated invocation (alias, `eval`, a renamed git) slips
  it. That's acceptable — the goal is preventing an *accidental* raw teardown, not defeating a determined bypass.

## 5. Verification

1. **Hook denies raw teardown:** pipe a synthetic PreToolUse payload
   (`{"tool_input":{"command":"git worktree remove ../llvm-mos-65816-foo"}}`) into the hook → expect the deny JSON;
   a benign payload (`{"tool_input":{"command":"git status"}}`) → expect empty output + exit 0. (Also exercise
   `git branch -D wt/foo`.)
2. **Live block:** with the hook wired, an actual `git worktree remove …` Bash call is denied with the reason
   shown (do not run a real destructive remove — a dry/non-existent path is enough to see the deny).
3. **Wrapper aborts on durable loss:** point it at a worktree with an uncommitted tracked file / a unique commit
   → expect the abort listing them; at a clean build-only worktree → expect it to proceed (dry-run first: add a
   `--dry-run` that prints the plan + reclaim figure without removing).
4. **Wrapper round-trips a real teardown** only when the user explicitly asks (it's destructive); until then the
   `--dry-run` is the proof. `set -euo pipefail` + `-h` handled.
5. **No collateral:** ordinary Bash calls (git status/diff/build/test) are untouched by the hook (it early-exits).

## 5a. Verification results — RAN 2026-06-21 (`dev/test-worktree-teardown.sh`, 15/15)

```
guard hook deny/passthrough matrix: 13/13
  DENY: git worktree remove …, …--force…, cd && remove, git -C path worktree remove, branch -[dD] wt/…
  PASS: git worktree list, worktree add, git status, branch -D feature/… (not wt/),
        "git worktree remove" MENTIONED in echo/grep, AND the wrapper invocation itself
wrapper: -h exits 0; bad arg → FATAL (exit 1)
```
Live behaviour confirmed:
- The hook is **active in-session** (writing `.claude/settings.json` loaded it without a restart) — a real
  `git worktree remove …` Bash call is denied with the redirect reason shown.
- `dev/worktree-teardown.sh 321-track-a --dry-run` → **PASS** (build-only worktree: 0 tracked files differ from
  main; would reclaim **12 GB**, 258 durable keepers retained).
- `dev/worktree-teardown.sh wt/320-far-cc --dry-run` → **ABORT**, correctly catching 2 unmerged branch commits
  (variant (a)/(b) far-CC work) — the durability gate protecting real work, exactly as intended.

One bug found+fixed during verification: gate 2 first compared the worktree against its own (stale) HEAD and
false-aborted on a `0002` regenerated-in-worktree-then-copied-to-main; corrected to compare against `main`
(content already on main is not a loss). Matcher also hardened to **command-position** anchoring so a *mention*
of the string (echo/grep/doc/test payload) is not blocked — only an actual teardown command.

## 6. Bookkeeping

- Stage: `dev/worktree-teardown.sh`, `.claude/hooks/guard-worktree-teardown.sh`, `.claude/settings.json`, this
  plan, the TODO pointer. `.claude/settings.json` travels with the hook (CLAUDE.md).
- Add a TODO item under "Test Bench / CI" (tooling). Commit; push only when asked.
- This plan + the wrapper are themselves durable keepers — exactly the kind of artifact the policy protects.
