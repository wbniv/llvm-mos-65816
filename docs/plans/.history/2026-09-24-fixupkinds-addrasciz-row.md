| Date | Change |
|------|--------|
| [2026-09-24](https://github.com/wbniv/llvm-mos-65816/commit/e5936100) | todo: record fixupkinds-addrasciz-row verification, triage its Inbox stub |
| [2026-09-24](https://github.com/wbniv/llvm-mos-65816/commit/fe54d1b7) | fix(mos): add the missing AddrAsciz row to MOSFixupKinds.cpp's Infos[] |

<!--history-meta v1
e5936100	author	Will Norris
e5936100	added	48
e5936100	deleted	4
e5936100	files	1
e5936100	body	The AddrAsciz-row fix's plan (docs/plans/2026-09-24-fixupkinds-addrasciz-row.md)\ndescribed its verification steps but hadn't pasted raw output/PASS yet when the\nprior commit's audit-plan-deferrals hook captured a [verify] Inbox stub for it.\nFill in the plan's Verification section with the actual dev/run.sh lit output\n(155-test/4-known-failures baseline unaffected, addressing-modes-65816.s\nconfirmed pre-existing by reverting the fix in isolation) and the round-trip\napply-and-diff check, then triage the now-redundant Inbox stub away (the item\nis already in Done). Also corrects the plan's Upstream section, which had\ndrafted language about writing the PR-prep doc inline before the actual\ndecision (queue a TODO item mirroring 0043/0044, left unranked since a T1\ndispatch cannot assign a delegation tier) was made.\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_017sAprvTwtKFJHKgQmr1qgr
fe54d1b7	author	Will Norris
fe54d1b7	added	106
fe54d1b7	deleted	0
fe54d1b7	files	1
fe54d1b7	body	MOSFixupKinds.h declares 15 target fixup kinds; Infos[] had only 14\ninitialisers, so a lookup for MOS::AddrAsciz silently read the array's\nvalue-initialised tail ({nullptr, 0, 0, 0}) instead of a real row. Harmless\ntoday (TargetSize == 0 already meant "never relax", which happens to be\ncorrect for this variable-width decimal-ASCII data directive), but the\ntable's own documented "same order as the header" contract was silently\nviolated, and the next fixup kind appended after AddrAsciz would inherit the\nsame off-by-one. Pristine-upstream, one-file, one-row fix (patch 0046);\nconfirmed no fork patch touches MOSFixupKinds.cpp.\n\nAdds the row with a deliberate, documented TargetSize=0 (matching today's\naccidental behaviour but now intentional) and registers 0046 in\ndev/toolchain.sh and dev/regen-patch.sh's STANDALONE_MOSDIR list, same\npattern as 0039/0044/0045.\n\ndev/run.sh lit: 155 tests, same 4 known-failing baseline (unrelated to this\nchange, confirmed by reverting the fix and re-running just the one file that\nwas allegedly at risk). Round-trip verified: 0046 applies cleanly to a\npristine worktree and produces a byte-identical MOSFixupKinds.cpp.\n\nTODO: moves the wip item to Done; adds an unranked queued item for drafting\nthe 0046 upstream PR (mirrors the 0043/0044 pattern) since ranking a new\nTODO item is not a T1 dispatch's call to make.\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_017sAprvTwtKFJHKgQmr1qgr
-->
