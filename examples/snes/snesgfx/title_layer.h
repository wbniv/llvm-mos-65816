/* snesgfx — TitleLayer: drop-in animated title overlay on BG2.
 *
 * Every demo in the battery leaves BG2 free, so the title can live there in BGMODE_1 without
 * colliding with any demo layer. Font data and the tilemap are written once in reserve() under
 * force-blank; the CINEMATIC intro (title_begin…title_end) then animates via emit() using
 * REG_BG2VOFS to scroll both lines pixel-smoothly into position — zero VRAM traffic during the
 * animation. Ink shimmer + rainbow backdrop are driven via CGRAM pushes each frame.
 *
 * Layout (always):
 *   line0 — 8×8 font, centred on tilemap row 12 (screen row 96 at VOFS=0)
 *   line1 — 16×16 pixel-doubled font, centred on tilemap rows 14–15 (screen rows 112–127)
 *
 * Animation sequence:
 *   1. reserve() parks the layer at BG2VOFS=TITLE_VOFS_START (both lines above the screen).
 *   2. title_begin() fades the screen to full brightness, then eases BG2VOFS toward 0 — fast far
 *      out, decelerating gently to rest (exponential decay).
 *   3. title_end(frames) holds for `frames` v-blanks, then sets restore=1 and fades to black.
 *      During the fade, emit() accelerates BG2VOFS upward (quadratic ramp) — the text exits the
 *      top of the screen in ≤ 6 frames. Screen then fades back up for the demo.
 *
 * VRAM layout (single mode, always mixed):
 *   tiles   0– 63  8×8 glyphs (line0)               1 K words at TITLE_CHR_WORD
 *   tiles  64–319  16×16 expanded glyphs (line1)     4 K words at TITLE_CHR_WORD + 0x0400
 *   Total 5 K words starting at TITLE_CHR_WORD = 0x1000.
 *
 * HDMA channel 3 on BG2HOFS: pixel-centres line0 (8×8 can't always land on a tile boundary).
 * Line1 is always exactly centred at the 16 px tile boundary — its HDMA band is 0.
 *
 * Gate-neutral: once title_end() sets active=0, emit() is a no-op.
 *
 * Lifecycle:
 *   display_init(d); display_add(d, <demo drawables>); display_add(d, &title.base);
 *   title_begin(d, &title, "CATEGORY", "DEMO NAME");   // fly-in + hold begins
 *   <heavy pre-loop compute>
 *   title_end(d, &title, hold_frames);
 *   for (;;) { <render>; display_frame(d); }
 *
 * Strings must be UPPERCASE ASCII (font8 covers 0x20..0x5F). Max 32 chars for line0, 16 for line1.
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
#define TITLE_CHR_WORD  0x1000u   /* BG2 char base (4K-word granular → BG12NBA high nibble = 1) */
#endif
#ifndef TITLE_MAP_WORD
#define TITLE_MAP_WORD  0x5000u   /* BG2 tilemap base (clear of demos' 0x0000..0x4400 regions)  */
#endif
#define TITLE_PAL        7u       /* CGRAM palette 7 (entries 112..127)                          */
#define TITLE_COLS       32u
#define TITLE_ROWS       32u
#define TITLE_MAX_CHARS  16u      /* max chars for line1 (16×16 font; 2 tile-cols per glyph)     */
#define TITLE_L1_TILE    FONT8_N  /* first tile index for 16×16 glyphs (= 64)                   */
#define TITLE_VOFS_START 220      /* initial BG2VOFS: both lines above screen (screen row < 0)   */

#define TITLE_HDMA_CHAN  3u       /* HDMA channel for BG2HOFS pixel-centre (0=GP-DMA UpQ,
                                    1-2=hud.h split; 3 is free during the intro)                 */

typedef struct {
  Drawable    base;
  const char *line0;   /* 8×8 font, centred on row 12      (NULL = skip) */
  const char *line1;   /* 16×16 font, centred on rows 14–15 (NULL = skip) */
  /* --- cinematics state --- */
  int16_t     vofs;    /* live BG2VOFS (TITLE_VOFS_START = above screen, 0 = at target)         */
  int16_t     vel;     /* ease-out velocity accumulator (added to vofs each frame)               */
  uint8_t     phase;   /* animation clock for ink shimmer + rainbow backdrop                     */
  uint8_t     active;  /* 1 = emit() is live; 0 = static no-op                                  */
  uint8_t     flyin;   /* 1 = ease vofs toward 0; 0 = hold current vofs                         */
  uint8_t     restore; /* 1 = ease-out: accelerate vofs upward + drive backdrop to black         */
  uint16_t    ink;     /* live ink colour (CGRAM palette-7 colour 1)                             */
  uint16_t    back;    /* live backdrop colour (CGRAM[0])                                        */
  HScroll2    hscroll; /* HDMA table for BG2HOFS pixel-centring on line0                        */
} TitleLayer;

#define TITLE_INK_IDX  (uint8_t)(TITLE_PAL * 16u + 1u)   /* CGRAM entry for ink (= 113) */
#define TITLE_ROW0      12u   /* target tilemap row for line0; line1 top = TITLE_ROW0 + 2 */

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

/* Triangle wave 0..127..0 — building block for the rainbow backdrop. */
static inline uint8_t _title_tri(uint8_t x) { return (uint8_t)((x & 0x80u) ? (uint8_t)(255u - x) : x); }

/* Pixel-double one 8-bit plane row to 16 bits: each source bit → 2 adjacent bits (MSB=left). */
static inline uint16_t _title_expand_byte(uint8_t b) {
  uint16_t r = 0;
  for (uint8_t i = 0; i < 8u; i++) {
    if (b & (uint8_t)(0x80u >> i)) r |= (uint16_t)(0xC000u >> (uint8_t)(i << 1u));
  }
  return r;
}

/* ── reserve ──────────────────────────────────────────────────────────────────────────────────── */

static void _title_reserve(Drawable *d, VramAlloc *va) {
  (void)va;
  TitleLayer *t = (TitleLayer *)d;

  REG_BG2SC   = SNES_BGSC(TITLE_MAP_WORD, 0);
  REG_BG12NBA = (uint8_t)(((TITLE_CHR_WORD >> 12) & 0x0Fu) << 4);

  REG_CGADD  = (uint8_t)(TITLE_PAL * 16u);
  REG_CGDATA = 0x00; REG_CGDATA = 0x00;   /* colour 0 = black (transparent on BG) */
  REG_CGDATA = 0xFF; REG_CGDATA = 0x7F;   /* colour 1 = white (BGR555 0x7FFF)     */

  /* 8×8 glyphs: tiles 0–63 (1 K words at TITLE_CHR_WORD).
     2bpp font promoted to 4bpp: planes 2+3 = 0 → ink = colour 1. */
  snes_vram_addr(TITLE_CHR_WORD);
  for (uint16_t g = 0; g < FONT8_N; g++) {
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = FONT8[g * 8u + r];
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
  }

  /* 16×16 expanded glyphs: tiles 64–319 (4 K words at TITLE_CHR_WORD + 0x0400).
     Each glyph → 4 tiles: TL (4g+0), TR (4g+1), BL (4g+2), BR (4g+3).
     Horizontal: each source bit → 2 adjacent bits. Vertical: each row emitted twice. */
  snes_vram_addr((uint16_t)(TITLE_CHR_WORD + (uint16_t)(FONT8_N * 16u)));
  for (uint16_t g = 0; g < FONT8_N; g++) {
    for (uint8_t r = 0; r < 8u; r++)                                    /* TL: rows 0-3 left  */
      REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u)]) >> 8);
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
    for (uint8_t r = 0; r < 8u; r++)                                    /* TR: rows 0-3 right */
      REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u)]) & 0xFFu);
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
    for (uint8_t r = 0; r < 8u; r++)                                    /* BL: rows 4-7 left  */
      REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u) + 4u]) >> 8);
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
    for (uint8_t r = 0; r < 8u; r++)                                    /* BR: rows 4-7 right */
      REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u) + 4u]) & 0xFFu);
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
  }

  /* Clear tilemap to transparent (palette 7 entry 0 = transparent). */
  snes_vram_addr(TITLE_MAP_WORD);
  for (uint16_t i = 0; i < (uint16_t)(TITLE_COLS * TITLE_ROWS); i++)
    REG_VMDATA = (uint16_t)(TITLE_PAL << 10);

  /* Write line0 (8×8) at tilemap row 12, centred. */
  {
    const char *s = t->line0;
    uint8_t len = 0;
    if (s) for (const char *p = s; *p && len < TITLE_COLS; p++) len++;
    uint8_t sc = (uint8_t)((TITLE_COLS - len) / 2u);
    snes_vram_addr((uint16_t)(TITLE_MAP_WORD + (uint16_t)TITLE_ROW0 * TITLE_COLS));
    for (uint8_t i = 0; i < TITLE_COLS; i++) {
      uint16_t tile = (s && i >= sc && i < (uint8_t)(sc + len))
                        ? _title_glyph((uint8_t)s[i - sc]) : 0u;
      REG_VMDATA = (uint16_t)((uint16_t)(TITLE_PAL << 10) | tile);
    }
  }

  /* Write line1 (16×16) at tilemap rows 14 (top) and 15 (bottom), centred. */
  {
    const char *s = t->line1;
    uint8_t len = 0;
    if (s) for (const char *p = s; *p && len < TITLE_MAX_CHARS; p++) len++;
    uint8_t sc = (uint8_t)((TITLE_COLS - (uint8_t)(2u * len)) / 2u);
    /* Top tile row (row 14) */
    snes_vram_addr((uint16_t)(TITLE_MAP_WORD + (uint16_t)(TITLE_ROW0 + 2u) * TITLE_COLS));
    for (uint8_t i = 0; i < TITLE_COLS; i++) {
      uint16_t tile = 0;
      if (s && i >= sc && i < (uint8_t)(sc + 2u * len)) {
        uint8_t ci = (uint8_t)((i - sc) >> 1u);   /* char index */
        uint8_t hs = (uint8_t)((i - sc) & 1u);    /* 0=left tile, 1=right tile */
        tile = (uint16_t)((uint16_t)TITLE_L1_TILE + 4u * _title_glyph((uint8_t)s[ci]) + hs);
      }
      REG_VMDATA = (uint16_t)((uint16_t)(TITLE_PAL << 10) | tile);
    }
    /* Bottom tile row (row 15) */
    snes_vram_addr((uint16_t)(TITLE_MAP_WORD + (uint16_t)(TITLE_ROW0 + 3u) * TITLE_COLS));
    for (uint8_t i = 0; i < TITLE_COLS; i++) {
      uint16_t tile = 0;
      if (s && i >= sc && i < (uint8_t)(sc + 2u * len)) {
        uint8_t ci = (uint8_t)((i - sc) >> 1u);
        uint8_t hs = (uint8_t)((i - sc) & 1u);
        tile = (uint16_t)((uint16_t)TITLE_L1_TILE + 4u * _title_glyph((uint8_t)s[ci]) + 2u + hs);
      }
      REG_VMDATA = (uint16_t)((uint16_t)(TITLE_PAL << 10) | tile);
    }
  }

  /* Park both lines above the screen; build + arm HDMA for line0 pixel-centring.
     Split at scanline (TITLE_ROW0+1)*8+4 = 108 — sits in the blank gap row between line0 and
     line1. Band A [0..107]: line0 HOFS; band B [108..223]: 0 (line1 is always exactly centred). */
  REG_BG2VOFS = (uint8_t)TITLE_VOFS_START; REG_BG2VOFS = (uint8_t)(TITLE_VOFS_START >> 8);
  t->vofs = TITLE_VOFS_START; t->vel = 0;
  hscroll2_build(&t->hscroll, (uint8_t)((TITLE_ROW0 + 1u) * 8u + 4u),
                 _title_hofs(t->line0), 0);
  hscroll2_arm(TITLE_HDMA_CHAN, HSCROLL_BG2HOFS, &t->hscroll);

  t->base.tm_bits = TM_BG2;
}

/* ── emit ─────────────────────────────────────────────────────────────────────────────────────── */

static void _title_emit(Drawable *d, UploadQueue *q) {
  TitleLayer *t = (TitleLayer *)d;
  if (!t->active) return;

  if (t->flyin) {
    /* ease-in: exponential decay toward vofs=0 — fast far out, gentle landing */
    if (t->vofs > 0) {
      int16_t step = (int16_t)(t->vofs >> 3);
      if (step < 1) step = 1;
      t->vofs -= step;
      if (t->vofs < 0) t->vofs = 0;
    }
  } else if (t->restore) {
    /* ease-out: quadratic acceleration upward — off-screen in ≤ 6 frames */
    t->vel += 6;
    t->vofs += t->vel;
  }
  upq_push_scroll(q, (uint16_t)(uintptr_t)&REG_BG2VOFS, (uint16_t)t->vofs);

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

static inline void title_init(TitleLayer *t, const char *line0, const char *line1) {
  t->base.vt = &TITLE_VT;
  t->base.tm_bits = TM_BG2;
  t->line0 = line0;
  t->line1 = line1;
}

/* ── public API ───────────────────────────────────────────────────────────────────────────────── */

/* title_begin — fly-in title card. line0 = 8×8 (category/subtitle), line1 = 16×16 (title name).
   Fades to full brightness, then eases both lines in from above. Returns when lines are at rest. */
static inline void title_begin(Display *d, TitleLayer *t, const char *line0, const char *line1) {
  title_init(t, line0, line1);
  t->phase = 0; t->active = 1; t->restore = 0; t->flyin = 0;
  t->ink = (uint16_t)SNES_RGB(31, 31, 31); t->back = 0u;
  display_add(d, (Drawable *)t);
  REG_HDMAEN = (uint8_t)(1u << TITLE_HDMA_CHAN);
  d->bright = 0;
  display_fade(d, INIDISP_ON);   /* fade in with lines parked above screen */
  t->flyin = 1;
  for (uint8_t g = 0; t->vofs != 0 && g < 96u; g++)
    display_frame(d);
}

/* title_begin16 — backward-compat alias (all pre-existing call sites used this name). */
#define title_begin16 title_begin

/* title_end — hold for `frames` v-blanks, then ease-out very fast and fade to black.
   Disables the title layer and fades the screen back up for the demo to begin. */
static inline void title_end(Display *d, TitleLayer *t, uint16_t frames) {
  display_hold(d, frames);
  t->restore = 1; t->vel = 0;
  display_fade(d, 0);            /* fade to black; ease-out runs during this */
  display_hide_layer(d, (Drawable *)t);
  REG_HDMAEN = 0;
  REG_BG2HOFS = 0; REG_BG2HOFS = 0;   /* clear HOFS latch */
  REG_BG2VOFS = 0; REG_BG2VOFS = 0;   /* reset VOFS latch for next use */
  t->active = 0;
  display_fade_to(d, INIDISP_ON);
}

/* splash16 — standalone title splash (no pre-existing display; leaves screen in force-blank).
   Drop-in replacement for splash_show() + the old splash.h include for Mode-7 demos. */
static inline void splash16(const char *line0, const char *line1, uint16_t frames) {
  Display _d; display_init(&_d);
  static TitleLayer _t;
  title_begin(&_d, &_t, line0, line1);
  title_end(&_d, &_t, frames);
  REG_INIDISP = 0x80;   /* re-enter force-blank for Mode 7 / VRAM setup */
}

#endif /* SNESGFX_TITLE_LAYER_H */
