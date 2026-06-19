| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/e1f155c) | #321 CI [verify]: complete the local half for corpus-a16 + bsnes-jg xcheck wiring |
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/d5f0bef) | ci: add bsnes-jg xcheck job to smoke.yml (cached from-source toolchain) |

<!--history-meta v1
e1f155c	author	Will Norris
e1f155c	added	8
e1f155c	deleted	1
e1f155c	files	1
e1f155c	body	Both CI items (corpus-a16 + the heavy bsnes-jg xcheck job in smoke.yml) are wired and\nYAML-valid; the only remaining confirmation is a user-triggered green CI dispatch. Did\nthe locally-verifiable half and recorded evidence:\n\n- dev/run.sh xcheck re-ran green locally (bsnes-jg only, no MAME): hello 0x42,\n  far-run/far-bank1 0xF3, "bsnes-jg agrees with MAME on the far ROMs", exit 0 — fills\n  the xcheck plan's verification step 1 (was an unfilled placeholder).\n- smoke.yml re-validated: 2 jobs, corpus-a16 secret-gated, workflow_dispatch trigger.\n- corpus-a16's own command is green per the differential-mode item; not re-run here\n  (MAME-heavy, shared box).\n\nKey finding recorded in both TODO items: the last green CI run (27475871789, 2026-06-13,\n~1.5 min) is the OLD smoke-only workflow — the heavy xcheck job + corpus-a16 step have\nNEVER actually run in CI. The SNES_SPC700_ROM_B64 secret is already set, so the single\nremaining (user-triggered) action is: gh workflow run snes-smoke && gh run watch.\n\nNo code/CI change — local verification + docs only.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d5f0bef	author	Will Norris
d5f0bef	added	129
d5f0bef	deleted	0
d5f0bef	files	1
d5f0bef	body	New xcheck job (parallel to smoke): caches the ~30-90 min from-source patched\nllvm-mos toolchain (actions/cache@v5, keyed on the backend patches; skipped on\nhit), builds the snes-far SDK against it, then runs dev/run.sh xcheck to boot\nthe far ROMs in bsnes-jg and assert hello/far-run/far-bank1. Needs no SPC700\nsecret, so it runs unconditionally. YAML validated; a green CI dispatch is the\nremaining (heavy, user-triggered) verification.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
