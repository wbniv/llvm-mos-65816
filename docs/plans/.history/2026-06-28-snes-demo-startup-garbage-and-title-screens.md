| Date | Change |
|------|--------|
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/8f87929) | feat(snes): fix Newton startup garbage + add title screens to the demo battery |

<!--history-meta v1
8f87929	author	Will Norris
8f87929	added	297
8f87929	deleted	0
8f87929	files	1
8f87929	body	Two user-reported issues against the published SNES demos:\n\n1. Newton's fractal booted to garbage colours. Root cause: commit ac9c0b2\n   regressed the BG tilemap word from `root<<10` to `root<<12`; the palette\n   field is bits 10-12 (hud.h:46), so `<<12` selected uninitialised CGRAM\n   palettes 4-5. Reverted to `root<<10`. Also fixed factorial's HUD palette\n   (1<<13 priority-bit -> 2<<10, the CGRAM-8 palette).\n\n2. Demos showed a blank screen during the slow pre-loop gate-hash compute.\n   New snesgfx/title_layer.h (BG2 4bpp static overlay, 2bpp font promoted to\n   4bpp, written in force-blank, no DMA) + display_hide_layer()/display_hold()\n   in display.h, and snesgfx/splash.h (BGMODE_1 BG3 splash for the Mode-7\n   demos). Titles wired into 10 demos: newton, spirograph, n-body,\n   double-pendulum, spigot, 1d-ca (TITLE_CHR_WORD=0x6000 override), rdiff,\n   invaders (in-loop overlay), mandel-display, blossom. All gate-neutral.\n\nDrive-by: fixed n-body.c's pre-existing broken include (nbody.h -> n-body.h;\nthe file is n-body.h and the host oracle includes it) — it did not compile at\nHEAD.\n\nVerified on the bsnes-jg WASM core: Newton renders garbage-free; all titles\nrender; every demo's corpus_result/CRC unchanged (display-only) — newton\n0x4D8B, spirograph 0x32D4, invaders 0x9D57, mandel 0x204F, blossom grid 0x9047\n+ controller replay, all == host. Re-published live to biohack.net (v1.0.105).\n\nPlan: docs/plans/2026-06-28-snes-demo-startup-garbage-and-title-screens.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
