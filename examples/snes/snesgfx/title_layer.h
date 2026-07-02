/* snesgfx — TitleLayer: drop-in animated title overlay on BG2.
 *
 * Every demo in the battery leaves BG2 free, so the title can live there in BGMODE_1 without
 * colliding with any demo layer. Font data and the tilemap are written once in reserve() under
 * force-blank; the CINEMATIC intro (title_begin…title_end) then animates two independent BG2VOFS
 * bands via HDMA — line0 descends from the top, line1 rises from the bottom — each easing to rest
 * at centre screen. Demo drawables (canvas, text, HUD) are masked off during the title card and
 * restored in title_end(). Ink shimmer + rainbow backdrop are driven via CGRAM pushes each frame.
 *
 * Layout (always):
 *   line0 — 8×8 font, centred at tilemap row 12 (y=96;  VOFS=0 → screen row  96)
 *   line1 — real 16×16 Waldo font (font16.h; face + SE drop-shadow), tilemap rows 14–15 (y=112)
 *   (1 blank tilemap row between them; normal reading spacing.)
 *
 *   The two lines share ONE BG2 layer but each band of the screen gets its own VOFS via HDMA:
 *     Band A [scanlines 0..107]   → vofs_top  (governs line0)
 *     Band B [scanlines 108..223] → vofs_bot  (governs line1)
 *
 * VOFS geometry (VOFS=0 is the shared rest position for both lines):
 *   screen_row = tilemap_y − VOFS  (mod tilemap height = 256 px)
 *   line0 @ y=96:  vofs_top 128→0 eases screen_row from gap/top to 96  (fly-in from top)
 *   line1 @ y=112: vofs_bot −128→0 eases screen_row from 240 (below screen) to 112 (fly-in from bot)
 *   Ease-out (BOTH to bottom): vofs_top and vofs_bot both decrease 0→−128 (eff VOFS 0→255→128),
 *     walking line0 from 96→224 and line1 from 112→240 — both exit bottom simultaneously.
 *     Line1 at y=112 stays at screen_row ≥ 112 > split=108 throughout, so it never appears in
 *     band A's window regardless of vofs_top. No double-image.
 *
 * Animation timing (at 60 fps):
 *   Ease-in  ~2 s (≈120 frames) — exponential decay, TITLE_FLYIN_SHIFT=6
 *   Hold     2 s  (TITLE_HOLD_FRAMES=120) — lines stationary, shimmer/rainbow continues
 *   Ease-out ~1.2 s — constant TITLE_EASEOUT_VEL=3 px/frame; screen fades simultaneously
 *
 * VRAM layout (single mode, always mixed):
 *   tiles   0– 63  8×8 glyphs (line0)               1 K words at TITLE_CHR_WORD
 *   tiles  64–319  16×16 Waldo glyphs (line1)        4 K words at TITLE_CHR_WORD + 0x0400
 *   Total 5 K words at TITLE_CHR_WORD = 0x1000.
 *
 * HDMA channels (both free during the title intro — hud.h arms 1–2 only inside demo loops):
 *   TITLE_HDMA_CHAN_VOFS = 3 — BG2VOFS 2-band counter-slide (rebuilt each emit frame)
 *   TITLE_HDMA_CHAN_HOFS = 4 — BG2HOFS pixel-centring for line0 (static, built once in reserve)
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
#ifndef TITLE_FONT16_OFF
#include "../font16.h"   /* real 16×16 Waldo font (face + SE drop-shadow) for line1 */
#endif

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

#define TITLE_ROW0       12u      /* tilemap row for line0 (8×8);  y=96;  screen row = 96  at VOFS=0 */
#define TITLE_ROW1       14u      /* tilemap row for line1 top (16×16); y=112; screen row=112 at VOFS=0 */

/* VOFS start / target values.
   Line0: vofs_top 128→0 (enters from gap/top).
   Line1: vofs_bot −128→0 (starts below screen: eff VOFS=128 → y=112 at screen_row=240). */
#define TITLE_VOFS_TOP_START    128
#define TITLE_VOFS_BOT_START    ((int16_t)-128)
#define TITLE_VOFS_BOT_TARGET   0

/* Animation parameters */
#define TITLE_FLYIN_SHIFT    6    /* exponential decay shift — ~2 s ease-in at 60 fps           */
#define TITLE_EASEOUT_VEL    3    /* px/frame constant ease-out — ~1.2 s exit                   */
#define TITLE_HOLD_FRAMES  120    /* 2 s hold at 60 fps                                         */

/* HDMA channel assignment */
#define TITLE_HDMA_CHAN_VOFS  3u  /* BG2VOFS 2-band counter-slide                               */
#define TITLE_HDMA_CHAN_HOFS  4u  /* BG2HOFS pixel-centring for line0                           */

/* Scanline split: sits in the blank row 13 gap between line0 (rows 12) and line1 (rows 14–15). */
#define TITLE_HDMA_SPLIT  (uint8_t)((TITLE_ROW0 + 1u) * 8u + 4u)   /* = 108 */

typedef struct {
  Drawable    base;
  const char *line0;     /* 8×8 font, centred on tilemap row 12   (NULL = skip) */
  const char *line1;     /* 16×16 font, centred on tilemap rows 14–15 (NULL = skip) */
  /* --- cinematics state --- */
  int16_t     vofs_top;  /* BG2VOFS band A: 128=above screen → 0=at target (line0)          */
  int16_t     vofs_bot;  /* BG2VOFS band B: 0=below screen → 128=at target (line1)          */
  uint8_t     phase;     /* animation clock for ink shimmer + rainbow backdrop               */
  uint8_t     active;    /* 1 = emit() is live; 0 = no-op                                   */
  uint8_t     flyin;     /* 1 = ease lines toward target; 0 = hold                          */
  uint8_t     restore;   /* 1 = ease-out: slide lines back to edges                         */
  uint8_t     demo_tm;   /* saved demo drawables' TM bits, restored in title_end()          */
  uint16_t    ink;       /* live ink colour (CGRAM palette-7 colour 1)                      */
  uint16_t    back;      /* live backdrop colour (CGRAM[0])                                 */
  HScroll2    vscroll;   /* BG2VOFS 2-band HDMA table (rebuilt each emit frame)             */
  HScroll2    hscroll;   /* BG2HOFS pixel-centring HDMA table (static)                     */
} TitleLayer;

#define TITLE_INK_IDX  (uint8_t)(TITLE_PAL * 16u + 1u)   /* CGRAM entry for ink (= 113) */

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

#ifdef TITLE_FONT16_OFF
/* Legacy path (font16 disabled to save ~4 K ROM on size-tight demos, e.g. mandel-double): pixel-double
   one 8-bit plane row to 16 bits — each source bit → 2 adjacent bits (MSB=left). */
static inline uint16_t _title_expand_byte(uint8_t b) {
  uint16_t r = 0;
  for (uint8_t i = 0; i < 8u; i++)
    if (b & (uint8_t)(0x80u >> i)) r |= (uint16_t)(0xC000u >> (uint8_t)(i << 1u));
  return r;
}
#endif

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
#ifndef TITLE_FONT16_OFF
  /* Real Waldo font: 4 tiles/glyph TL,TR,BL,BR (tilemap uses 4g+0..3). FONT16 word = face | shadow<<8
     (planes 0/1); planes 2/3 = 0 → face = colour 1 (animated ink), shadow = colour 2 (fixed dark). */
  for (uint16_t g = 0; g < FONT16_N; g++) {
    for (uint8_t tile = 0; tile < 4u; tile++) {
      for (uint8_t r = 0; r < 8u; r++)
        REG_VMDATA = FONT16[(uint16_t)(g * 32u) + (uint16_t)(tile * 8u) + r];
      for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
    }
  }
#else
  /* Legacy: pixel-double the 8×8 font8 into each glyph's 4 tiles (no 4 K font16 table — for ROM-size-
     tight demos). Chunky 1-colour form; shadow colour 2 simply goes unused. */
  for (uint16_t g = 0; g < FONT8_N; g++) {
    for (uint8_t r = 0; r < 8u; r++)
      REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u)]) >> 8);
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
    for (uint8_t r = 0; r < 8u; r++)
      REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u)]) & 0xFFu);
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
    for (uint8_t r = 0; r < 8u; r++)
      REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u) + 4u]) >> 8);
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
    for (uint8_t r = 0; r < 8u; r++)
      REG_VMDATA = (uint16_t)(_title_expand_byte((uint8_t)FONT8[g * 8u + (r >> 1u) + 4u]) & 0xFFu);
    for (uint8_t r = 0; r < 8u; r++) REG_VMDATA = 0u;
  }
#endif

  /* Clear tilemap to transparent. */
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

  /* Write line1 (16×16) at tilemap rows 30 (top) and 31 (bottom), centred.
     At VOFS_bot=128, screen_row = 240-128 = 112 (same visual position as before). */
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

  /* Initial VOFS: line0 in gap/above (band A = 128 → invisible then pops in at top),
                   line1 below screen (band B = −128 → eff VOFS 128 → y=112 at screen_row 240). */
  t->vofs_top = TITLE_VOFS_TOP_START;
  t->vofs_bot = TITLE_VOFS_BOT_START;
  REG_BG2VOFS = (uint8_t)TITLE_VOFS_TOP_START; REG_BG2VOFS = (uint8_t)((uint16_t)TITLE_VOFS_TOP_START >> 8);

  /* VOFS HDMA: 2-band slide (channel 3). Rebuilt each emit() frame. */
  hscroll2_build(&t->vscroll, TITLE_HDMA_SPLIT,
                 (int16_t)TITLE_VOFS_TOP_START, TITLE_VOFS_BOT_START);
  hscroll2_arm(TITLE_HDMA_CHAN_VOFS, VSCROLL_BG2VOFS, &t->vscroll);

  /* HOFS HDMA: static pixel-centring for line0 (channel 4). */
  hscroll2_build(&t->hscroll, TITLE_HDMA_SPLIT, _title_hofs(t->line0), 0);
  hscroll2_arm(TITLE_HDMA_CHAN_HOFS, HSCROLL_BG2HOFS, &t->hscroll);

  t->base.tm_bits = TM_BG2;
}

/* ── emit ─────────────────────────────────────────────────────────────────────────────────────── */

static void _title_emit(Drawable *d, UploadQueue *q) {
  TitleLayer *t = (TitleLayer *)d;
  if (!t->active) return;

  if (t->flyin) {
    /* Line0: vofs_top decreases 128→0 (line enters from top). */
    if (t->vofs_top > 0) {
      int16_t s = (int16_t)(t->vofs_top >> TITLE_FLYIN_SHIFT);
      if (s < 1) s = 1;
      t->vofs_top -= s;
      if (t->vofs_top < 0) t->vofs_top = 0;
    }
    /* Line1: vofs_bot increases −128→0 (rises from below screen to centre). */
    if (t->vofs_bot < (int16_t)TITLE_VOFS_BOT_TARGET) {
      int16_t remain = (int16_t)((int16_t)TITLE_VOFS_BOT_TARGET - t->vofs_bot);
      int16_t s = (int16_t)(remain >> TITLE_FLYIN_SHIFT);
      if (s < 1) s = 1;
      t->vofs_bot += s;
      if (t->vofs_bot > (int16_t)TITLE_VOFS_BOT_TARGET) t->vofs_bot = (int16_t)TITLE_VOFS_BOT_TARGET;
    }
  } else if (t->restore) {
    /* Ease-out: BOTH lines exit to the BOTTOM simultaneously.
       Both vofs_top and vofs_bot decrease 0→−128 (eff VOFS sweeps 0→255→128).
       line0 @ y=96:  screen_row = 96  → 224 (off screen below).
       line1 @ y=112: screen_row = 112 → 240 (off screen below).
       Line1 at y=112 gives screen_row ≥ 112 > split=108 throughout, so it stays in band B
       and never appears as a double image in band A. Clamp both at −128 (off-screen). */
    t->vofs_top -= TITLE_EASEOUT_VEL;
    t->vofs_bot -= TITLE_EASEOUT_VEL;
    if (t->vofs_top < -128) t->vofs_top = -128;
    if (t->vofs_bot < -128) t->vofs_bot = -128;
  }

  /* Rebuild VOFS HDMA table — fixed split throughout; no dynamic tracking needed for counter-slide. */
  hscroll2_build(&t->vscroll, TITLE_HDMA_SPLIT, t->vofs_top, t->vofs_bot);

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

/* title_begin — counter-sliding fly-in title card.
 *   line0 = 8×8  (category/subtitle) — descends from top
 *   line1 = 16×16 (demo name)        — rises from bottom
 * Masks demo drawables' TM bits for the duration (restored in title_end).
 * Returns when both lines are at rest. */
static inline void title_begin(Display *d, TitleLayer *t, const char *line0, const char *line1) {
  title_init(t, line0, line1);
  t->phase = 0; t->active = 1; t->restore = 0; t->flyin = 0;
  t->ink = (uint16_t)SNES_RGB(31, 31, 31); t->back = 0u;

  uint8_t demo_tm = d->tm;            /* save demo drawables' TM bits before title is added */
  display_add(d, (Drawable *)t);      /* d->tm |= TM_BG2 */
  t->demo_tm = demo_tm;
  d->tm = TM_BG2; REG_TM = TM_BG2;  /* show only title during intro — hide canvas/HUD/text */

  REG_HDMAEN = (uint8_t)((1u << TITLE_HDMA_CHAN_VOFS) | (1u << TITLE_HDMA_CHAN_HOFS));
  d->bright = 0;
  display_fade(d, INIDISP_ON);        /* fade in with lines at start positions */
  t->flyin = 1;
  for (uint8_t g = 0;
       (t->vofs_top != 0 || t->vofs_bot != (int16_t)TITLE_VOFS_BOT_TARGET) && g < 200u;
       g++)
    display_frame(d);
  t->flyin = 0;   /* ease-in complete; clear so title_end's restore branch is reachable */
}

/* title_begin16 — backward-compat alias (all pre-existing call sites used this name). */
#define title_begin16 title_begin

/* title_end — hold for `frames` v-blanks, ease-out, fade to black, restore demo layers.
 *   Recommended: pass TITLE_HOLD_FRAMES (120 = 2 s) unless the demo has specific needs. */
static inline void title_end(Display *d, TitleLayer *t, uint16_t frames) {
  display_hold(d, frames);
  t->restore = 1;
  /* Run ease-out at FULL BRIGHTNESS until both lines have cleared their edges, then freeze and
     fade to black.  vofs_bot is clamped to 0 in _title_emit so the exit condition vofs_bot<=0
     fires safely; < 0 would require the value to have gone negative, which wraps BG2VOFS and
     makes line1 reappear at the top of the screen for the duration of display_fade. */
  for (uint8_t g = 0; g < 80u; g++) {
    display_frame(d);
    if (t->vofs_top <= -128 && t->vofs_bot <= -128) break;
  }
  t->restore = 0;   /* freeze vofs before display_fade to prevent over-scroll past wrap boundary */
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
