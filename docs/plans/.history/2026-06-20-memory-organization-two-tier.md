| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/6779286) | memory: adopt the two-tier layout — project-specific in repo, generics symlinked to the master |

<!--history-meta v1
6779286	author	Will Norris
6779286	added	70
6779286	deleted	0
6779286	files	1
6779286	body	Match every other project: per-project memory lives in this repo at .claude/memory/\n(gitignored except !.claude/memory/), symlinked into ~/.claude/projects/<key>/memory.\n- Real (project-specific): MEMORY.md, a16-codegen-mostly-16bit-mode, modest-gains-worth-doing.\n- Symlinks -> ~/.claude/memory/ (generic, cross-project): no-false-choice-questions,\n  investigations-on-throwaway-branches, close-net-negative-findings-not-defer,\n  audit-deferrals-hook-force-adds-todo.\nReplaces the abandoned home-repo projects.env mechanism (reverted in the homedir repo).\n\nPlan: docs/plans/2026-06-20-memory-organization-two-tier.md.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
