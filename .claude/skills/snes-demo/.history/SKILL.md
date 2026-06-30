| Date | Change |
|------|--------|
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/fd4e937) | docs(snes): title-card screenshots on all completed demo plans + skill |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/bfcbe69) | chore(skills): add snes-demo + snes-rom-page as project-local skills |

<!--history-meta v1
fd4e937	author	Will Norris
fd4e937	added	38
fd4e937	deleted	7
fd4e937	files	1
fd4e937	body	Add the gate's bsnes-jg render (build/<slug>-jg.png) as a centered title card\nunder the H1 of every completed-demo plan (18 demos), copied to\ndocs/plans/screenshots/<slug>.png. One artifact, two uses: the same render is\nthe plan card AND the /snes-rom-page --preview, so no second screenshot is\ncollected. Fix factorial's broken plans/screenshots/ path (-> screenshots/).\n\nUpdate the snes-demo skill: plan template gains a title-card <img> slot, the\nverification steps gain a 'land the title card' step, the publish step switches\n--preview from the often-blank -mame.png to the full-colour -jg.png, and the\nsanity-check list documents the one-render-two-uses flow.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
bfcbe69	author	Will Norris
bfcbe69	added	587
bfcbe69	deleted	0
bfcbe69	files	1
bfcbe69	body	Moves the two SNES skills out of ~/.claude/skills/ (global) and into\n.claude/skills/ (tracked in the repo) so any checkout picks them up\nwithout manual setup.  Adds !.claude/skills/ to .gitignore's allowlist.\n\nPath changes vs the global copies:\n- snes-rom-page/SKILL.md: scaffold.sh invoked via\n  $(git rev-parse --show-toplevel)/.claude/skills/snes-rom-page/scaffold.sh\n  (was ~/.claude/skills/snes-rom-page/scaffold.sh)\n- snes-demo/SKILL.md: /home/will/SRC/... references replaced with\n  portable equivalents (git rev-parse / ~/SRC/...)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
