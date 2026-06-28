/* snesgfx — TitleLayer: a drop-in title-screen overlay on BG2 (the universally-free layer).
 *
 * Every demo in the battery uses BG1 (newton/rdiff) or BG3 (canvas/text demos) — none use BG2 —
 * so a title can live on BG2 in BGMODE_1 without colliding with any demo's own layer. The content
 * is STATIC (a fixed name + subtitle), so the whole layer (char data, tilemap, palette) is written
 * directly in reserve() while the boot bracket still holds force-blank; emit() is a no-op and the
 * layer never touches the UploadQueue. This keeps it gate-neutral: it adds zero DMA jobs and the
 * demo's corpus hash (computed pre-loop) is unaffected.
 *
 * Lifecycle (display_hide_layer lives in display.h):
 *   display_init(d); display_add(d, <demo drawables>); display_add(d, &title.base);
 *   display_frame(d);                 // releases force-blank with the title visible over the demo's (black) layer
 *   <heavy pre-loop compute>          // no display_frame -> the PPU keeps showing the title the whole time
 *   display_hide_layer(d, &title.base); // clear TM_BG2: the title vanishes, the demo's layer takes over
 *   for (;;) { <render>; display_frame(d); }
 *
 * IMPORTANT: add the TitleLayer AFTER the demo's own drawables — its reserve() writes REG_BG12NBA
 * (the shared BG1/BG2 char-base register) last, preserving the BG1 nibble = 0 that the BG1 demos use.
 *
 * The 2bpp font8 glyphs are promoted to 4bpp (planes 2-3 = 0) so ink = palette colour 1. The title
 * uses CGRAM palette 7 (entries 112..127), clear of every demo's palettes (0-3). font8 is ASCII
 * 0x20..0x5F (UPPERCASE + digits + a little punctuation) — title strings must be uppercase.
 *
 * Header-only (static inline). Reuses examples/snes/font8.h. */
#ifndef SNESGFX_TITLE_LAYER_H
#define SNESGFX_TITLE_LAYER_H

#include <snes.h>
#include "drawable.h"
#include "../font8.h"

#ifndef TITLE_CHR_WORD
#define TITLE_CHR_WORD  0x1000u   /* BG2 char base (4K-word granular -> BG12NBA high nibble = 1)   */
#endif
#ifndef TITLE_MAP_WORD
#define TITLE_MAP_WORD  0x5000u   /* BG2 tilemap base (clear of the demos' 0x0000..0x4400 regions) */
#endif
#define TITLE_PAL       7u        /* CGRAM palette 7 (entries 112..127) — clear of demo palettes 0-3 */
#define TITLE_COLS      32u
#define TITLE_ROWS      32u

typedef struct {
  Drawable    base;
  const char *line0;   /* centred on TITLE_ROW0      (NULL = skip) */
  const char *line1;   /* centred on TITLE_ROW0 + 2  (NULL = skip) */
} TitleLayer;

#define TITLE_ROW0  12u   /* vertical placement: line0 mid-screen, line1 two rows below */

/* font8 tile# for an ASCII char (space / out-of-set -> the all-zero space glyph, tile 0). */
static inline uint16_t _title_glyph(uint8_t ch) {
  return (ch >= FONT8_FIRST && ch < (uint8_t)(FONT8_FIRST + FONT8_N))
           ? (uint16_t)(ch - FONT8_FIRST) : 0u;
}

/* Write one centred NUL-terminated string into BG2 tilemap row `row` (direct VRAM, force-blank). */
static void _title_put_centred(uint16_t row, const char *s) {
  if (!s) return;
  uint8_t len = 0;
  for (const char *p = s; *p && len < TITLE_COLS; p++) len++;
  uint8_t col = (uint8_t)((TITLE_COLS - len) / 2u);
  snes_vram_addr((uint16_t)(TITLE_MAP_WORD + row * TITLE_COLS + col));
  for (const char *p = s; *p && col < TITLE_COLS; p++, col++)
    REG_VMDATA = (uint16_t)((TITLE_PAL << 10) | _title_glyph((uint8_t)*p));
}

static void _title_reserve(Drawable *d, VramAlloc *va) {
  (void)va;
  TitleLayer *t = (TitleLayer *)d;

  /* BG2 layer registers. BG12NBA: BG2 char base = TITLE_CHR_WORD (high nibble), BG1 = 0 (low). */
  REG_BG2SC   = SNES_BGSC(TITLE_MAP_WORD, 0);
  REG_BG12NBA = (uint8_t)(((TITLE_CHR_WORD >> 12) & 0x0Fu) << 4);

  /* Palette 7 colour 1 = white (the ink). Colour 0 stays transparent (pixel 0 on a BG). Direct
     CGRAM write is safe in force-blank (reserve runs before display_frame releases the blank). */
  REG_CGADD  = (uint8_t)(TITLE_PAL * 16u);          /* entry 112 (palette 7, colour 0) */
  REG_CGDATA = 0x00; REG_CGDATA = 0x00;             /* colour 0 = black (transparent on BG anyway) */
  REG_CGDATA = 0xFF; REG_CGDATA = 0x7F;             /* colour 1 = white  (BGR555 0x7FFF)            */

  /* Load the font promoted to 4bpp at BG2 tiles 0..FONT8_N-1: 8 words planes 0&1 (the glyph),
     then 8 zero words planes 2&3 -> ink = colour 1. */
  snes_vram_addr(TITLE_CHR_WORD);
  for (uint16_t g = 0; g < FONT8_N; g++) {
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = FONT8[g * 8u + r];
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
  }

  /* Clear the whole 32x32 tilemap to the (all-zero) space glyph, then lay the centred lines. */
  snes_vram_addr(TITLE_MAP_WORD);
  for (uint16_t i = 0; i < (uint16_t)(TITLE_COLS * TITLE_ROWS); i++)
    REG_VMDATA = (uint16_t)(TITLE_PAL << 10);       /* palette 7, tile 0 (space) */
  _title_put_centred(TITLE_ROW0,      t->line0);
  _title_put_centred(TITLE_ROW0 + 2u, t->line1);

  t->base.tm_bits = TM_BG2;
}

static void _title_emit(Drawable *d, UploadQueue *q) { (void)d; (void)q; }  /* static: nothing per-frame */

static const DrawableVT TITLE_VT = { _title_reserve, _title_emit };

static inline void title_init(TitleLayer *t, const char *line0, const char *line1) {
  t->base.vt = &TITLE_VT;
  t->base.tm_bits = TM_BG2;
  t->line0 = line0;
  t->line1 = line1;
}

#endif /* SNESGFX_TITLE_LAYER_H */
