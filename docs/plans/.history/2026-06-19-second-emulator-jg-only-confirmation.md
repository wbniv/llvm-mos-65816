| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/d26a5e6) | #321 plan: bsnes-jg-only second-emulator confirmation runner (JG_ONLY / xcheck-suite) |

<!--history-meta v1
d26a5e6	author	Will Norris
d26a5e6	added	107
d26a5e6	deleted	0
d26a5e6	files	1
d26a5e6	body	Plan-first for a MAME-skipping suite runner so the second oracle (bsnes-jg) can be\nexercised cheaply + deterministically without booting the flaky MAME leg.\n\n- docs/plans/2026-06-19-second-emulator-jg-only-confirmation.md (new): the contract.\n  Design = a JG_ONLY guard in dev/_emu.sh (run_assert/require_bios no-op) +\n  dev/xcheck-suite.sh (serial, niced, tallies PASS/FAIL/SKIP). Records the corrected\n  understanding that a concurrent MAME does NOT affect a deterministic bsnes-jg run\n  (minor good-neighbor courtesy, not a constraint), the now/wait/both policy, and the\n  finding that xy16 second-emulator coverage is already complete (xy16spill is a\n  compile gate, not a gap).\n- TODO.md: new Test Bench / CI item linking the plan.\n- agent-handoff.md: clarify the "QUIET box" rule is a MAME/fuzzer rule -- the bsnes-jg\n  leg is deterministic + load-insensitive (and BIOS-free).\n\nNo codegen / vendor / 0002 change. Runner code follows in a later commit.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
