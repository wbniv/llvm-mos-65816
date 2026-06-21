| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/b78a2d5) | #321 xy16: both-legs verify hardening — known a16 issue can't mask a new xy16 crash |

<!--history-meta v1
b78a2d5	author	Will Norris
b78a2d5	added	141
b78a2d5	deleted	0
b78a2d5	files	1
b78a2d5	body	Follow-up to the symmetric-classify fix. The +mos-a16 verify leg still\nearly-returned XFAIL on a known issue BEFORE the +mos-xy16 leg ran, so a\ngenuinely-new xy16-only crash (e.g. an X-lattice regression) on a known-a16\nprogram was silently hidden behind the a16 XFAIL.\n\nRestructure the verify block in evaluate() to run BOTH legs (unless a16 is\nitself a NEW crash → fast-path early-out), then decide by priority:\n  - NEW (unclassified) crash on EITHER leg  -> CRASH\n  - else known issue on EITHER leg          -> XFAIL\n  - else (both clean)                       -> proceed\nA new crash on either leg now always outranks a known issue on the other, so\nthe masking gap is closed for exactly the population (16-bit-pressure programs)\nmost likely to expose an X-lattice regression.\n\nCost: one extra xy16 verify only for known-a16-issue programs (the 8 scavenger\nseeds, globals, the two repros) — clean-a16 already ran xy16, new-a16-crash\nstill early-outs. No current known-issue case flips: every one classifies on\nboth legs. Python-only tool change (not vendor/) -> no 0002 regen.\n\nVerified: 7-row decision-table unit test (mocked verify_machineinstrs) ALL PASS\nincl. the critical a16=known + xy16=new -> CRASH; check a16regpress/a16scavnz\nstill XFAIL; corpus-a16 5/6 PASS + globals XFAIL (no flip); builtin fuzz seed\n306 -> XFAIL scavenger-p-not-gpr.\n\nPlan: docs/plans/2026-06-21-321-xy16-verify-both-legs-hardening.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01MfznzHZwGwQHUDg7yjrJ8u
-->
