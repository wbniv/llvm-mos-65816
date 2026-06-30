# Plan: 16×16 pixel-doubled title font (optional, alongside 8×8)

**Date:** 2026-06-30
**Motivation:** The investigation at `docs/investigations/snes-title-screens.md` found that
every reference SNES title uses a large logo (typically 24–40 px tall) while our `TitleLayer`
draws 8×8 text at ~11% screen height. The fix is to offer 16×16 as an option — not a forced
replacement, since some demos have long subtitles that need the 8×8 width.

## Design

Both font sizes coexist in a single `TitleLayer` struct. A `uint8_t font16` field selects the
mode; `_title_reserve()` and `_title_emit()` branch on it. The public API stays backward-
compatible:

```c
title_begin(d, &t, "NAME", "SUBTITLE");    // 8×8, all existing call sites unchanged
title_begin16(d, &t, "NAME", "SUBTITLE");  // 16×16 pixel-doubled, new
title_end(d, &t, frames);                  // shared for both
```

## What changes in `title_layer.h`

### Struct
- Add `uint8_t font16` field.
- `rbuf0`, `rbuf1`, `rblank` stay at `[TITLE_COLS * 2]` = 64 words (8×8 uses only `[0..31]`;
  16×16 uses all 64). Wastes 192 bytes in bss in 8×8 mode — acceptable for a title-only struct.
- Keep `HScroll2 hscroll` for 8×8 HDMA pixel-centring.

### Font loading in `_title_reserve()` — branches on `t->font16`

**8×8 path (existing):** 64 glyphs × 16 words = 1024 words at `TITLE_CHR_WORD`.

**16×16 path (new):** pixel-double each 8×8 glyph into 4 tiles (TL, TR, BL, BR = tiles
`4g+0..4g+3`). Each source bit doubled horizontally; each source row emitted twice vertically.
64 glyphs × 4 tiles × 16 words = 4096 words at `TITLE_CHR_WORD` (0x1000–0x1FFF).

### Tilemap building — branches on `t->font16`

**8×8:** `_title_build_row()` — 32-word row, 1 tile per char, max 32 chars, HDMA nudge needed.

**16×16:** `_title_build_row16()` — 64-word row-pair (top 32 + bottom 32), 2 tiles per char,
max `TITLE_MAX_CHARS = 16` chars, pixel centering exact (no HDMA needed).

### HDMA — conditional on `t->font16`

- `font16 = 0`: arm HDMA channel 3 (BG2HOFS) in `title_begin`, clear in `title_end`.
- `font16 = 1`: skip HDMA entirely; channel 3 stays free for demos.

### Initial parking and fly-in — branches on `t->font16`

- 8×8: line0 at row 0, line1 at row 27. `py1` target = `TITLE_ROW0 + 2 = 14`.
- 16×16: line0 at rows 0–1, line1 at rows 28–29 (off-screen). Fly-in DMA covers 2 rows
  (64 words, `TITLE_COLS * 4` bytes). `py1` target = `TITLE_ROW0 + 2 = 14` (same numeric
  value; means top-of-block is at row 14, bottom at row 15).

### New helpers
- `_title_expand_byte(uint8_t b) → uint16_t`: spread 8 bits to 16, each bit doubled.
- `_title_build_row16(buf[64], s)`: builds 64-word tilemap row-pair for 16×16 glyphs.
- `title_begin16(d, t, line0, line1)`: sets `t->font16 = 1` then calls shared setup.

### Demo string abbreviations (for 16×16 mode; 8×8 mode is unaffected)
The two strings that exceed `TITLE_MAX_CHARS = 16` were already abbreviated:
- `rdiff.c`: `"REACTION DIFFUSION"` (18) → `"REACT DIFFUSION"` (15) ✅ done
- `1d-ca.c`: `"CELLULAR AUTOMATA"` (17) → `"CELL AUTOMATA"` (13) ✅ done

These demos still use `title_begin` (8×8) so the change is cosmetic until they opt into 16×16.

## VRAM layout

```
0x0000  demo BG1/BG3 char data
0x1000  TitleLayer BG2 char data
          8×8 mode:  1024 words (glyphs 0–63 × 1 tile each)
          16×16 mode: 4096 words (glyphs 0–63 × 4 tiles each, 0x1000–0x1FFF)
0x2000  (free in 16×16 mode; free above 0x1400 in 8×8 mode)
0x5000  TitleLayer BG2 tilemap (1024 words, unchanged in both modes)
```

## VRAM layout after change
```
0x0000  demo BG1/BG3 char data
0x1000  TitleLayer BG2 char data (4096 words, glyphs 0–63 × 4 tiles each)
0x2000  (free)
0x5000  TitleLayer BG2 tilemap (1024 words, unchanged)
```

## Verification

1. ~~Build: `task compile` — zero errors.~~ PASS
2. ~~Gate: fn-plot corpus hash unchanged.~~ PASS `0x2EBE` (both 8×8 and 16×16 modes tested)
3. ~~Visual: 16×16 text renders correctly.~~ PASS — pixel measurement confirms:
   - `"FN-PLOT"` (len=7): starts at x=72 = tile-col 9 × 8px (exact 16×16 centering), spans ~106px ≈ 7×16=112px ✓
   - `"RECURSIVE PARSER"` (len=16): spans ~250px ≈ full 256px screen width = 16×16px ✓
   - Text height covers 2 tile rows (16px) as expected ✓
   - Screenshots: `docs/plans/screenshots/fn-plot-16x16-f{60,90,130}.png`
4. rdiff and 1d-ca string abbreviations — not yet verified visually (low priority; 8×8 path unchanged)
