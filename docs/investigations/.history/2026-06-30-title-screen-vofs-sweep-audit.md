| Date | Change |
|------|--------|
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/0cb5bca) | docs(audit): add biohack.net preview thumbnails to rebuild audit table |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/12041dd) | docs(audit): add VRAM/OAM/CGRAM init sweep to title-screen rebuild audit |

<!--history-meta v1
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
