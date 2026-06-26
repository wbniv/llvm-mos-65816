| Date | Change |
|------|--------|
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/de9101c) | docs(invaders): record as-built status — game verified, page committed, deploy pending |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/3e87d01) | docs(invaders-plan): add P7 — publish playable page at biohack.net/space-invaders |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/1d753fe) | #321 snesgfx P0: OOP rendering library core + SpriteSet (OAM front-end) |

<!--history-meta v1
de9101c	author	Will Norris
de9101c	added	19
de9101c	deleted	0
de9101c	files	1
de9101c	body	Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3e87d01	author	Will Norris
3e87d01	added	9
3e87d01	deleted	3
3e87d01	files	1
3e87d01	body	Per request: ship build/invaders-a16.sfc to a playable in-browser page at\nhttps://www.biohack.net/space-invaders/ via the snes-rom-page skill (bsnes-jg\nWASM). Hard prereq: the bsnes 3x-capture determinism check (already enforced by\ndev/invaders.sh) — the page runs bsnes-jg, so any power-on flap would show there.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
1d753fe	author	Will Norris
1d753fe	added	243
1d753fe	deleted	0
1d753fe	files	1
1d753fe	body	Header-only snesgfx library (the approved Space-Invaders-on-snesgfx plan, P0):\n- display.h Display (root context; boot bracket; owns queue/vram/scene; BGMODE_1)\n- upload.h UploadQueue (v-blank/force-blank-gated DMA queue; access-window rule)\n- vram.h VramAlloc; drawable.h Drawable (coarse vtable seam); scene.h Scene\n- sprite_set.h SpriteSet: the new OAM front-end (544B contiguous shadow,\n  put/move/hide/palette, 2-bit high-table packing, emit() DMAs OAM, reserve()\n  sets OBSEL + TM_OBJ). OAM was raw-registers-only before (handoff Sprites).\n\ninvaders.c P0 smoke: a 5-sprite proto-fleet via the OAM shadow DMA; runtime 4bpp\ntile so it links standalone (real gfx4snes art via objcopy/Option B next). No far\npointers -> builds default + a16 + xy16.\n\nVerified: compiles all 3 modes, -verify-machineinstrs clean; boots + runs on MAME\nand bsnes-jg (sentinel==0x42). Visual sprite verification pending the Xvfb path.\nPlan updated to Option B (objcopy -O elf32-mos into ROM .rodata) + TODO entry.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
