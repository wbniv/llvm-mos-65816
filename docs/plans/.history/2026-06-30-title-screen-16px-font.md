| Date | Change |
|------|--------|
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/7f80226) | feat(snesgfx): title_layer 16×16 pixel-doubled font + reference survey |

<!--history-meta v1
7f80226	author	Will Norris
7f80226	added	96
7f80226	deleted	0
7f80226	files	1
7f80226	body	Add `title_begin16()` alongside the existing `title_begin()` so demos can\nopt into a 16×16 font: each 8×8 source glyph is pixel-doubled at load time\ninto 4 tiles (TL/TR/BL/BR = tiles 4g+0..4g+3). Both modes share one TitleLayer\nstruct via a `font16` flag; all 24 existing call sites are unchanged (8×8\ndefault). HDMA channel 3 is skipped in 16×16 mode — pixel centering is exact\nat the 16px tile boundary for every string length.\n\nAlso abbreviate two overlong title strings that exceed the 16-char 16×16 limit:\n- rdiff.c "REACTION DIFFUSION" (18) → "REACT DIFFUSION" (15)\n- 1d-ca.c "CELLULAR AUTOMATA" (17) → "CELL AUTOMATA" (13)\n\nGate-neutral verified: fn-plot corpus hash 0x2EBE unchanged in both modes.\n16×16 pixel-width confirmed by measurement (FN-PLOT: x=72–184, ≈112px = 7×16).\n\nAlso add:\n- docs/snes-title-screen.md — reference doc for the title system lifecycle\n- docs/investigations/snes-title-screens.md — 9-game SNES title screen survey\n  with screenshots (DKC, Super Metroid, F-Zero, Zelda, Mario World, Mega Man X,\n  Secret of Mana, Yoshi's Island, FF6) and synthesis section\n- docs/plans/2026-06-30-title-screen-16px-font.md — plan + verification evidence\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
-->
