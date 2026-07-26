/* snesgfx — TitleLayer: drop-in animated title overlay on BG2.
 *
 * Every demo in the battery leaves BG2 free, so the title can live there in BGMODE_1 without
 * colliding with any demo layer. Font data and the tilemap are written once in reserve() under
 * force-blank; the CINEMATIC intro (title_begin…title_end) then animates the two text lines by
 * driving BG2VOFS per scanline via HDMA — line0 descends from the top, line1 rises from the bottom,
 * they meet as a normal two-line title, hold, then FALL off the bottom together under gravity.
 * Demo drawables (canvas, text, HUD) are masked off during the title card and restored in
 * title_end(). Ink shimmer + rainbow backdrop are driven via CGRAM pushes each frame.
 *
 * Tilemap layout (fixed):
 *   line0 — 8×8 font,  centred on tilemap row 12      → tilemap y  96…103
 *   line1 — 16×16 Waldo font (font16.h; face + SE drop-shadow), rows 14–15 → tilemap y 112…127
 *   (one blank tilemap row between them; normal reading spacing.) Everything else is blank.
 *
 * ── The banding scheme (this is the whole trick — read before touching the geometry) ───────────
 * Both lines share ONE BG2 tilemap, and BG scroll wraps mod 256 px (a 32×32 map). A band of
 * scanlines [a,b) with scroll V shows tilemap rows [a+V, b+V) mod 256 — so a band that is TALL
 * relative to the distance between the two lines will, at some point in the slide, drag the OTHER
 * line's rows into view. That is precisely the bug this scheme replaces: a fixed two-band split at
 * scanline 108 gave band A a 108-row window sweeping 128 px of travel (tilemap rows 0…235, which
 * contains line1) and band B a window containing line0 — so BOTH lines appeared from BOTH edges.
 * No fixed split can avoid it: whichever geometry fixes the fly-in breaks the fall.
 *
 * Instead each line gets a band exactly as tall as the line plus a small margin, and its scroll is
 * derived from its own position:  V = tilemap_y − screen_y.  The two cancel, so the band's tilemap
 * window is CONSTANT — line0's band always shows tilemap rows [94,106), line1's always [110,130) —
 * no matter where on screen the line is. Neither window can ever contain the other line, so a
 * double image is structurally impossible for ANY pair of positions, in either animation phase.
 *
 * Every other scanline is "blank": a band anchored at tilemap row TITLE_BLANK_ROW (136), i.e.
 * V = 136 − band_top, chunked to at most TITLE_BLANK_MAX (112) scanlines so its window always lands
 * inside tilemap rows [136,248) — deep inside the blank region 128…255, ≥8 rows clear of line1's
 * last row (127). The ±2 px band margins and that 8-row clearance also absorb the SNES BGnVOFS
 * off-by-one, so the scheme does not depend on which scanline convention the PPU uses.
 *
 * BG2HOFS is banded identically (same boundaries, same frame) so line0's sub-tile pixel-centring
 * nudge travels with line0 instead of being pinned to a fixed scanline split. line1 needs no nudge:
 * its 16×16 glyphs are 2 tile-columns wide, so (32 − 2·len)/2 is always exact.
 *
 * Both tables are double-buffered (HScrollDB). emit() runs during ACTIVE DISPLAY — Display calls
 * scene_emit before waiting for v-blank — so an in-place rebuild would be writing the table the
 * HDMA engine is walking, and the rest of that frame could see a count byte from one layout paired
 * with a scroll value from another. Instead the rebuild goes to the half the engine is not reading
 * and the channel's table pointer is re-pointed through the UploadQueue, which runs in v-blank.
 *
 * Animation timing (at 60 fps):
 *   Fly-in   ~1.9 s — both lines move simultaneously, TITLE_FLYIN_SHIFT=6
 *   Hold     2 s    (TITLE_HOLD_FRAMES=120) — lines stationary, shimmer/rainbow continues
 *   Fall     ~0.75 s (≈45 frames) — constant acceleration TITLE_GRAVITY_Q4, one shared velocity so
 *                    the two lines keep their spacing and drop off the bottom as a unit
 *
 * VRAM layout (single mode, always mixed):
 *   tiles   0– 63  8×8 glyphs (line0)               1 K words at TITLE_CHR_WORD
 *   tiles  64–319  16×16 Waldo glyphs (line1)        4 K words at TITLE_CHR_WORD + 0x0400
 *   Total 5 K words at TITLE_CHR_WORD = 0x1000.
 *
 * HDMA channels (both free during the title intro — hud.h arms 1–2 only inside demo loops):
 *   TITLE_HDMA_CHAN_VOFS = 3 — BG2VOFS per-line bands (rebuilt + republished each emit frame)
 *   TITLE_HDMA_CHAN_HOFS = 4 — BG2HOFS per-line bands (rebuilt + republished each emit frame)
 *
 * TM masking: title_begin() saves the demo drawables' TM bits and masks them off so the demo's
 * canvas/text/HUD does not show during the title card. title_end() restores them before fade-up.
 *
 * Gate-neutral: once title_end() sets active=0, emit() is a no-op.
 *
 * Header-only (static inline). Reuses examples/snes/font8.h. */
#ifndef SNESGFX_TITLE_LAYER_H
#define SNESGFX_TITLE_LAYER_H

#include <snes.h>
#include "drawable.h"
#include "display.h"
#include "hdma_hscroll.h"
#include "../font8.h"
#include "../font16.h"   /* real 16×16 Waldo font (face + SE drop-shadow) for line1 — ALWAYS */

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

#define TITLE_ROW0       12u      /* tilemap row for line0 (8×8)                                 */
#define TITLE_ROW1       14u      /* tilemap row for line1 top (16×16)                           */
#define TITLE_H0         8        /* line0 height, px                                            */
#define TITLE_H1        16        /* line1 height, px                                            */
#define TITLE_TY0       (int16_t)(TITLE_ROW0 * 8u)   /*  96 — tilemap y of line0 */
#define TITLE_TY1       (int16_t)(TITLE_ROW1 * 8u)   /* 112 — tilemap y of line1 */
#define TITLE_SCREEN_H  224       /* visible scanlines                                           */

/* Band margin: each glyph band is this many px taller on each side than the glyphs themselves. The
   extra rows land on blank tilemap (row 95 above line0 / 104–105 below it; 110–111 above line1 /
   128–129 below it) and absorb any BGnVOFS scanline off-by-one, so no row is ever clipped. */
#define TITLE_MARGIN     2

/* Blank bands: anchored at this tilemap row, chunked to this many scanlines, so every blank window
   is a subset of tilemap rows [136,248) — well inside the blank region, clear of both lines. */
#define TITLE_BLANK_ROW  136
#define TITLE_BLANK_MAX  112

/* Screen-space rest / start positions (y = the line's top scanline). At rest each line sits at its
   own tilemap y, so both scroll values are 0 — the easy case to reason about. */
#define TITLE_Y0_REST    TITLE_TY0                          /*  96 */
#define TITLE_Y1_REST    TITLE_TY1                          /* 112 */
#define TITLE_Y0_START   (int16_t)(-TITLE_H0)               /*  −8 — fully above the screen */
#define TITLE_Y1_START   (int16_t)(TITLE_SCREEN_H)          /* 224 — fully below the screen */

/* Positions are Q4 fixed point (1/16 px) so gravity can accelerate sub-pixel. */
#define TITLE_Q4(px)     ((int16_t)((int16_t)(px) * 16))

/* Animation parameters */
#define TITLE_FLYIN_SHIFT    6    /* fly-in decay shift — ~1.9 s at 60 fps, matches the old feel  */
#define TITLE_GRAVITY_Q4     2    /* fall acceleration, Q4 px/frame² — 128 px in ≈45 frames       */
#define TITLE_FALL_MAX     90u    /* safety cap on the fall loop (frames)                         */
#define TITLE_HOLD_FRAMES  120    /* 2 s hold at 60 fps                                           */

/* HDMA channel assignment */
#define TITLE_HDMA_CHAN_VOFS  3u  /* BG2VOFS per-line bands */
#define TITLE_HDMA_CHAN_HOFS  4u  /* BG2HOFS per-line bands */

/* Band budget: 2 glyph bands (≤20 lines each, so never chunked) + at most 5 blank chunks of
   ≤112 lines = 7 runs, comfortably inside HSCROLL_MAX_RUNS (12). */

typedef struct {
  Drawable    base;
  const char *line0;     /* 8×8 font, centred on tilemap row 12   (NULL = skip) */
  const char *line1;     /* 16×16 font, centred on tilemap rows 14–15 (NULL = skip) */
  /* --- cinematics state (screen-space tops, Q4 = 1/16 px) --- */
  int16_t     y0_q4;     /* line0 top scanline                                              */
  int16_t     y1_q4;     /* line1 top scanline                                              */
  int16_t     vel_q4;    /* shared fall velocity (both lines, so spacing is preserved)       */
  int16_t     hofs0;     /* line0's sub-tile horizontal centring nudge                       */
  uint8_t     phase;     /* animation clock for ink shimmer + rainbow backdrop               */
  uint8_t     active;    /* 1 = emit() is live; 0 = no-op                                   */
  uint8_t     flyin;     /* 1 = ease lines toward rest; 0 = hold                            */
  uint8_t     falling;   /* 1 = gravity: both lines drop off the bottom                     */
  uint8_t     exiting;   /* 1 from the start of the fall to the end of title_end: freezes   */
                         /* the shimmer/rainbow so the backdrop cannot flash back on during */
                         /* the fade-out after `falling` is cleared to park the positions.  */
  uint8_t     demo_tm;   /* saved demo drawables' TM bits, restored in title_end()          */
  uint16_t    ink;       /* live ink colour (CGRAM palette-7 colour 1)                      */
  uint16_t    back;      /* live backdrop colour (CGRAM[0])                                 */
  HScrollDB   vscroll;   /* BG2VOFS band table, double-buffered (rebuilt each emit frame)   */
  HScrollDB   hscroll;   /* BG2HOFS band table, same boundaries, same frame                 */
} TitleLayer;

#define TITLE_INK_IDX  (uint8_t)(TITLE_PAL * 16u + 1u)   /* CGRAM entry for ink (= 113) */

/* Glyph index for an ASCII char. Both fonts cover 0x20..0x5F, so lowercase is FOLDED TO CAPS at
   render time rather than dropped: a title written "NaN / POLES" or "div_t" used to lose those
   letters silently (out of range → glyph 0 → a space). Folding is free and keeps the titles' source
   spelling intact for the day the fonts grow real 0x60..0x7F glyphs — at which point deleting these
   two lines is the whole change. Anything still out of range renders as a space; dev/title-charset.sh
   is the gate that stops such a title from shipping. */
static inline uint16_t _title_glyph(uint8_t ch) {
  if (ch >= 'a' && ch <= 'z') ch = (uint8_t)(ch - 32u);
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

/* ── band table construction ──────────────────────────────────────────────────────────────────── */

/* Blank scanlines [top,bot): chunks of ≤TITLE_BLANK_MAX, each anchored so its tilemap window
   starts at TITLE_BLANK_ROW. HOFS is irrelevant on blank rows — 0 keeps the latch tidy. */
static void _title_blank(HScrollW *v, HScrollW *h, int16_t top, int16_t bot) {
  while (bot > top) {
    int16_t run = (int16_t)(bot - top);
    if (run > TITLE_BLANK_MAX) run = TITLE_BLANK_MAX;
    hscrollw_band(v, (uint8_t)run, (int16_t)(TITLE_BLANK_ROW - top));
    hscrollw_band(h, (uint8_t)run, 0);
    top = (int16_t)(top + run);
  }
}

/* One glyph band: screen rows [y−margin, y+height+margin), clipped to the screen and to whatever
   has already been emitted (*cur), preceded by the blank gap above it. Its scroll is
   (tilemap_y − y), which makes the band's tilemap window CONSTANT regardless of y — the invariant
   that makes a double image impossible. */
static void _title_glyph_band(HScrollW *v, HScrollW *h, int16_t *cur,
                              int16_t y, int16_t height, int16_t ty, int16_t hofs) {
  int16_t a = (int16_t)(y - TITLE_MARGIN);
  int16_t b = (int16_t)(y + height + TITLE_MARGIN);
  if (a < *cur) a = *cur;
  if (b > TITLE_SCREEN_H) b = TITLE_SCREEN_H;
  if (b <= a) return;                        /* line is entirely off-screen this frame */
  _title_blank(v, h, *cur, a);               /* blank gap above it */
  hscrollw_band(v, (uint8_t)(b - a), (int16_t)(ty - y));
  hscrollw_band(h, (uint8_t)(b - a), hofs);
  *cur = b;
}

/* Build both band tables for one frame into `vt`/`ht`. y0/y1 are the lines' top scanlines (whole
   px). Both tables get identical band boundaries so the horizontal nudge always tracks the line it
   belongs to. Callers pass the double buffers' BACK halves (never the half HDMA is reading) and
   publish them with hscrolldb_commit(). */
static void _title_build(TitleLayer *t, int16_t y0, int16_t y1, HScrollN *vt, HScrollN *ht) {
  HScrollW v, h;
  int16_t cur = 0;
  hscrollw_begin(&v, vt);
  hscrollw_begin(&h, ht);
  _title_glyph_band(&v, &h, &cur, y0, TITLE_H0, TITLE_TY0, t->hofs0);
  _title_glyph_band(&v, &h, &cur, y1, TITLE_H1, TITLE_TY1, 0);
  _title_blank(&v, &h, cur, TITLE_SCREEN_H);
  hscrollw_end(&v);
  hscrollw_end(&h);
}

/* ── reserve ──────────────────────────────────────────────────────────────────────────────────── */

static void _title_reserve(Drawable *d, VramAlloc *va) {
  (void)va;
  TitleLayer *t = (TitleLayer *)d;

  REG_BG2SC   = SNES_BGSC(TITLE_MAP_WORD, 0);
  REG_BG12NBA = (uint8_t)(((TITLE_CHR_WORD >> 12) & 0x0Fu) << 4);

  REG_CGADD  = (uint8_t)(TITLE_PAL * 16u);
  REG_CGDATA = 0x00; REG_CGDATA = 0x00;   /* colour 0 = black (transparent on BG)       */
  REG_CGDATA = 0xFF; REG_CGDATA = 0x7F;   /* colour 1 = white ink (BGR555 0x7FFF, animated) */
  REG_CGDATA = 0x84; REG_CGDATA = 0x10;   /* colour 2 = dark grey (BGR555 0x1084) = drop-shadow */

  /* 8×8 glyphs: tiles 0–63 (1 K words at TITLE_CHR_WORD).
     2bpp font promoted to 4bpp: planes 2+3 = 0 → ink = colour 1. */
  snes_vram_addr(TITLE_CHR_WORD);
  for (uint16_t g = 0; g < FONT8_N; g++) {
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = FONT8[g * 8u + r];
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
  }

  /* 16×16 line1 glyphs: tiles 64–319 (4 K words at TITLE_CHR_WORD + 0x0400). */
  snes_vram_addr((uint16_t)(TITLE_CHR_WORD + (uint16_t)(FONT8_N * 16u)));
  /* Real Waldo font: 4 tiles/glyph TL,TR,BL,BR (tilemap uses 4g+0..3). FONT16 word = face | shadow<<8
     (planes 0/1); planes 2/3 = 0 → face = colour 1 (animated ink), shadow = colour 2 (fixed dark).
     There is no font-less fallback: every demo gets the real font. A demo too tight for the 4 KB table
     in its near window parks it in far ROM (TITLE_FONT16_FAR, see font16.h) rather than dropping it. */
  for (uint16_t g = 0; g < FONT16_N; g++) {
    for (uint8_t tile = 0; tile < 4u; tile++) {
      for (uint8_t r = 0; r < 8u; r++)
        REG_VMDATA = FONT16[(uint16_t)(g * 32u) + (uint16_t)(tile * 8u) + r];
      for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
    }
  }

  /* Clear tilemap to transparent. Everything outside rows 12 and 14–15 stays blank — the blank
     bands rely on that, so do not park anything else in this tilemap. */
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

  /* Write line1 (16×16) at tilemap rows 14 (top half) and 15 (bottom half), centred. */
  {
    const char *s = t->line1;
    uint8_t len = 0;
    if (s) for (const char *p = s; *p && len < TITLE_MAX_CHARS; p++) len++;
    uint8_t sc = (uint8_t)((TITLE_COLS - (uint8_t)(2u * len)) / 2u);
    snes_vram_addr((uint16_t)(TITLE_MAP_WORD + (uint16_t)TITLE_ROW1 * TITLE_COLS));
    for (uint8_t i = 0; i < TITLE_COLS; i++) {
      uint16_t tile = 0;
      if (s && i >= sc && i < (uint8_t)(sc + 2u * len)) {
        uint8_t ci = (uint8_t)((i - sc) >> 1u);
        uint8_t hs = (uint8_t)((i - sc) & 1u);
        tile = (uint16_t)((uint16_t)TITLE_L1_TILE + 4u * _title_glyph((uint8_t)s[ci]) + hs);
      }
      REG_VMDATA = (uint16_t)((uint16_t)(TITLE_PAL << 10) | tile);
    }
    snes_vram_addr((uint16_t)(TITLE_MAP_WORD + (uint16_t)(TITLE_ROW1 + 1u) * TITLE_COLS));
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

  /* Both lines start fully off-screen; the shared scroll latch is parked on blank tilemap so
     nothing flashes between here and the first HDMA frame. */
  t->y0_q4  = TITLE_Q4(TITLE_Y0_START);
  t->y1_q4  = TITLE_Q4(TITLE_Y1_START);
  t->vel_q4 = 0;
  t->hofs0  = _title_hofs(t->line0);
  REG_BG2VOFS = (uint8_t)TITLE_BLANK_ROW; REG_BG2VOFS = 0;

  /* Fill buffer 0 of each double buffer directly — HDMA is not enabled yet, so there is nothing
     to race with here — then arm the channels on it. From the first emit onward every rebuild
     goes to the back half and is published in v-blank. */
  _title_build(t, TITLE_Y0_START, TITLE_Y1_START, &t->vscroll.buf[0], &t->hscroll.buf[0]);
  hscrolldb_arm(TITLE_HDMA_CHAN_VOFS, VSCROLL_BG2VOFS, &t->vscroll);
  hscrolldb_arm(TITLE_HDMA_CHAN_HOFS, HSCROLL_BG2HOFS, &t->hscroll);

  t->base.tm_bits = TM_BG2;
}

/* ── emit ─────────────────────────────────────────────────────────────────────────────────────── */

/* One fly-in step toward `target`: exponential decay with a 1 px floor, so the line always makes
   progress and lands exactly on target. */
static int16_t _title_ease(int16_t cur, int16_t target) {
  int16_t rem = (int16_t)(target - cur);
  if (rem == 0) return cur;
  int16_t mag  = rem < 0 ? (int16_t)-rem : rem;
  int16_t step = (int16_t)((mag >> 4) >> TITLE_FLYIN_SHIFT);   /* px */
  if (step < 1) step = 1;
  step = (int16_t)(step << 4);                                 /* → Q4 */
  if (step > mag) step = mag;
  return rem < 0 ? (int16_t)(cur - step) : (int16_t)(cur + step);
}

static void _title_emit(Drawable *d, UploadQueue *q) {
  TitleLayer *t = (TitleLayer *)d;
  if (!t->active) return;

  if (t->flyin) {
    /* Both lines move simultaneously and meet in the middle: line0 descends from above the top
       edge to y=96, line1 rises from below the bottom edge to y=112. */
    t->y0_q4 = _title_ease(t->y0_q4, TITLE_Q4(TITLE_Y0_REST));
    t->y1_q4 = _title_ease(t->y1_q4, TITLE_Q4(TITLE_Y1_REST));
  } else if (t->falling) {
    /* Gravity: one shared velocity, so the pair keeps its 16 px spacing and drops off the bottom
       looking like a single falling object. Clamp well past the bottom edge so nothing wraps. */
    t->vel_q4 = (int16_t)(t->vel_q4 + TITLE_GRAVITY_Q4);
    t->y0_q4  = (int16_t)(t->y0_q4 + t->vel_q4);
    t->y1_q4  = (int16_t)(t->y1_q4 + t->vel_q4);
    if (t->y0_q4 > TITLE_Q4(280)) t->y0_q4 = TITLE_Q4(280);
    if (t->y1_q4 > TITLE_Q4(296)) t->y1_q4 = TITLE_Q4(296);
  }

  _title_build(t, (int16_t)(t->y0_q4 >> 4), (int16_t)(t->y1_q4 >> 4),
               hscrolldb_back(&t->vscroll), hscrolldb_back(&t->hscroll));
  hscrolldb_commit(&t->vscroll, q, TITLE_HDMA_CHAN_VOFS);
  hscrolldb_commit(&t->hscroll, q, TITLE_HDMA_CHAN_HOFS);

  t->phase = (uint8_t)(t->phase + 1u);
  if (!t->exiting) {
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

/* title_begin — counter-sliding fly-in title card.
 *   line0 = 8×8  (category/subtitle) — descends from the top
 *   line1 = 16×16 (demo name)        — rises from the bottom
 * Masks demo drawables' TM bits for the duration (restored in title_end).
 * Returns when both lines are at rest. */
static inline void title_begin(Display *d, TitleLayer *t, const char *line0, const char *line1) {
  title_init(t, line0, line1);
  t->phase = 0; t->active = 1; t->falling = 0; t->exiting = 0; t->flyin = 0;
  t->ink = (uint16_t)SNES_RGB(31, 31, 31); t->back = 0u;

  uint8_t demo_tm = d->tm;            /* save demo drawables' TM bits before title is added */
  display_add(d, (Drawable *)t);      /* d->tm |= TM_BG2 */
  t->demo_tm = demo_tm;
  d->tm = TM_BG2; REG_TM = TM_BG2;  /* show only title during intro — hide canvas/HUD/text */

  REG_HDMAEN = (uint8_t)((1u << TITLE_HDMA_CHAN_VOFS) | (1u << TITLE_HDMA_CHAN_HOFS));
  d->bright = 0;
  display_fade(d, INIDISP_ON);        /* fade in with both lines still off-screen */
  t->flyin = 1;
  for (uint8_t g = 0;
       (t->y0_q4 != TITLE_Q4(TITLE_Y0_REST) || t->y1_q4 != TITLE_Q4(TITLE_Y1_REST)) && g < 200u;
       g++)
    display_frame(d);
  t->flyin = 0;   /* at rest; clear so title_end's fall branch is reachable */
}

/* title_begin16 — backward-compat alias (all pre-existing call sites used this name). */
#define title_begin16 title_begin

/* title_end — hold for `frames` v-blanks, drop both lines off the bottom under gravity, fade to
 * black, restore the demo layers.
 *   Recommended: pass TITLE_HOLD_FRAMES (120 = 2 s) unless the demo has specific needs. */
static inline void title_end(Display *d, TitleLayer *t, uint16_t frames) {
  display_hold(d, frames);
  t->falling = 1; t->exiting = 1;
  /* Run the fall at FULL BRIGHTNESS until line0 (the higher of the two, so the last to leave) has
     cleared the bottom edge, then freeze the positions and fade to black. */
  for (uint8_t g = 0; g < TITLE_FALL_MAX; g++) {
    display_frame(d);
    if (t->y0_q4 >= TITLE_Q4(TITLE_SCREEN_H)) break;
  }
  t->falling = 0;   /* freeze positions before the fade so nothing keeps moving under it   */
                    /* (`exiting` stays set, so the backdrop does not flash back to rainbow) */
  display_fade(d, 0);
  d->tm |= t->demo_tm;               /* restore demo layers before hide_layer removes BG2 */
  display_hide_layer(d, (Drawable *)t);
  REG_HDMAEN = 0;
  REG_BG2HOFS = 0; REG_BG2HOFS = 0; /* clear HOFS latch */
  REG_BG2VOFS = 0; REG_BG2VOFS = 0; /* reset VOFS latch */
  t->active = 0;
  /* Reset CGRAM[0] (SNES backdrop) to black. The rainbow shimmer writes CGRAM[0] every frame
     during the animation and leaves it at the last hue when title_end exits. The push is queued
     here and flushed on the demo's first display_frame call, while brightness is still 0. */
  static const uint16_t _title_bg_black = 0;
  upq_push_cgram(&d->q, 0, &_title_bg_black, 0x00, sizeof _title_bg_black);
  display_fade_to(d, INIDISP_ON);    /* fade back up showing demo content */
}

/* splash16 — standalone title splash (no pre-existing display; leaves screen in force-blank).
 * Drop-in for Mode-7 demos that don't use the display system for their main render.
 * Recommended: pass TITLE_HOLD_FRAMES (120) for consistent timing. */
static inline void splash16(const char *line0, const char *line1, uint16_t frames) {
  Display _d; display_init(&_d);
  static TitleLayer _t;
  title_begin(&_d, &_t, line0, line1);
  title_end(&_d, &_t, frames);
  REG_INIDISP = 0x80;   /* re-enter force-blank for Mode 7 / VRAM setup */
}

#endif /* SNESGFX_TITLE_LAYER_H */
