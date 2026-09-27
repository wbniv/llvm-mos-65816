| Date | Change |
|------|--------|
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/1bd2a347) | docs(plan): gate 0064 to regions with competing carries |

<!--history-meta v1
1bd2a347	author	Will Norris
1bd2a347	added	116
1bd2a347	deleted	0
1bd2a347	files	1
1bd2a347	body	Plan the follow-up that would remove 0064's 32 growing corpus configurations\n(208 B total) without giving up its wins: count carry saves per growing\nfunction from the retained disassembly, then, if none were removed, skip the\ncomputed-carry term in regions where carries cannot compete. Add the ranked\nT4 TODO item linking the plan and record the plan in the document inventory.\n\nDocumentation only; code work waits for Fable. Claude Code 2.1.280 using\nClaude Opus 5.5 (claude-opus-5-5), medium reasoning effort; session\n65695418-7e9b-45bd-92e3-2ecfd88ecf0b.\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_017sAprvTwtKFJHKgQmr1qgr
-->
