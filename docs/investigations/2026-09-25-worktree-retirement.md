# Retired worktrees and retained validation evidence

Five inactive worktrees were removed at the user's request to recover disk space.
Free space increased from approximately 118 MiB to 18 GiB. Their branches remain
in the main repository. [Exact paths, revisions, and verification](2026-09-25-worktree-retirement.json).

Audit, evidence retention, and cleanup: OpenAI Codex CLI 0.157.0 (`codex-tui`),
model `gpt-6-astra`, `xhigh` reasoning effort, verified from this session metadata.

| Removed checkout | Retained evidence |
|---|---|
| `llvm-mos-65816-pr0043-pinval` | [Archive manifest](../../build/retired-worktrees/2026-09-25/llvm-mos-65816-pr0043-pinval/manifest.json); [validation](../pr-preparations/2026-09-25/0043-validation.md) |
| `llvm-mos-65816-pr0044-pinval` | [Archive manifest](../../build/retired-worktrees/2026-09-25/llvm-mos-65816-pr0044-pinval/manifest.json); [plan](../plans/2026-09-24-asmprinter-long-address.md) |
| `llvm-mos-65816-pr0046-pinval` | [Archive manifest](../../build/retired-worktrees/2026-09-25/llvm-mos-65816-pr0046-pinval/manifest.json); [validation](../pr-preparations/2026-09-25/0046-validation.md) |
| `llvm-mos-65816-pr0047-pinval` | [Archive manifest](../../build/retired-worktrees/2026-09-25/llvm-mos-65816-pr0047-pinval/manifest.json); [validation](../pr-preparations/2026-09-25/0047-validation.md) |
| `.claude/worktrees/agent-a6894f2e1ef68a174` | Clean, fully merged checkout; branch retained |

Each validation archive preserves every named before/after compiler snapshot,
the configured build's executable tools and resource headers, generated headers,
tests, run logs, CMake configuration, commands, untracked reproducers, and tracked
source changes. The archive manifests identify source revisions still present
in surviving Git repositories and hash each retained file. Hard links preserve
the original bytes without making temporary full copies on the nearly full disk.
Hashes were checked again after removal, and all 13 retained `llc` snapshots in
the named binary sets execute successfully.

Deleted material consists of duplicate committed checkouts and their nested Git
stores, ccache entries, object/static-library build intermediates, and regenerable
CMake files. No branch was deleted. Existing validation documents retain their
captured paths and now link to these relocation records.

The current project's compiler, saved upstream reference, preserved failure
builds, and all baselines named by the 11 structured defect records remain intact.
Dirty feature worktrees, older unresolved investigations, and their unique
artifacts were retained. Worktree inactivity was checked against process working
directories before removal.
