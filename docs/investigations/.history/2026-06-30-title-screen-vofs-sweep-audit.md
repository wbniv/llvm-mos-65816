| Date | Change |
|------|--------|
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/1f7fceb) | docs(audit): full per-demo VRAM/CGRAM/OAM init audit with preview thumbnails |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/0cb5bca) | docs(audit): add biohack.net preview thumbnails to rebuild audit table |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/12041dd) | docs(audit): add VRAM/OAM/CGRAM init sweep to title-screen rebuild audit |

<!--history-meta v1
1f7fceb	author	Will Norris
1f7fceb	added	61
1f7fceb	deleted	50
1f7fceb	files	1
1f7fceb	body	- Table now has VRAM/video init column for all 35 published demos\n- BGMODE-1/snesgfx demos: verified ✓ (reserve() pattern + per-demo CGRAM notes)\n- Mode-7 ⚠: avalanche/julia/mandel-float call m7_show() before chr data is\n  written; m7_tilemap_clear only DMA's VMDATAL (low bytes), leaving VMDATAH\n  (chr pixel data) at random power-on state for the full compute window\n- Fix pattern: vram_clear_all() two-pass DMA (low + high bytes), per buddha.c\n- newton note: tilemap palette field << 10 not << 12 guards against uninit palettes\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
0cb5bca	author	Will Norris
0cb5bca	added	37
0cb5bca	deleted	37
0cb5bca	files	1
0cb5bca	body	Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
12041dd	author	Will Norris
12041dd	added	155
12041dd	deleted	0
12041dd	files	1
12041dd	body	snes_ppu_reset_blank() zeroes control regs only — not VRAM/CGRAM/OAM\ndata. Mode-7 demos missing vram_clear_all() can show garbage before the\nfirst clean frame; mandel-double's slow double-precision compute makes\nthe window long enough to be user-visible. Logs the fix (add vram_clear_all\nafter snes_ppu_reset_blank, buddha.c pattern) as a tracked follow-on.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
