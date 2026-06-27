/* snesgfx — BitmapCanvas: a NEAR software plot surface (the spirograph demo's central new piece).
 *
 * A 128x128-pixel 2bpp tiled bitmap that lives entirely in bank-0 WRAM (a 4 KB chr shadow), so the
 * program that draws into it builds default-8-bit AND +mos-a16 AND +mos-xy16 — no far pointers. It
 * IS a Drawable (base struct first): reserve() programs the BG3 layer (2bpp in BGMODE_1) + builds a
 * static tilemap mapping a centred 16x16-tile box to the canvas tiles; emit() DMAs only the tiles
 * touched since the last frame (a capped contiguous range, <= 1 KB/v-blank like the blossom band).
 *
 * canvas_plot(x,y,color) is the rasterizer: tile = (y>>3)*16 + (x>>3), byte = (y&7)*2 in that tile,
 * bit = 7-(x&7); it ORs the two 2bpp bitplanes (the curve accumulates — never clears a pixel except
 * via canvas_clear). The tile-address shift/mask arithmetic is itself good codegen.
 *
 * Header-only (static inline). The reusable "software framebuffer" the growing SNES rendering
 * library lacked. See docs/plans/2026-06-27-11-snes-spirograph-hypotrochoid.md. */
#ifndef SNESGFX_BITMAP_CANVAS_H
#define SNESGFX_BITMAP_CANVAS_H

#include <snes.h>
#include "drawable.h"
#include "upload.h"

#define CANVAS_TILES_W  16                       /* canvas width  in 8x8 tiles -> 128 px */
#define CANVAS_TILES_H  16                       /* canvas height in 8x8 tiles -> 128 px */
#define CANVAS_W       (CANVAS_TILES_W * 8)       /* 128 */
#define CANVAS_H       (CANVAS_TILES_H * 8)       /* 128 */
#define CANVAS_NTILES  (CANVAS_TILES_W * CANVAS_TILES_H)   /* 256 */
#define CANVAS_TILEBYTES 16                       /* 2bpp: 8 rows x 2 planes */
#define CANVAS_FLUSH_TILES 64                     /* max tiles DMA'd per frame (64*16 = 1 KB/v-blank) */

typedef struct {
  Drawable base;                                  /* member 0 — (Drawable*)&c is a free upcast */
  uint8_t  chr[CANVAS_NTILES * CANVAS_TILEBYTES]; /* 2bpp tile shadow (4 KB) */
  uint16_t lo, hi;                                /* dirty tile range [lo,hi]; lo>hi == empty */
  uint16_t chr_word;                              /* BG3 char VRAM base (word) */
  uint16_t map_word;                              /* BG3 tilemap VRAM base (word) */
  uint8_t  box_col, box_row;                      /* tilemap cell where the 16x16 box starts */
} BitmapCanvas;

/* VRAM tile# of canvas tile 0 (2bpp: 8 words/tile) and of the off-box "blank" tile. */
#define _CANVAS_BASE_TILE(c)  ((uint16_t)((c)->chr_word >> 3))
#define _CANVAS_BLANK_TILE(c) ((uint16_t)(_CANVAS_BASE_TILE(c) + CANVAS_NTILES))

static void _canvas_reserve(Drawable *d, VramAlloc *va) {
  (void)va;                                       /* fixed BG3 layout, not bump-allocated */
  BitmapCanvas *c = (BitmapCanvas *)d;
  REG_BG3SC   = SNES_BGSC(c->map_word, 0);                         /* 32x32 tilemap base */
  /* BG34NBA is WRITE-ONLY — never read-modify-write it (reads return open bus). BG3 char base in the
     low nibble ($1000-word units); BG4 unused, so write the full byte. */
  REG_BG34NBA = (uint8_t)((c->chr_word >> 12) & 0x0F);
  /* Build the static tilemap: the 16x16 box shows the canvas tiles row-major; everything else the
     transparent blank tile. Direct VRAM writes are safe here — reserve() runs in force-blank. */
  uint16_t base = _CANVAS_BASE_TILE(c), blank = _CANVAS_BLANK_TILE(c);
  snes_vram_addr(c->map_word);
  for (uint8_t sy = 0; sy < 32; sy++)
    for (uint8_t sx = 0; sx < 32; sx++) {
      uint8_t inx = (uint8_t)(sx - c->box_col), iny = (uint8_t)(sy - c->box_row);
      uint16_t tile = (inx < CANVAS_TILES_W && iny < CANVAS_TILES_H)
                        ? (uint16_t)(base + iny * CANVAS_TILES_W + inx) : blank;
      REG_VMDATA = tile;
    }
  /* Zero the blank tile (8 words) and the whole canvas chr region (matches the .bss-cleared shadow). */
  snes_vram_addr(c->chr_word);
  for (uint16_t w = 0; w < (uint16_t)(CANVAS_NTILES * 8 + 8); w++) REG_VMDATA = 0;
}

static void _canvas_emit(Drawable *d, UploadQueue *q) {
  BitmapCanvas *c = (BitmapCanvas *)d;
  if (c->lo > c->hi) return;                       /* nothing dirty */
  uint16_t lo = c->lo;
  uint16_t hi = c->hi;
  if (hi - lo + 1 > CANVAS_FLUSH_TILES) hi = (uint16_t)(lo + CANVAS_FLUSH_TILES - 1); /* cap/frame */
  uint16_t ntiles = (uint16_t)(hi - lo + 1);
  upq_push_vram(q, (uint16_t)(c->chr_word + lo * 8), &c->chr[lo * CANVAS_TILEBYTES],
                0x00, (uint16_t)(ntiles * CANVAS_TILEBYTES), VMAIN_INC_HIGH_1);
  if (hi >= c->hi) { c->lo = 0xFFFF; c->hi = 0; } /* fully flushed */
  else             c->lo = (uint16_t)(hi + 1);     /* stream the remainder next frame */
}

static const DrawableVT CANVAS_VT = { _canvas_reserve, _canvas_emit };

static inline void canvas_init(BitmapCanvas *c, uint16_t chr_word, uint16_t map_word,
                               uint8_t box_col, uint8_t box_row) {
  c->base.vt = &CANVAS_VT;
  c->base.tm_bits = TM_BG3;
  c->chr_word = chr_word;
  c->map_word = map_word;
  c->box_col = box_col;
  c->box_row = box_row;
  for (uint16_t i = 0; i < CANVAS_NTILES * CANVAS_TILEBYTES; i++) c->chr[i] = 0;
  c->lo = 0xFFFF; c->hi = 0;
}

/* Set pixel (x,y) to `color` (1..3; 0 is the transparent background). OR-only — the curve
   accumulates; canvas_clear is the only eraser. Out-of-range points are dropped (unsigned compare). */
static inline void canvas_plot(BitmapCanvas *c, int16_t x, int16_t y, uint8_t color) {
  if ((uint16_t)x >= CANVAS_W || (uint16_t)y >= CANVAS_H) return;
  uint16_t tile = (uint16_t)(((uint16_t)y >> 3) * CANVAS_TILES_W + ((uint16_t)x >> 3));
  uint8_t *t = &c->chr[tile * CANVAS_TILEBYTES + ((uint8_t)y & 7) * 2];
  uint8_t mask = (uint8_t)(0x80u >> ((uint8_t)x & 7));
  if (color & 1) t[0] |= mask;
  if (color & 2) t[1] |= mask;
  if (tile < c->lo) c->lo = tile;
  if (tile > c->hi) c->hi = tile;
}

/* Bresenham line from (x0,y0) to (x1,y1) — connects consecutive curve samples so the rose is a
   continuous stroke at any point density (and is itself integer-only shift/compare codegen).
   noinline: keeps its live set out of the caller's a16/xy16 register budget (handoff §4). */
__attribute__((noinline))
static void canvas_line(BitmapCanvas *c, int16_t x0, int16_t y0, int16_t x1, int16_t y1, uint8_t color) {
  int16_t dx = (int16_t)(x1 > x0 ? x1 - x0 : x0 - x1);
  int16_t dy = (int16_t)(y1 > y0 ? y1 - y0 : y0 - y1);
  int16_t sx = (int16_t)(x0 < x1 ? 1 : -1);
  int16_t sy = (int16_t)(y0 < y1 ? 1 : -1);
  int16_t err = (int16_t)(dx - dy);
  for (;;) {
    canvas_plot(c, x0, y0, color);
    if (x0 == x1 && y0 == y1) break;
    int16_t e2 = (int16_t)(err * 2);
    if (e2 > -dy) { err = (int16_t)(err - dy); x0 = (int16_t)(x0 + sx); }
    if (e2 <  dx) { err = (int16_t)(err + dx); y0 = (int16_t)(y0 + sy); }
  }
}

static inline void canvas_clear(BitmapCanvas *c) {
  for (uint16_t i = 0; i < CANVAS_NTILES * CANVAS_TILEBYTES; i++) c->chr[i] = 0;
  c->lo = 0; c->hi = (uint16_t)(CANVAS_NTILES - 1);  /* re-DMA the whole canvas (capped/frame) */
}

#endif /* SNESGFX_BITMAP_CANVAS_H */
