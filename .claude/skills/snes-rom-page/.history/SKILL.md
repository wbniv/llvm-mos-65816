| Date | Change |
|------|--------|
| [2026-07-02](https://github.com/wbniv/llvm-mos-65816/commit/996f4b4) | docs+skill: SNES demos live under /snes/ — audit location column + skill path fix |
| [2026-07-01](https://github.com/wbniv/llvm-mos-65816/commit/bdbae81) | feat(skill): add category to snes-rom-page + page template chip |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/1f1a718) | docs(snes): record VBLANK/flicker sweep + display fixes; bsnes-jg render verifies ROM |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/bfcbe69) | chore(skills): add snes-demo + snes-rom-page as project-local skills |

<!--history-meta v1
996f4b4	author	Will Norris
996f4b4	added	18
996f4b4	deleted	5
996f4b4	files	1
996f4b4	body	- snes-rom-page skill: page path is site-specific — biohack.net demos go to\n  src/pages/snes/<slug>.astro (Base import ../../layouts/), NOT top-level, or the\n  gallery card (/snes/<slug>/) 404s. Fixed SKILL.md step 3 + Per-site + template\n  header. Also: deploy is 'task bump' (auto-tag+push), there is no 'task release'.\n- demo-ideas audit doc: added a 'Published-location audit' section — the location\n  column for all 107 published ROMs (all under /snes/) + the 2026-07-02 sweep record.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
bdbae81	author	Will Norris
bdbae81	added	7
bdbae81	deleted	1
bdbae81	files	1
bdbae81	body	snes-rom-page skill now requires a `category` input (one of 10 ids:\nfractals/physics/cellular/motion/algorithms/rendering/signals/bignums/\nciphers/classics). page-template.astro gains {{CATEGORY_ID}} and\n{{CATEGORY_LABEL}} placeholders that render a .rp-cat-chip pill linking\nback to the gallery shelf. Step 3 and step 4 docs updated accordingly.\nPlan: docs/plans/2026-07-01-snes-gallery-categories-netflix.md.\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
1f1a718	author	Will Norris
1f1a718	added	15
1f1a718	deleted	3
1f1a718	files	1
1f1a718	body	New plan docs/plans/2026-06-29-snes-vblank-flicker-sweep.md records the all-23-demo\nsweep, the three fixes (doom-fire halved refresh, rdiff title z-order, 1d-ca scroll\ntear), the hot-tree reproducibility note, and the v1.0.121 republish. Add dated\nupdate notes to the #7/#8/#6 plans pointing at it.\n\nUpdate the snes-rom-page skill verify step: a bsnes-jg screenshot of the ROM proves\nit renders (the page runs the same bsnes-jg WASM core) — Chrome is optional, only\nfor a page-shell check when the .astro/template changed.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
bfcbe69	author	Will Norris
bfcbe69	added	130
bfcbe69	deleted	0
bfcbe69	files	1
bfcbe69	body	Moves the two SNES skills out of ~/.claude/skills/ (global) and into\n.claude/skills/ (tracked in the repo) so any checkout picks them up\nwithout manual setup.  Adds !.claude/skills/ to .gitignore's allowlist.\n\nPath changes vs the global copies:\n- snes-rom-page/SKILL.md: scaffold.sh invoked via\n  $(git rev-parse --show-toplevel)/.claude/skills/snes-rom-page/scaffold.sh\n  (was ~/.claude/skills/snes-rom-page/scaffold.sh)\n- snes-demo/SKILL.md: /home/will/SRC/... references replaced with\n  portable equivalents (git rev-parse / ~/SRC/...)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
