/* snesgfx — TextLayer: a tiled 2bpp text HUD that co-tenants BG3 with the BitmapCanvas.
 *
 * In BGMODE_1 only BG3 is 2bpp, and the canvas already lives there — so rather than burn a 4bpp layer
 * on text, the HUD shares BG3: the canvas owns tiles 0..256 and the BG3 layer registers; the font
 * glyphs occupy tiles FONT_BASE.. (chr words FONT_BASE*8..), and the HUD writes its strings into
 * tilemap rows OUTSIDE the canvas box (top + bottom bars). It IS a Drawable (in the Scene) but with
 * tm_bits = 0 (the canvas already enabled BG3); reserve() loads the font; emit() DMAs only the text
 * rows that changed. (The font's space glyph 0x20 is all-zero == the canvas blank tile, so they
 * coincide harmlessly at tile FONT_BASE.)
 *
 * Header-only (static inline). Reuses examples/snes/font8.h (the 2bpp 8x8 font, tools/gen-font8.py).
 * Completes the snesgfx library's text piece. See docs/plans/2026-06-27-11-snes-spirograph-...md. */
#ifndef SNESGFX_TEXT_LAYER_H
#define SNESGFX_TEXT_LAYER_H

#include <snes.h>
#include "drawable.h"
#include "upload.h"
#include "../font8.h"

#define TEXT_NROWS  2          // HUD bars: row[0] = top values, row[1] = bottom legend
#define TEXT_COLS   32
#define TEXT_FONT_BASE 256     // first font glyph tile# (right after canvas tiles 0..255 / blank 256)

typedef struct {
  Drawable base;
  uint16_t map_word;                       // shared BG3 tilemap base (same as the canvas)
  uint8_t  trow[TEXT_NROWS];               // tilemap row each HUD bar maps to
  uint16_t shadow[TEXT_NROWS * TEXT_COLS]; // tilemap-entry shadow for the bars
  uint8_t  dirty;                          // bit i set => re-DMA bar i
} TextLayer;

static void _text_reserve(Drawable *d, VramAlloc *va) {
  (void)va;
  TextLayer *t = (TextLayer *)d;
  /* Load the 2bpp font into BG3 char VRAM at the glyph tile base (force-blank). Each glyph = 8 words
     (plane 0 = bitmap, plane 1 = 0 -> ink is palette colour 1). */
  snes_vram_addr((uint16_t)(TEXT_FONT_BASE * 8));
  for (uint16_t i = 0; i < (uint16_t)FONT8_N * 8; i++) REG_VMDATA = FONT8[i];
}

static void _text_emit(Drawable *d, UploadQueue *q) {
  TextLayer *t = (TextLayer *)d;
  for (uint8_t i = 0; i < TEXT_NROWS; i++)
    if (t->dirty & (uint8_t)(1u << i))
      upq_push_vram(q, (uint16_t)(t->map_word + (uint16_t)t->trow[i] * TEXT_COLS),
                    &t->shadow[i * TEXT_COLS], 0x00, TEXT_COLS * 2, VMAIN_INC_HIGH_1);
  t->dirty = 0;
}

static const DrawableVT TEXT_VT = { _text_reserve, _text_emit };

static inline void text_init(TextLayer *t, uint16_t map_word, uint8_t top_row, uint8_t bot_row) {
  t->base.vt = &TEXT_VT;
  t->base.tm_bits = 0;                      // canvas already enables BG3
  t->map_word = map_word;
  t->trow[0] = top_row; t->trow[1] = bot_row;
  for (uint16_t i = 0; i < TEXT_NROWS * TEXT_COLS; i++) t->shadow[i] = TEXT_FONT_BASE;  // all spaces
  t->dirty = (uint8_t)((1u << TEXT_NROWS) - 1u);
}

/* Write NUL-terminated ASCII `s` into HUD bar `bar` (0/1) starting at column `col`. Glyph tile# =
   FONT_BASE + (ch - FONT8_FIRST); out-of-set chars render as space. Marks the bar dirty. */
static inline void text_puts(TextLayer *t, uint8_t bar, uint8_t col, const char *s) {
  uint16_t *row = &t->shadow[bar * TEXT_COLS];
  for (; *s && col < TEXT_COLS; s++, col++) {
    uint8_t ch = (uint8_t)*s;
    row[col] = (ch >= FONT8_FIRST && ch < FONT8_FIRST + FONT8_N)
                 ? (uint16_t)(TEXT_FONT_BASE + (ch - FONT8_FIRST)) : TEXT_FONT_BASE;
  }
  t->dirty |= (uint8_t)(1u << bar);
}

/* Clear HUD bar `bar` to spaces (marks dirty). */
static inline void text_clear_bar(TextLayer *t, uint8_t bar) {
  uint16_t *row = &t->shadow[bar * TEXT_COLS];
  for (uint8_t c = 0; c < TEXT_COLS; c++) row[c] = TEXT_FONT_BASE;
  t->dirty |= (uint8_t)(1u << bar);
}

#endif /* SNESGFX_TEXT_LAYER_H */
