| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/f30c9ea) | #321 implement bsnes-jg-only confirmation runner (dev/run.sh xcheck-suite) — 45/45 |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/d26a5e6) | #321 plan: bsnes-jg-only second-emulator confirmation runner (JG_ONLY / xcheck-suite) |

<!--history-meta v1
f30c9ea	author	Will Norris
f30c9ea	added	54
f30c9ea	deleted	1
f30c9ea	files	1
f30c9ea	body	Per the plan: a MAME-skipping JG_ONLY pass so the second emulator (bsnes-jg) can be\nexercised cheaply + deterministically — no MAME, no SPC700 BIOS, no quiet box.\n\n- dev/_emu.sh: JG_ONLY=1 guard in run_assert (skip MAME -> "SMOKE: SKIP", return 0)\n  and require_bios (no-op). Each test's own deterministic bsnes-jg leg still runs.\n- dev/xcheck-suite.sh (new): serial, niced pass over the a16*/xy16* tests that carry a\n  jgxcheck leg (45; the 6 compile-only gates auto-excluded). Optional PREFIX filter.\n  Logs to build/xcheck-suite/ (mounted, persist). PASS requires the positive\n  "(ran N frames, bsnes-jg)" result line, so a jgxcheck-absent SKIP can't masquerade\n  as a confirmation.\n- dev/run.sh: xcheck-suite target + usage + JG_ONLY env forwarding.\n\nVerified 2026-06-19 (raw output in the plan): (1) JG_ONLY skips MAME on a16add;\n(2) full suite 45/45 in ~49 s; (3) xy16 4/4 -- the recent xy16 codegen IS confirmed\non bsnes-jg; (4) runs with the SPC700 BIOS absent. TODO item -> [x].\n\nNo codegen / vendor / 0002 change.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d26a5e6	author	Will Norris
d26a5e6	added	107
d26a5e6	deleted	0
d26a5e6	files	1
d26a5e6	body	Plan-first for a MAME-skipping suite runner so the second oracle (bsnes-jg) can be\nexercised cheaply + deterministically without booting the flaky MAME leg.\n\n- docs/plans/2026-06-19-second-emulator-jg-only-confirmation.md (new): the contract.\n  Design = a JG_ONLY guard in dev/_emu.sh (run_assert/require_bios no-op) +\n  dev/xcheck-suite.sh (serial, niced, tallies PASS/FAIL/SKIP). Records the corrected\n  understanding that a concurrent MAME does NOT affect a deterministic bsnes-jg run\n  (minor good-neighbor courtesy, not a constraint), the now/wait/both policy, and the\n  finding that xy16 second-emulator coverage is already complete (xy16spill is a\n  compile gate, not a gap).\n- TODO.md: new Test Bench / CI item linking the plan.\n- agent-handoff.md: clarify the "QUIET box" rule is a MAME/fuzzer rule -- the bsnes-jg\n  leg is deterministic + load-insensitive (and BIOS-free).\n\nNo codegen / vendor / 0002 change. Runner code follows in a later commit.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
