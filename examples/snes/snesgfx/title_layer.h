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
#include "display.h"        /* title_begin/title_end drive the Display (add/frame/hold/hide) */
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
  /* --- cinematics state (driven by title_begin/title_end; emit() pushes it each frame) --- */
  int16_t     y0, y1;  /* line0/line1 vertical position, Q4 (row<<4); eased to the centre rows  */
  uint8_t     py0, py1;/* last integer tilemap rows drawn (cleared when a line moves)           */
  uint8_t     phase;   /* animation clock for the ink shimmer + the rainbow backdrop            */
  uint8_t     active;  /* 1 = emit() pushes the cinematics; 0 = static no-op                    */
  uint8_t     flyin;   /* 1 = emit() eases the lines in; 0 = hold them parked (during fade-up)  */
  uint8_t     restore; /* 1 = fade-out: drive the backdrop back to black for the demo           */
  uint16_t    ink;     /* live ink colour (CGRAM palette-7 colour 1) — persists for the DMA src  */
  uint16_t    back;    /* live backdrop colour (CGRAM[0]) — persists for the DMA src             */
  uint16_t    rbuf0[TITLE_COLS];  /* prebuilt BG2 tilemap row for line0 (centred glyphs)         */
  uint16_t    rbuf1[TITLE_COLS];  /* ... for line1                                               */
  uint16_t    rblank[TITLE_COLS]; /* an all-space row, used to clear a line's previous position  */
} TitleLayer;

#define TITLE_INK_IDX  (uint8_t)(TITLE_PAL * 16u + 1u)   /* CGRAM entry for the title ink (=113) */

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

/* Triangle wave 0..127..0 over a uint8 ramp — the building block of the rainbow backdrop. */
static inline uint8_t _title_tri(uint8_t x) { return (uint8_t)((x & 0x80u) ? (uint8_t)(255u - x) : x); }

/* Build one BG2 tilemap row (TITLE_COLS words) into `buf`: all spaces, with `s` centred. */
static void _title_build_row(uint16_t *buf, const char *s) {
  for (uint8_t i = 0; i < TITLE_COLS; i++) buf[i] = (uint16_t)(TITLE_PAL << 10);   /* space glyph */
  if (!s) return;
  uint8_t len = 0; for (const char *p = s; *p && len < TITLE_COLS; p++) len++;
  uint8_t col = (uint8_t)((TITLE_COLS - len) / 2u);
  for (const char *p = s; *p && col < TITLE_COLS; p++, col++)
    buf[col] = (uint16_t)((TITLE_PAL << 10) | _title_glyph((uint8_t)*p));
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

  /* Clear the whole 32x32 tilemap to the (all-zero) space glyph. */
  snes_vram_addr(TITLE_MAP_WORD);
  for (uint16_t i = 0; i < (uint16_t)(TITLE_COLS * TITLE_ROWS); i++)
    REG_VMDATA = (uint16_t)(TITLE_PAL << 10);       /* palette 7, tile 0 (space) */

  /* Prebuild the two text rows + a blank row (DMA sources for the per-frame fly-in). */
  _title_build_row(t->rbuf0, t->line0);
  _title_build_row(t->rbuf1, t->line1);
  _title_build_row(t->rblank, (const char *)0);

  /* Place line0 at the TOP edge (row 0) and line1 at the BOTTOM edge (row 27); emit() flies them in
     toward the centre rows. (Direct VRAM writes are safe — reserve runs in force-blank.) */
  snes_vram_addr((uint16_t)TITLE_MAP_WORD);
  for (uint8_t i = 0; i < TITLE_COLS; i++) REG_VMDATA = t->rbuf0[i];
  snes_vram_addr((uint16_t)(TITLE_MAP_WORD + 27u * TITLE_COLS));
  for (uint8_t i = 0; i < TITLE_COLS; i++) REG_VMDATA = t->rbuf1[i];
  t->y0 = 0;                    t->py0 = 0;
  t->y1 = (int16_t)(27 << 4);   t->py1 = 27;

  t->base.tm_bits = TM_BG2;
}

/* Per-frame cinematics: when active, fly the two text lines in from the top + bottom edges to the
 * centre (re-DMAing a line's tilemap row only when its integer row changes), shimmer the ink, and
 * cycle a rainbow backdrop. Everything goes through the UploadQueue (WRAM-only enqueue here; the
 * actual VRAM/CGRAM writes happen in upq_flush during the v-blank/force-blank window — the
 * access-window rule). When inactive (the demo is running) this is a no-op, so the layer stays
 * gate-neutral. */
static void _title_emit(Drawable *d, UploadQueue *q) {
  TitleLayer *t = (TitleLayer *)d;
  if (!t->active) return;

  /* fly-in (only once armed — title_begin fades up first with the lines parked at the edges, so the
     travel is seen at full brightness): ease each line's Q4 row toward its centre target, snapping
     the final sub-row so it settles exactly, and redraw only on an integer-row change. line0
     descends from the top edge, line1 rises from the bottom edge — they meet in the middle. */
  if (t->flyin) {
    int16_t tgt0 = (int16_t)(TITLE_ROW0 << 4), tgt1 = (int16_t)((TITLE_ROW0 + 2u) << 4);
    t->y0 = (int16_t)(t->y0 + ((tgt0 - t->y0) >> 3));
    t->y1 = (int16_t)(t->y1 + ((tgt1 - t->y1) >> 3));
    if ((int16_t)(tgt0 - t->y0) < 16) t->y0 = tgt0;   /* snap the last <1 row so the loop terminates */
    if ((int16_t)(t->y1 - tgt1) < 16) t->y1 = tgt1;
    uint8_t ny0 = (uint8_t)(t->y0 >> 4), ny1 = (uint8_t)(t->y1 >> 4);
    if (ny0 != t->py0) {
      upq_push_vram(q, (uint16_t)(TITLE_MAP_WORD + (uint16_t)t->py0 * TITLE_COLS), t->rblank, 0x00u, TITLE_COLS * 2u, VMAIN_INC_HIGH_1);
      upq_push_vram(q, (uint16_t)(TITLE_MAP_WORD + (uint16_t)ny0   * TITLE_COLS), t->rbuf0,  0x00u, TITLE_COLS * 2u, VMAIN_INC_HIGH_1);
      t->py0 = ny0;
    }
    if (ny1 != t->py1) {
      upq_push_vram(q, (uint16_t)(TITLE_MAP_WORD + (uint16_t)t->py1 * TITLE_COLS), t->rblank, 0x00u, TITLE_COLS * 2u, VMAIN_INC_HIGH_1);
      upq_push_vram(q, (uint16_t)(TITLE_MAP_WORD + (uint16_t)ny1   * TITLE_COLS), t->rbuf1,  0x00u, TITLE_COLS * 2u, VMAIN_INC_HIGH_1);
      t->py1 = ny1;
    }
  }

  t->phase = (uint8_t)(t->phase + 1u);
  if (!t->restore) {
    /* ink shimmer: a gentle brightness "breath" on the white title text. */
    uint8_t lvl = (uint8_t)(24u + (_title_tri((uint8_t)(t->phase << 1)) >> 4));   /* 24..31 */
    t->ink = (uint16_t)SNES_RGB(lvl, lvl, lvl);
    /* FLASHY cycling-rainbow backdrop: three 120°-shifted triangle waves → a smooth hue sweep. */
    uint8_t h = (uint8_t)(t->phase << 1);
    t->back = (uint16_t)SNES_RGB((uint8_t)(_title_tri(h)                  >> 2),
                                 (uint8_t)(_title_tri((uint8_t)(h + 85u)) >> 2),
                                 (uint8_t)(_title_tri((uint8_t)(h + 170u))>> 2));
  } else {
    /* fade-out: hold the ink, drive the backdrop back to black so the demo starts on black. */
    t->ink  = (uint16_t)SNES_RGB(28, 28, 28);
    t->back = 0u;
  }
  upq_push_cgram(q, TITLE_INK_IDX, &t->ink, 0x00u, 2u);   /* palette-7 colour 1 (the text ink) */
  upq_push_cgram(q, 0u,            &t->back, 0x00u, 2u);   /* CGRAM[0] backdrop */
}

static const DrawableVT TITLE_VT = { _title_reserve, _title_emit };

static inline void title_init(TitleLayer *t, const char *line0, const char *line1) {
  t->base.vt = &TITLE_VT;
  t->base.tm_bits = TM_BG2;
  t->line0 = line0;
  t->line1 = line1;
}

/* ------------------------------------------------------------------------------------------------
 * The shared title-screen subroutine every demo calls. title_begin() raises the title card;
 * title_end() holds it then tears it down. Splitting begin/end (rather than one all-in-one call) is
 * what lets the demos that do heavy pre-loop compute run it WHILE the title is up:
 *
 *   title_begin(d, &title, "NAME", "SUBTITLE");   // card up, force-blank released
 *   corpus_result = <gate>();                     // (optional) compute the PPU masks behind the card
 *   title_end(d, &title, 110);                    // hold ~2 s, then hand off to the demo's layer
 *
 * Centralising here means a single change to these two functions restyles every demo's intro at once.
 * Call title_begin AFTER adding the demo's own drawables (TitleLayer's reserve() writes the shared
 * BG12NBA char-base register last).
 * ------------------------------------------------------------------------------------------------ */

/* Raise the title card cinematically: reserve it, then FADE the master brightness up from black while
 * the text SLIDES in from the side and the backdrop drifts — all over ~16 v-blanks. After this returns
 * the card is fully lit; a demo may then run heavy pre-loop compute (the PPU holds the lit card). */
static inline void title_begin(Display *d, TitleLayer *t, const char *line0, const char *line1) {
  title_init(t, line0, line1);
  t->phase = 0; t->active = 1; t->restore = 0; t->flyin = 0;
  t->ink = (uint16_t)SNES_RGB(31, 31, 31); t->back = 0u;
  display_add(d, (Drawable *)t);     /* reserve(): builds rows, parks text top+bottom, inits y0/y1 */
  d->bright = 0;                     /* fade up to full with the lines parked at the edges ...       */
  display_fade(d, INIDISP_ON);
  t->flyin = 1;                      /* ... then fly them in to the centre at full brightness       */
  for (uint8_t g = 0; (t->py0 != (uint8_t)TITLE_ROW0 || t->py1 != (uint8_t)(TITLE_ROW0 + 2u)) && g < 48u; g++)
    display_frame(d);
}

/* Hold the lit card for `frames` v-blanks (the shimmer + backdrop animate), then FADE it out to black,
 * tear it down, and leave the brightness ramping back to full so the demo's first frames FADE IN. */
static inline void title_end(Display *d, TitleLayer *t, uint16_t frames) {
  display_hold(d, frames);           /* dwell: ink shimmer + backdrop drift */
  t->restore = 1;                    /* emit() now drives the backdrop back to black */
  display_fade(d, 0);                /* fade the card out to black */
  display_hide_layer(d, (Drawable *)t);
  t->active = 0;                     /* emit() reverts to a no-op (gate-neutral) */
  display_fade_to(d, INIDISP_ON);    /* the demo's main-loop frames ramp brightness back up → fade-in */
}

#endif /* SNESGFX_TITLE_LAYER_H */
