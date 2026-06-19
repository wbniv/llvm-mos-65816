| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/d5f0bef) | ci: add bsnes-jg xcheck job to smoke.yml (cached from-source toolchain) |

<!--history-meta v1
d5f0bef	author	Will Norris
d5f0bef	added	129
d5f0bef	deleted	0
d5f0bef	files	1
d5f0bef	body	New xcheck job (parallel to smoke): caches the ~30-90 min from-source patched\nllvm-mos toolchain (actions/cache@v5, keyed on the backend patches; skipped on\nhit), builds the snes-far SDK against it, then runs dev/run.sh xcheck to boot\nthe far ROMs in bsnes-jg and assert hello/far-run/far-bank1. Needs no SPC700\nsecret, so it runs unconditionally. YAML validated; a green CI dispatch is the\nremaining (heavy, user-triggered) verification.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
