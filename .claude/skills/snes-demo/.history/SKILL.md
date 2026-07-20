| Date | Change |
|------|--------|
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/d65c75e) | fix(fn-plot): add TitleLayer intro + canvas_line curves + 2px/frame; update snes-demo skill |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/1194065) | docs(snes-demo skill): make the prime directive explicit — stress the compiler, never work around it |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/fd4e937) | docs(snes): title-card screenshots on all completed demo plans + skill |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/bfcbe69) | chore(skills): add snes-demo + snes-rom-page as project-local skills |

<!--history-meta v1
d65c75e	author	Will Norris
d65c75e	added	57
d65c75e	deleted	13
d65c75e	files	1
d65c75e	body	fn-plot.c:\n  - Add TitleLayer ("FN-PLOT" / "RECURSIVE PARSER") wrapping corpus_result\n    computation — every demo requires the animated title intro card\n  - Replace canvas_plot with canvas_line connecting consecutive columns;\n    track prev_py in App struct to eliminate gaps on steep curve sections\n  - PIXELS_PER_FRAME 1→2 (64 frames per curve, ~1 s draw time)\n  - Fix char buf[7]→buf[21] (progress bar needed 20+NUL)\n\nSKILL.md (snes-demo):\n  - Add TitleLayer row to component guide, marked "Required for every demo"\n  - Add canonical title_begin/title_end pattern with code example\n  - Verification step 6: check demo animation is running (not blank canvas)\n  - Publication step 9: two-stage publish — default-8-bit first, then\n    verified +mos-a16 overwrites after full differential gate confirms\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
1194065	author	Will Norris
1194065	added	52
1194065	deleted	6
1194065	files	1
1194065	body	Add a top-of-skill section: the demos exist to surface compiler bugs; a differential\ndisagreement (or -verify/assembler/crash) is a COMPILER defect to isolate -> diagnose ->\nfix in vendor/llvm-mos -> regen-patch -> queue upstream, NEVER to paper over by reshaping\nthe demo (forbidden list: casts, expr splits, width/op swaps, volatile, -O0, GATE_N\nshrink, dodging the construct). The differential gate is the arbiter: host value is ground\ntruth. One exception spelled out: a bug in the demo's OWN render code (gate still green) is\na demo bug — fix the display (precedent: #21/#22 Mode-7 collapses). Strengthen step-7\ntriage to route real miscompiles into the protocol.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
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
