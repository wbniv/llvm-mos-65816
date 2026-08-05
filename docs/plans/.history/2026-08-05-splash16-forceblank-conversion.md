| Date | Change |
|------|--------|
| [2026-08-05](https://github.com/wbniv/llvm-mos-65816/commit/58e9e7f) | docs(plan): splash.h / splash16 force-blank conversion — NULL result, zero consumers |

<!--history-meta v1
58e9e7f	author	Will Norris
58e9e7f	added	148
58e9e7f	deleted	0
58e9e7f	files	1
58e9e7f	body	Both conversion targets in agent-handoff's "Still to convert" list are dead\ncode: nothing #includes snesgfx/splash.h and splash16() has no call sites.\nTheir consumers were removed by the very commits that introduced the systems\nthat replaced them — b6ef256 (TitleLayer replaced splash_show) and 8ac159f\n(m7splash_* replaced splash16). Neither helper is itself contract-violating;\nthe frames the contract recovers live in caller code, of which there is none.\n\nNo code change proposed. Escalated: keep-or-delete is a surface decision, and\nthe 11 stale splash.h rows in dev/snes-display-quality-baseline.json overlap\nconcurrent in-flight baseline work.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
