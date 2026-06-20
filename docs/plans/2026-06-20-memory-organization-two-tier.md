# Memory organization: generic master in `~/.claude/memory`, project-specific in the project repo, symlinked

**Status:** executing 2026-06-20. Cross-cutting (homedir repo + llvm-mos repo + the `~/.claude/memory` master);
triggered while wiring llvm-mos memory version-control. Supersedes the abandoned `projects.env` mechanism
(home-repo commit `e7dcf85`, to be reverted).

## Decision — the architecture (two masters, split by *kind of thing*)

Same symlink-into-a-master **mechanism** for both, but a **different master per resource type**:

- **Generic memory** (who the user is / how they like to work — `user_*`, `feedback_*`, cross-project
  principles) → **`~/.claude/memory/`** (the **homedir** repo). It is personal user-state.
- **Shared tooling** (Taskfile, `task md`, scripts, hooks, future TUI) → **python-tui-lib**. It is reusable
  *code*. **Memory does NOT go in python-tui-lib** — that library may be extracted/published (the baseline
  plan flags it as the long-term home for shared tooling), and personal `feedback_*`/`user_*` memory must not
  ride along into a potentially-public repo.
- **Project-specific memory** → the project's **own repo** at `.claude/memory/` (real files), gitignored
  except `!.claude/memory/`, symlinked into `~/.claude/projects/<key>/memory` (matches every other project).

So each project's `.claude/memory/` = `MEMORY.md` (real, this project's index) + project-specific files
(real) + generic files (symlinks → `~/.claude/memory/`). Exactly parallel to how its Taskfile/hooks symlink
into python-tui-lib. "Does this project have a TUI yet" stays irrelevant to where memory lives.

**Naming:** keep **kebab-case** (`name:` frontmatter + `<slug>.md`) — the current documented convention; it
preserves the `[[cross-links]]` between memories and is lower-churn. The master's existing `feedback_*` names
are the older style (type-in-filename); a lone rename now only mixes conventions. New generic memories use
kebab-case + frontmatter `metadata.type`.

## llvm-mos migration

**Classification of the 7 current memories** (`~/.claude/projects/-home-will-SRC-llvm-mos-65816/memory/`):

| memory | destination | rationale |
|---|---|---|
| `MEMORY.md` | real → llvm-mos repo | this project's index |
| `a16-codegen-mostly-16bit-mode` | real → llvm-mos repo | project-specific codegen lesson |
| `modest-gains-worth-doing` | real → llvm-mos repo | compiler-framed |
| `no-false-choice-questions` | generic → master + symlink | cross-project working principle |
| `investigations-on-throwaway-branches` | generic → master + symlink | cross-project principle |
| `close-net-negative-findings-not-defer` | generic → master + symlink | cross-project principle |
| `audit-deferrals-hook-force-adds-todo` | generic → master + symlink | about the python-tui-lib hook, not llvm-mos |

**Steps**

1. **llvm-mos repo**: append `.claude/*` + `!.claude/memory/` to `.gitignore` (ignores the stray
   `scheduled_tasks.lock`, tracks memory); `mkdir -p .claude/memory`.
2. **Move project-specific (3)** → `~/SRC/llvm-mos-65816/.claude/memory/` (real files).
3. **Move generic (4)** → `~/.claude/memory/` (the master); **symlink** each back into the llvm-mos memory
   dir as `../../../../.claude/memory/<slug>.md` (relative, matching parking-space).
4. **Replace** `~/.claude/projects/-home-will-SRC-llvm-mos-65816/memory` (real dir, now empty) with a symlink
   → `/home/will/SRC/llvm-mos-65816/.claude/memory` (absolute, matching every other project).
5. Verify the llvm-mos `MEMORY.md` index (slugs unchanged; it lists project-specific + the symlinked generics).
6. **Revert home-repo misstep `e7dcf85`**: remove `.claude/projects.env`, `.claude/sync-memory-gitignore.sh`,
   the generated `~/.gitignore` block, and untrack the 7 files under `.claude/projects/…/memory/` (3 left for
   the llvm-mos repo, 4 relocated to `~/.claude/memory/`). **Keep `1d90953`** (the `projects.json` registry
   entry — that part was correct).

**Commits**
- **llvm-mos repo**: `.claude/memory/` (3 real + 4 symlinks) + `.gitignore` + this plan.
- **homedir repo**: the 4 generics now under `~/.claude/memory/`; removal of `projects.env` + sync script +
  the gitignore block; untracked moved files. (`projects.json` registration stays.)

## Verification
1. `~/.claude/projects/-home-will-SRC-llvm-mos-65816/memory` is a symlink → the llvm-mos repo; all generic
   symlinks resolve to existing files in `~/.claude/memory/`.
2. llvm-mos repo tracks `.claude/memory/` (3 real + 4 symlinks); `scheduled_tasks.lock` ignored.
3. The 4 generic memories exist in `~/.claude/memory/` (master).
4. homedir repo: no `projects.env`/sync script/gitignore block; `projects.json` kept; the 7 old paths
   resolved (moved/relocated), nothing dangling.
5. Memory still loads end-to-end (`MEMORY.md` index valid, `[[links]]` intact).
