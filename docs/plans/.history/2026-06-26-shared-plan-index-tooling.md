| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/63daf1f) | plan: shared plan-index tooling — retire the llvm-specific drift hook |

<!--history-meta v1
63daf1f	author	Will Norris
63daf1f	added	54
63daf1f	deleted	0
63daf1f	files	1
63daf1f	body	The plan-index drift check is now generic shared infra in python-tui-lib\n(check-plan-index.sh + seed-plan-index.sh + a generic post-commit dispatcher on\nthe global core.hooksPath), so every project gets it without a per-project hook.\n\n- Remove dev/check-plan-index.sh and .claude/hooks/plan-index-reminder.sh (and\n  the .claude/settings.json PostToolUse wiring) — superseded by the shared hook.\n  This repo keeps its (already-rich) docs/investigations/plan-index.md, now\n  checked by the shared dispatcher.\n- Add the design/rollout plan docs/plans/2026-06-26-shared-plan-index-tooling.md.\n\nThe never-committed dev/git-hooks/post-commit + dev/install-git-hooks.sh drafts\nare dropped (no per-repo install needed once the shared dispatcher is global).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
