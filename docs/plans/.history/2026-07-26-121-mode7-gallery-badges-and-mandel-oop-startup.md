| Date | Change |
|------|--------|
| [2026-09-15](https://github.com/wbniv/llvm-mos-65816/commit/3dbabec1) | fix(snesgfx): m7splash_begin owns the PPU control block from power-on |
| [2026-09-15](https://github.com/wbniv/llvm-mos-65816/commit/24f334f3) | 121 verify: gate 22 on indri closed live (23/23); title-window entropy sensitivity recorded + deferred |
| [2026-09-14](https://github.com/wbniv/llvm-mos-65816/commit/61767534) | docs(121/123): reconcile the Mode 7 gallery website gates with reality; re-verify both plans |
| [2026-08-04](https://github.com/wbniv/llvm-mos-65816/commit/1a9d9b89) | fix(121/123): halve the mandel-oop startup black window; land the Mode 7 data contract |
| [2026-08-03](https://github.com/wbniv/llvm-mos-65816/commit/ab6a541b) | docs(mode7-gallery): record 121-badges plan verification (18/23 PASS) |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/bdbf5168) | feat: add Mode 7 gallery UX and progressive Mandelbrot |

<!--history-meta v1
3dbabec1	author	Will Norris
3dbabec1	added	318
3dbabec1	deleted	8
3dbabec1	files	1
3dbabec1	body	m7splash_begin() is the first thing a Mode 7 demo puts on screen and it runs\nbefore display_init(), which holds the boot path's only snes_ppu_reset_blank().\ncrt0 writes just NMITIMEN and INIDISP, so every other PPU control register\n($2101..$2133) reaches the splash at power-on state - random() per register\nunder bsnes-jg's own default Low entropy, which is what the web player runs.\n\nThe splash writes only the registers it uses, so the rest decided the picture.\nCGWSEL $2130 bits 7-6 - the main-screen colour-window "clip to black" region -\nis the decisive one: 3 clips always (a wholly black title card), 1/2 clip\ninside/outside a colour window whose bounds are equally random (black bands\nacross the glyphs), 0 renders correctly. SETINI, MOSAIC and the window\nregisters add smaller corruption on top. mandel-oop showed it because its\nmain() is written to "only Display API, zero bare REG_*/snes_* calls", so its\nsole reset is inside display_init() - after the splash. snes-video-reel and\napollo-reel have no reset at all; the other eight adopters call\nsnes_ppu_reset_blank() themselves right before the splash, which is the\nprecondition this moves into the facility that needs it.\n\nEvidence, mandel-oop at JGX_ENTROPY=1, frames 60/100/120/200:\n  before  8/8 runs differ from the entropy-0 render at every frame\n          (0.00% / 7.39% / 34.28% / 66.29% / 96.43% non-black, run to run)\n  after   20/20 runs identical to it at every frame\nThe entropy-0 reference hashes are unchanged, so the title card looks exactly\nas it did; only its determinism improves.\n\ndev/title-entropy.sh is the regression guard: one JGX_ENTROPY=0 render plus N\nJGX_ENTROPY=1 renders per frame, all required to hash identically.\n\nBattery: dev/run.sh build 255 built / 3 excluded by contract / 0 failed;\ncorpus 63/63; corpus-a16 62/62, 0 xfail - all equal to the pre-change baseline.\nROM bytes change for the 11 m7title.h adopters (mandel-oop\n83c1f0a02f7b54dd -> 2b92f51e316c46d7, corpus_result still 0x204F);\ntitle_layer.h adopters are untouched and already pass the gate. Republishing\nis user-gated and not done here.\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa
24f334f3	author	Will Norris
24f334f3	added	89
24f334f3	deleted	5
24f334f3	files	1
24f334f3	body	Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa
61767534	author	Will Norris
61767534	added	548
61767534	deleted	0
61767534	files	1
61767534	body	One decision table (docs/plans/2026-09-14-m7-gallery-web-reconcile.md) for 121 gates\n11/17/20/22/23 and 123 steps 2/4/10. Every row is "fix the gate" with the commit that made the\nchange intentional — nothing on either site was wrong:\n- 17 / 123-2 / 123-4: "nine" = the ledgered contract count (cdaa6f4, ad87374, 1a9d9b8).\n- 11: re-baselined to the committed dev/m7blank.sh budget (5 <= 6; floor 1 per 2026-08-05).\n- 20: compare deployed bytes to the last publication record; demo-source drift -> republish,\n  toolchain-only drift -> accepted divergence. Today is source drift (13ebe3e, e2f3cd0, b6ab8b5):\n  republish staged, unpushed, on snes/mandel-oop-republish in both site repos.\n- 22 / 123-10: verification steps, not CI deps — executed in host Chrome over DevTools\n  (dev/m7web/, no tooling added to either site repo).\n- 23: was a mis-measurement — both sites have shipped a content-hash bust map since 07-26/27\n  (3aeb92d, 2208cb0, c7988ac); the browser's requests carry ?v=<sha>.\n\nRe-run against main @ 294bc8c: plan 121 22/23 (only #22 on indri, the tracked [wip T2] player\ndefect), plan 123 10/10 (steps 3-9 executed for real, step 10 at 320 px + reduced motion).\n\nCo-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa\n(cherry picked from commit 9d3660e6fc489a223ac99c764f53512f71baaab8)
1a9d9b89	author	Will Norris
1a9d9b89	added	447
1a9d9b89	deleted	0
1a9d9b89	files	1
1a9d9b89	body	Re-runs both verification records. 121: 18/23 -> 19/23. 123: 7/10 -> 9/10.\n\nmandel-oop startup (121 gate 11, 24 -> 11 black frames)\n  The 24-frame black panel between title exit and the loading field was not a\n  handoff-sequencing defect -- every Part-3 handoff requirement was already met.\n  It was the wall-clock duration of _mandel_reserve(), which painted the loading\n  checker across the 64x56 FAR framebuffer and then read all 3,584 bytes back out\n  through build_chr_row(): ~7,200 far accesses under force-blank to build a texture\n  that never needed the round-trip. Part 4 already forbade this ("install a small\n  deterministic loading texture", not the full grid).\n\n  1u + (((x >> 3) ^ (y >> 3)) & 7u) is constant over an 8x8 tile, so the checker is\n  now generated straight into the tiled chr staging buffer. Same picture, no fb\n  round-trip. Nothing needed the prefill: every fb byte is written by build_step()\n  before it is read, and even the COARSE pass expands to all 56 rows, so crc_fb_oop()\n  still CRCs a fully written buffer.\n\n  0x204F unchanged on host, bsnes-jg and MAME; -verify clean; 1 indirect dispatch;\n  3x byte-identical captures; .text 6,331 -> 6,274 B.\n\n  Residual 11 frames is a shared-library floor, not demo-local: mandel-display, same\n  m7splash(), holds black 72 frames from the same f=239 seam. Closing it means\n  changing m7splash_end()/display_init() so the boot force-blank window is not\n  re-opened after the title -- cross-cutting across all seven Mode 7 demo main()s,\n  already logged in docs/agent-handoff.md. ESCALATED, not attempted.\n\nMode 7 data contract (123 steps 2 and 4)\n  The plan's build-time assertion and tests/snes-mode7-filter.test.mjs had never been\n  implemented on either site, which is why cdaa6f4/ad87374 drifted the badge/filter set\n  from 9 to 11 in silence. Both now exist (site repos, committed separately). The count\n  is derived from each demo registry; the only committed list is the ledger, whose job\n  is to make a count change reviewed rather than silent.\n\n  The plan's stale "nine" is annotated, not rewritten: an "Amendment -- 2026-08-04"\n  records both added demos as legitimate and restates every numeral as the derived\n  contract count.\n\nRemaining red, all out of scope here: 121 #20/#23 deploy-gated, 121 #22 and 123 #10\nBLOCKED-no-harness, 121 #11 escalated. Nothing was published.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
ab6a541b	author	Will Norris
ab6a541b	added	437
ab6a541b	deleted	0
ab6a541b	files	1
ab6a541b	body	Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
bdbf5168	author	Will Norris
bdbf5168	added	452
bdbf5168	deleted	0
bdbf5168	files	1
-->
