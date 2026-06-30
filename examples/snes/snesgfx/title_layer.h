/* snesgfx — TitleLayer: a drop-in title-screen overlay on BG2 (the universally-free layer).
 *
 * Every demo in the battery uses BG1 (newton/rdiff) or BG3 (canvas/text demos) — none use BG2 —
 * so a title can live on BG2 in BGMODE_1 without colliding with any demo's own layer. Char data,
 * tilemap and palette are written directly in reserve() under force-blank; the CINEMATIC intro
 * (title_begin..title_end) then animates via emit(): the two lines fly in vertically (slow constant
 * velocity, meeting at the centre rows), the ink shimmers, and a rainbow backdrop cycles — all
 * enqueued on the UploadQueue and flushed in v-blank. Each line is PIXEL-centred by an HDMA stream
 * on BG2HOFS (channel 3, 8×8 mode only) so two lines of different character-parity centre
 * independently (tile placement only lands on the 8 px grid).
 *
 * Two font modes, selected per title card:
 *
 *   title_begin(d, &t, line0, line1)   — 8×8 font (default; all existing demos)
 *   title_begin16(d, &t, line0, line1) — 16×16 pixel-doubled font (new; short strings)
 *
 * 8×8 mode:  64 glyphs × 1 tile × 16 words = 1024 words at TITLE_CHR_WORD. Max 32 chars/line.
 *            HDMA channel 3 armed on BG2HOFS for sub-tile pixel centring.
 * 16×16 mode: each 8×8 glyph is pixel-doubled into 4 tiles (TL/TR/BL/BR = tiles 4g+0..4g+3).
 *            64 glyphs × 4 tiles × 16 words = 4096 words (0x1000–0x1FFF). Max 16 chars/line.
 *            Centering is exact at the 16 px boundary — no HDMA needed, channel 3 stays free.
 *
 * Gate-neutral: once title_end() sets active=0, emit() is a no-op; the demo's corpus hash
 * (computed pre-loop) and its own layers/HDMA are unaffected.
 *
 * Lifecycle:
 *   display_init(d); display_add(d, <demo drawables>); display_add(d, &title.base);
 *   display_frame(d);       // releases force-blank with the title visible over the demo's layer
 *   <heavy pre-loop compute>
 *   display_hide_layer(d, &title.base);
 *   for (;;) { <render>; display_frame(d); }
 *
 * Strings must be UPPERCASE ASCII (font8 covers 0x20..0x5F).
 * Add the TitleLayer AFTER the demo's own drawables — reserve() writes REG_BG12NBA last.
 *
 * Header-only (static inline). Reuses examples/snes/font8.h. */
#ifndef SNESGFX_TITLE_LAYER_H
#define SNESGFX_TITLE_LAYER_H

#include <snes.h>
#include "drawable.h"
#include "display.h"
#include "hdma_hscroll.h"
#include "../font8.h"

#ifndef TITLE_CHR_WORD
#define TITLE_CHR_WORD  0x1000u   /* BG2 char base (4K-word granular → BG12NBA high nibble = 1)   */
#endif
#ifndef TITLE_MAP_WORD
#define TITLE_MAP_WORD  0x5000u   /* BG2 tilemap base (clear of demos' 0x0000..0x4400 regions)    */
#endif
#define TITLE_PAL        7u       /* CGRAM palette 7 (entries 112..127) — clear of demo palettes  */
#define TITLE_COLS       32u
#define TITLE_ROWS       32u
#define TITLE_MAX_CHARS  16u      /* max chars/line in 16×16 mode (TITLE_COLS / 2 cols per glyph) */

/* TITLE_RBUF_COLS — row-buffer width in words. Default is TITLE_COLS*2 (64 words) to hold both
   the top and bottom tile rows for 16×16 fly-in DMA. For tight-RAM demos that only use the 8×8
   font (title_begin), define TITLE_RBUF_COLS=TITLE_COLS before including this header to get
   the compact 32-word buffers. */
#ifndef TITLE_RBUF_COLS
#define TITLE_RBUF_COLS (TITLE_COLS * 2u)
#endif

#define TITLE_FLY_STEP   3        /* vertical fly-in speed, Q4 (row<<4) units/frame               */
#define TITLE_HDMA_CHAN  3u        /* HDMA channel for 8×8 BG2HOFS pixel-centre (0=GP-DMA UpQ,
                                     1-2=hud.h split; 3 is free during the intro)                 */

typedef struct {
  Drawable    base;
  const char *line0;   /* centred on TITLE_ROW0      (NULL = skip) */
  const char *line1;   /* centred on TITLE_ROW0 + 2  (NULL = skip) */
  /* --- cinematics state --- */
  int16_t     y0, y1;  /* line0/line1 vertical position, Q4 (row<<4); eased to centre rows       */
  uint8_t     py0, py1;/* last integer tilemap rows drawn (top of block for 16×16 mode)           */
  uint8_t     phase;   /* animation clock for ink shimmer + rainbow backdrop                       */
  uint8_t     active;  /* 1 = emit() pushes cinematics; 0 = static no-op                          */
  uint8_t     flyin;   /* 1 = emit() eases lines in; 0 = hold parked (during fade-up)             */
  uint8_t     restore; /* 1 = fade-out: drive backdrop back to black                               */
  uint8_t     font16;  /* 0 = 8×8 (default), 1 = 16×16 pixel-doubled                             */
  uint16_t    ink;     /* live ink colour (CGRAM palette-7 colour 1)                               */
  uint16_t    back;    /* live backdrop colour (CGRAM[0])                                          */
  /* Row buffers: TITLE_RBUF_COLS words each (default 64 = top+bottom tile rows for 16×16;
     override to TITLE_COLS=32 for tight-RAM 8×8-only demos). */
  uint16_t    rbuf0[TITLE_RBUF_COLS];
  uint16_t    rbuf1[TITLE_RBUF_COLS];
  uint16_t    rblank[TITLE_RBUF_COLS];
  HScroll2    hscroll;  /* HDMA table for 8×8 pixel-centre (built but unused in 16×16 mode)       */
} TitleLayer;

#define TITLE_INK_IDX  (uint8_t)(TITLE_PAL * 16u + 1u)   /* CGRAM entry for ink (=113) */
#define TITLE_ROW0      12u   /* centre row for line0; line1 top = TITLE_ROW0 + 2 */

/* Glyph index for an ASCII char (space / out-of-set → 0). */
static inline uint16_t _title_glyph(uint8_t ch) {
  return (ch >= FONT8_FIRST && ch < (uint8_t)(FONT8_FIRST + FONT8_N))
           ? (uint16_t)(ch - FONT8_FIRST) : 0u;
}

/* BG2HOFS nudge for pixel-exact centring of one 8×8-font line (null/empty → 0). */
static inline int16_t _title_hofs(const char *s) {
#ifdef TITLE_PIXEL_CENTER_OFF
  (void)s; return 0;
#else
  if (!s) return 0;
  uint8_t len = 0; for (const char *p = s; *p && len < TITLE_COLS; p++) len++;
  uint8_t col = (uint8_t)((TITLE_COLS - len) / 2u);
  return (int16_t)((int16_t)(8 * (int16_t)col) + (int16_t)(4 * (int16_t)len) - 128);
#endif
}

/* Build one 32-word BG2 tilemap row into buf: all spaces, with s centred (8×8 font). */
static void _title_build_row(uint16_t *buf, const char *s) {
  for (uint8_t i = 0; i < TITLE_COLS; i++) buf[i] = (uint16_t)(TITLE_PAL << 10);
  if (!s) return;
  uint8_t len = 0; for (const char *p = s; *p && len < TITLE_COLS; p++) len++;
  uint8_t col = (uint8_t)((TITLE_COLS - len) / 2u);
  for (const char *p = s; *p && col < TITLE_COLS; p++, col++)
    buf[col] = (uint16_t)((TITLE_PAL << 10) | _title_glyph((uint8_t)*p));
}

/* Triangle wave 0..127..0 — building block for the rainbow backdrop. */
static inline uint8_t _title_tri(uint8_t x) { return (uint8_t)((x & 0x80u) ? (uint8_t)(255u - x) : x); }

/* ── 16×16 helpers ─────────────────────────────────────────────────────────────────────────── */

/* Pixel-double one 8-bit plane row to 16 bits: each source bit → 2 adjacent bits (MSB=left). */
static inline uint16_t _title_expand_byte(uint8_t b) {
  uint16_t r = 0;
  for (uint8_t i = 0; i < 8u; i++) {
    if (b & (uint8_t)(0x80u >> i)) r |= (uint16_t)(0xC000u >> (uint8_t)(i << 1u));
  }
  return r;
}

/* Build a 64-word BG2 tilemap buffer for one 16×16-font line.
   Words [0..31] = top tile row, words [32..63] = bottom tile row.
   Each glyph occupies 2 consecutive tile columns: tiles 4g+0/+1 (top), 4g+2/+3 (bottom). */
static void _title_build_row16(uint16_t *buf, const char *s) {
  for (uint8_t i = 0; i < (uint8_t)(TITLE_COLS * 2u); i++) buf[i] = (uint16_t)(TITLE_PAL << 10);
  if (!s) return;
  uint8_t len = 0;
  for (const char *p = s; *p && len < (uint8_t)TITLE_MAX_CHARS; p++) len++;
  uint8_t col = (uint8_t)((TITLE_COLS - 2u * len) / 2u);
  for (const char *p = s; *p && col < (uint8_t)(TITLE_COLS - 1u); p++, col += 2u) {
    uint16_t gi   = _title_glyph((uint8_t)*p);
    uint16_t base = (uint16_t)(TITLE_PAL << 10);
    buf[col]                    = (uint16_t)(base | (uint16_t)(4u * gi + 0u));
    buf[col + 1u]               = (uint16_t)(base | (uint16_t)(4u * gi + 1u));
    buf[TITLE_COLS + col]       = (uint16_t)(base | (uint16_t)(4u * gi + 2u));
    buf[TITLE_COLS + col + 1u]  = (uint16_t)(base | (uint16_t)(4u * gi + 3u));
  }
}

/* ── reserve ────────────────────────────────────────────────────────────────────────────────── */

static void _title_reserve(Drawable *d, VramAlloc *va) {
  (void)va;
  TitleLayer *t = (TitleLayer *)d;

  REG_BG2SC   = SNES_BGSC(TITLE_MAP_WORD, 0);
  REG_BG12NBA = (uint8_t)(((TITLE_CHR_WORD >> 12) & 0x0Fu) << 4);

  REG_CGADD  = (uint8_t)(TITLE_PAL * 16u);
  REG_CGDATA = 0x00; REG_CGDATA = 0x00;   /* colour 0 = black (transparent on BG) */
  REG_CGDATA = 0xFF; REG_CGDATA = 0x7F;   /* colour 1 = white (BGR555 0x7FFF)     */

  snes_vram_addr(TITLE_CHR_WORD);
  if (!t->font16) {
    /* 8×8: load 2bpp font promoted to 4bpp (planes 2+3 = 0 → ink = colour 1).
       64 glyphs × 16 words = 1024 words. */
    for (uint16_t g = 0; g < FONT8_N; g++) {
      for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = FONT8[g * 8u + r];
      for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
    }
  } else {
    /* 16×16: pixel-double each glyph into 4 tiles (TL, TR, BL, BR).
       Horizontal: each bit → 2 adjacent bits. Vertical: each row emitted twice.
       64 glyphs × 4 tiles × 16 words = 4096 words (0x1000–0x1FFF). */
    for (uint16_t g = 0; g < FONT8_N; g++) {
      /* Tile 4g+0 (TL): expanded rows from source rows 0-3, left byte */
      for (uint8_t r = 0; r < 8u; r++)
        REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u)]) >> 8);
      for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;   /* planes 2+3 */
      /* Tile 4g+1 (TR): same source rows 0-3, right byte */
      for (uint8_t r = 0; r < 8u; r++)
        REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u)]) & 0xFFu);
      for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
      /* Tile 4g+2 (BL): source rows 4-7, left byte */
      for (uint8_t r = 0; r < 8u; r++)
        REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u) + 4u]) >> 8);
      for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
      /* Tile 4g+3 (BR): source rows 4-7, right byte */
      for (uint8_t r = 0; r < 8u; r++)
        REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u) + 4u]) & 0xFFu);
      for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
    }
  }

  /* Clear the whole 32×32 tilemap to the space glyph (tile 0 = transparent). */
  snes_vram_addr(TITLE_MAP_WORD);
  for (uint16_t i = 0; i < (uint16_t)(TITLE_COLS * TITLE_ROWS); i++)
    REG_VMDATA = (uint16_t)(TITLE_PAL << 10);

  if (!t->font16) {
    /* 8×8: prebuild 32-word row buffers; park lines at top (row 0) and bottom (row 27). */
    _title_build_row(t->rbuf0,  t->line0);
    _title_build_row(t->rbuf1,  t->line1);
    _title_build_row(t->rblank, (const char *)0);
    snes_vram_addr((uint16_t)TITLE_MAP_WORD);
    for (uint8_t i = 0; i < TITLE_COLS; i++) REG_VMDATA = t->rbuf0[i];
    snes_vram_addr((uint16_t)(TITLE_MAP_WORD + 27u * TITLE_COLS));
    for (uint8_t i = 0; i < TITLE_COLS; i++) REG_VMDATA = t->rbuf1[i];
    t->y0 = 0;                    t->py0 = 0;
    t->y1 = (int16_t)(27 << 4);  t->py1 = 27;
    /* Per-line pixel centring via HDMA on BG2HOFS (channel 3).
       Split at scanline (TITLE_ROW0+1)*8+4 = 108 — sits in the blank gap row, hiding the
       1-scanline HDMA settle artefact. Static table valid for the whole fly-in. */
    hscroll2_build(&t->hscroll, (uint8_t)((TITLE_ROW0 + 1u) * 8u + 4u),
                   _title_hofs(t->line0), _title_hofs(t->line1));
    hscroll2_arm(TITLE_HDMA_CHAN, HSCROLL_BG2HOFS, &t->hscroll);
  } else {
    /* 16×16: prebuild 64-word row-pair buffers; park line0 at rows 0-1, line1 at rows 28-29
       (off-screen in 224-line mode — fly-in brings it up from below the visible area). */
    _title_build_row16(t->rbuf0,  t->line0);
    _title_build_row16(t->rbuf1,  t->line1);
    _title_build_row16(t->rblank, (const char *)0);
    snes_vram_addr((uint16_t)TITLE_MAP_WORD);
    for (uint8_t i = 0; i < (uint8_t)(TITLE_COLS * 2u); i++) REG_VMDATA = t->rbuf0[i];
    snes_vram_addr((uint16_t)(TITLE_MAP_WORD + 28u * TITLE_COLS));
    for (uint8_t i = 0; i < (uint8_t)(TITLE_COLS * 2u); i++) REG_VMDATA = t->rbuf1[i];
    t->y0 = 0;                    t->py0 = 0;
    t->y1 = (int16_t)(28 << 4);  t->py1 = 28;
    /* No HDMA needed: 16×16 centering is exact at the 16 px tile boundary. */
  }

  t->base.tm_bits = TM_BG2;
}

/* ── emit ───────────────────────────────────────────────────────────────────────────────────── */

static void _title_emit(Drawable *d, UploadQueue *q) {
  TitleLayer *t = (TitleLayer *)d;
  if (!t->active) return;

  if (t->flyin) {
    int16_t tgt0 = (int16_t)(TITLE_ROW0 << 4), tgt1 = (int16_t)((TITLE_ROW0 + 2u) << 4);
    if (t->y0 < tgt0) { t->y0 = (int16_t)(t->y0 + TITLE_FLY_STEP); if (t->y0 > tgt0) t->y0 = tgt0; }
    if (t->y1 > tgt1) { t->y1 = (int16_t)(t->y1 - TITLE_FLY_STEP); if (t->y1 < tgt1) t->y1 = tgt1; }
    uint8_t ny0 = (uint8_t)(t->y0 >> 4), ny1 = (uint8_t)(t->y1 >> 4);
    uint16_t dma_bytes = t->font16 ? (uint16_t)(TITLE_COLS * 4u) : (uint16_t)(TITLE_COLS * 2u);
    if (ny0 != t->py0) {
      upq_push_vram(q, (uint16_t)(TITLE_MAP_WORD + (uint16_t)t->py0 * TITLE_COLS), t->rblank, 0x00u, dma_bytes, VMAIN_INC_HIGH_1);
      upq_push_vram(q, (uint16_t)(TITLE_MAP_WORD + (uint16_t)ny0   * TITLE_COLS), t->rbuf0,  0x00u, dma_bytes, VMAIN_INC_HIGH_1);
      t->py0 = ny0;
    }
    if (ny1 != t->py1) {
      upq_push_vram(q, (uint16_t)(TITLE_MAP_WORD + (uint16_t)t->py1 * TITLE_COLS), t->rblank, 0x00u, dma_bytes, VMAIN_INC_HIGH_1);
      upq_push_vram(q, (uint16_t)(TITLE_MAP_WORD + (uint16_t)ny1   * TITLE_COLS), t->rbuf1,  0x00u, dma_bytes, VMAIN_INC_HIGH_1);
      t->py1 = ny1;
    }
  }

  t->phase = (uint8_t)(t->phase + 1u);
  if (!t->restore) {
    uint8_t lvl = (uint8_t)(24u + (_title_tri((uint8_t)(t->phase << 1)) >> 4));
    t->ink = (uint16_t)SNES_RGB(lvl, lvl, lvl);
    uint8_t h = (uint8_t)(t->phase << 1);
    t->back = (uint16_t)SNES_RGB((uint8_t)(_title_tri(h)                  >> 2),
                                 (uint8_t)(_title_tri((uint8_t)(h + 85u)) >> 2),
                                 (uint8_t)(_title_tri((uint8_t)(h + 170u))>> 2));
  } else {
    t->ink  = (uint16_t)SNES_RGB(28, 28, 28);
    t->back = 0u;
  }
  upq_push_cgram(q, TITLE_INK_IDX, &t->ink, 0x00u, 2u);
  upq_push_cgram(q, 0u,            &t->back, 0x00u, 2u);
}

static const DrawableVT TITLE_VT = { _title_reserve, _title_emit };

static inline void title_init(TitleLayer *t, const char *line0, const char *line1, uint8_t font16) {
  t->base.vt = &TITLE_VT;
  t->base.tm_bits = TM_BG2;
  t->line0 = line0;
  t->line1 = line1;
  t->font16 = font16;
}

/* ── public API ─────────────────────────────────────────────────────────────────────────────── */

/* Shared setup called by title_begin and title_begin16. */
static inline void _title_begin_impl(Display *d, TitleLayer *t,
                                     const char *line0, const char *line1, uint8_t font16) {
  title_init(t, line0, line1, font16);
  t->phase = 0; t->active = 1; t->restore = 0; t->flyin = 0;
  t->ink = (uint16_t)SNES_RGB(31, 31, 31); t->back = 0u;
  display_add(d, (Drawable *)t);   /* calls _title_reserve: loads font, parks lines, builds HDMA */
  if (!font16)
    REG_HDMAEN = (uint8_t)(1u << TITLE_HDMA_CHAN);  /* arm BG2HOFS pixel-centre stream */
  d->bright = 0;
  display_fade(d, INIDISP_ON);     /* fade up with lines parked at edges */
  t->flyin = 1;
  for (uint8_t g = 0; (t->py0 != (uint8_t)TITLE_ROW0 || t->py1 != (uint8_t)(TITLE_ROW0 + 2u)) && g < 96u; g++)
    display_frame(d);
}

/* title_begin — 8×8 font (default). All existing call sites use this. */
static inline void title_begin(Display *d, TitleLayer *t, const char *line0, const char *line1) {
  _title_begin_impl(d, t, line0, line1, 0);
}

/* title_begin16 — 16×16 pixel-doubled font. Use for short title strings (≤16 chars). */
static inline void title_begin16(Display *d, TitleLayer *t, const char *line0, const char *line1) {
  _title_begin_impl(d, t, line0, line1, 1);
}

/* Hold, fade out, tear down; fade brightness back up for the demo.
   Works for both 8×8 and 16×16 modes. */
static inline void title_end(Display *d, TitleLayer *t, uint16_t frames) {
  display_hold(d, frames);
  t->restore = 1;
  display_fade(d, 0);
  display_hide_layer(d, (Drawable *)t);
  if (!t->font16) {
    REG_HDMAEN = 0;                  /* stop BG2HOFS stream */
    REG_BG2HOFS = 0; REG_BG2HOFS = 0; /* clear scroll latch (write twice) */
  } else {
    REG_BG2HOFS = 0; REG_BG2HOFS = 0; /* clear latch even if we didn't write it */
  }
  t->active = 0;
  display_fade_to(d, INIDISP_ON);
}

/* splash16 — drop-in replacement for splash_show() that uses the 16×16 TitleLayer instead of
 * the static BGMODE_1 BG3 splash. Adds the animated fly-in + rainbow backdrop; leaves the
 * screen at INIDISP_BLANK (force-blank) on return so the caller can set up Mode 7 VRAM.
 *
 * Strings must be ≤ TITLE_MAX_CHARS (16) chars. Replaces both the include and the call:
 *   #include "snesgfx/splash.h"  →  #include "snesgfx/title_layer.h"
 *   splash_show(l0, l1, n)       →  splash16(l0, l1, n)
 */
static inline void splash16(const char *line0, const char *line1, uint16_t frames) {
  Display _d; display_init(&_d);
  static TitleLayer _t;
  title_begin16(&_d, &_t, line0, line1);
  title_end(&_d, &_t, frames);
  REG_INIDISP = 0x80;   /* re-enter force-blank for Mode 7 / VRAM setup */
}

#endif /* SNESGFX_TITLE_LAYER_H */
