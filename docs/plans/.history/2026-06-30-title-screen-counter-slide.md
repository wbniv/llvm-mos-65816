| Date | Change |
|------|--------|
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/b6ef256) | feat(snesgfx): counter-sliding title screen — per-band BG2VOFS HDMA + TM masking |

<!--history-meta v1
b6ef256	author	Will Norris
b6ef256	added	291
b6ef256	deleted	0
b6ef256	files	1
b6ef256	body	Replace single shared BG2VOFS (both lines same direction) with 2-band\nHDMA on BG2VOFS: line0 (8×8) descends from top, line1 (16×16) rises\nfrom bottom, each with independent exponential ease-in (~2 s) and\nconstant-velocity ease-out (~1.2 s). Hold 2 s between.\n\nGeometry: line1 moved to tilemap rows 30-31 (y=240-255, below the\n224-line visible screen at vofs_bot=0); vofs_bot increases 0→128 to\nbring it into view at screen_row=112. No tilemap-wrap discontinuity.\n\nHDMA channels:\n  3 = BG2VOFS (2-band counter-slide, VSCROLL_BG2VOFS=0x10 — new)\n  4 = BG2HOFS (pixel-centring for line0, moved from ch 3)\n\nTM masking: title_begin() saves demo drawables' TM bits and shows only\nBG2 for the intro; title_end() restores them before fade-up, so canvas/\ntext/HUD layers are never visible during the title card.\n\nNew in hdma_hscroll.h: VSCROLL_BG{1-4}VOFS B-bus constants (0x0E-0x14).\nTITLE_HOLD_FRAMES=120 defined (not yet rolled to call sites).\n\nGate-verified on hilbert: hash 0x5999 unchanged.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
