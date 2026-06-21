| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/814c4f4) | #321: known-issues XPASS guard — surface "drop the entry" when a deferred bug is fixed |

<!--history-meta v1
814c4f4	author	Will Norris
814c4f4	added	77
814c4f4	deleted	0
814c4f4	files	1
814c4f4	body	The deferred RA/scavenger defects are XFAIL'd via KNOWN_ISSUES with "REMOVE when\nfixed" comments, but nothing surfaced the trigger: an upstream/RA fix would just\nmake the repro silently verify clean, leaving a stale entry that masks a future\nregression of the same signature.\n\nAdd an XPASS guard:\n  - KNOWN_ISSUE_REPROS table (a16regpress.c -> regalloc-out-of-registers,\n    a16scavnz.c -> scavenger-p-not-gpr), maintained next to KNOWN_ISSUES.\n  - `tools/a16_fuzz.py known-issues` (cmd_known_issues): assert each repro STILL\n    crashes -verify-machineinstrs under +mos-a16 AND +mos-xy16 with its expected\n    kid. XPASS (verifies clean) or DRIFT (different/no signature, or missing) ->\n    hard FAIL printing the exact follow-up: drop the KNOWN_ISSUES entry + promote\n    the repro to a positive gate. Pure host verify (no SDK/emulator/secret).\n  - dev/known-issues.sh + dev/run.sh known-issues dispatch/usage.\n  - Unconditional CI step in smoke.yml xcheck (after the toolchain build), so any\n    push/PR carrying the fix turns CI red with the instruction.\n\na16-zp-pressure-overflow is out of scope: its repro is a gitignored c-torture\nLINK error, not a verify crash, so it can't be a verify-only guard row.\n\nVerified: guard PASS 4/4 legs (host subcommand + container/CI path); a simulated\nfix (row -> clean TU) trips a loud FAIL exit 1 with the drop+promote ACTION.\n\nPlan: docs/plans/2026-06-21-321-known-issues-xpass-guard.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01MfznzHZwGwQHUDg7yjrJ8u
-->
