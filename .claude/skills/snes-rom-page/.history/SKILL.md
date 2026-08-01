| Date | Change |
|------|--------|
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/f11eaff) | fix(snes-rom-page): restore the Fullscreen handler + block a third deletion |
| [2026-07-19](https://github.com/wbniv/llvm-mos-65816/commit/da5409b) | docs+dev: repoint ~/SRC references to the flat ~/ layout |
| [2026-07-02](https://github.com/wbniv/llvm-mos-65816/commit/996f4b4) | docs+skill: SNES demos live under /snes/ — audit location column + skill path fix |
| [2026-07-01](https://github.com/wbniv/llvm-mos-65816/commit/bdbae81) | feat(skill): add category to snes-rom-page + page template chip |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/1f1a718) | docs(snes): record VBLANK/flicker sweep + display fixes; bsnes-jg render verifies ROM |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/bfcbe69) | chore(skills): add snes-demo + snes-rom-page as project-local skills |

<!--history-meta v1
f11eaff	author	Will Norris
f11eaff	added	6
f11eaff	deleted	0
f11eaff	files	1
f11eaff	body	engine/app.js is the source of truth — scaffold.sh unconditionally copies it\nover <site>/public/play/app.js on every ROM publish — so fixing only the site\nwould be silently clobbered by the next demo.\n\nThe handler has now been deleted twice by unrelated ROM-rebuild commits\n(biohack.net 3733e8b, and earlier the Gray-Scott commit that 97035c7 undid),\neach time leaving ~111 pages with a button that highlights on hover and does\nnothing. Restored verbatim from 3733e8b^, with a DO-NOT-DELETE comment naming\nboth incidents.\n\nscaffold.sh now greps the INSTALLED play/app.js for requestFullscreen and\nfullscreenchange after the copy and aborts the publish if either is missing —\nasserting on what ships, not on the source. Verified the guard fires: a copy of\nthe engine with those identifiers stripped exits 2, the real engine passes.\nbiohack.net's deploy workflow carries the same check against dist/.\n\nSKILL.md's claim that app.js "wires a Fullscreen button" was true, then false,\nthen true again, with nothing to notice the middle state — that unverified claim\nis what let both deletions pass. Replaced with a warning that points at the\nguard.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
da5409b	author	Will Norris
da5409b	added	2
da5409b	deleted	2
da5409b	files	1
da5409b	body	The ~/SRC/<name> → ~/<name> flattening completed 2026-07-19; ~/SRC no\nlonger exists and there is no compat symlink, so every surviving\n~/SRC/... reference was dead.\n\nFunctional (verified against the filesystem):\n- dev/publish-web-roms.sh — the live default was\n  SITE="${HOME}/SRC/biohack.net", i.e. every invocation without --site\n  aborted with "no roms dir". Now ${HOME}/biohack.net;\n  ~/biohack.net/public/play/roms confirmed present.\n- dev/land-far-integration.sh — hardcoded /home/will/SRC/... for the\n  main checkout and for two SIBLING worktrees. ROOT now derives from\n  the script's own location and the siblings derive from ROOT\n  ("$ROOT-far-followups", "$ROOT-far-cc"), matching the\n  "$MAIN-$SLUG" convention in docs/howto-feature-worktree.md, so the\n  repo can live anywhere. Header notes that both worktrees must be\n  restored to re-run — neither is present on this machine (nor is the\n  gitignored vendor/llvm-mos), which is pre-existing and unrelated.\n- .claude/skills/{snes-demo,snes-rom-page}/SKILL.md — --site\n  ~/biohack.net; the per-site sections now cite ~/indri.studio and\n  ~/biohack.net. Both directories confirmed present.\n\nDocs (living, not dated snapshots):\n- CLAUDE.md, docs/howto-feature-worktree.md — ~/CLAUDE.md; the\n  relative link targets were already correct under the flat layout\n  since the parent of this repo is now ~.\n- docs/agent-handoff.md — the worktree registry's 16 sibling paths\n  repointed to /home/will/llvm-mos-65816-<slug>.\n- docs/howto-bulk-rebuild-republish-web-roms.md,\n  docs/snes-demo-cookbook.md — ~/biohack.net.\n- docs/investigations/snes-emulator-in-browser.md — ~/bsnes-jg-wasm\n  (present).\n- docs/ROADMAP.md — the M1 build-glue workspace is ~/llvm-mos-snes;\n  note it is not checked out on this machine.\n\nNot the vendored upstream: ~/llvm-mos is a separate checkout that this\nrepo never consumes — dev/toolchain.sh clones vendor/llvm-mos from\ngithub.com/llvm-mos/llvm-mos — so nothing was repointed at it, and its\nown LLVM_SRC_ROOT-style identifiers are not migration debt.\n\nLeft alone: dated point-in-time records under docs/plans/,\ndocs/handoffs/, docs/transcripts/ and .history/ sidecars; and SRC-in-\nanother-sense identifiers ($SRC in dev/*.sh, PLAYER_SRC, SUBSRC,\ntruchet.c's SRC table).\n\nVerified: bash -n clean on both edited scripts plus scaffold.sh;\ndev/publish-web-roms.sh -h exits 0; dev/test-worktree-teardown.sh\n26 passed / 0 failed; re-run of the SRC search leaves only dated\nrecords and the (pre-existing dirty, already-correct)\n.claude/memory/MEMORY.md.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_015uDBhrHoJFYhNJkNLhve4E
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
