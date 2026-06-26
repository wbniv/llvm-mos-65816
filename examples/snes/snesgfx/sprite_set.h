/* snesgfx — SpriteSet: the OAM (hardware sprite) front-end. The central new piece.
 *
 * A contiguous 544-byte RAM OAM shadow: lo[512] (128 sprites x {Xlo, Y, tile, attr}) immediately
 * followed by hi[32] (2 bits/sprite: bit0 = X bit 8, bit1 = size select). One DMA streams all 544
 * bytes from &lo[0] each frame. A SpriteSet IS a Drawable (base struct first); its emit() enqueues
 * the OAM DMA, its reserve() programs OBSEL (size pair + tile base) and enables OBJ on the main
 * screen. Sprite tile (character) data lives at a fixed 8K-word VRAM page (OBSEL namebase), uploaded
 * separately by the client; sprite palettes occupy CGRAM 128..255 (group g -> 128 + g*16).
 *
 * Header-only (static inline). OAM was previously raw-registers-only in this repo (handoff §Sprites);
 * this is the policy layer on top. */
#ifndef SNESGFX_SPRITE_SET_H
#define SNESGFX_SPRITE_SET_H

#include <snes.h>
#include "drawable.h"
#include "upload.h"

#define SPR_OFFSCREEN_Y 0xE0   /* park Y below the 224-line screen to hide a sprite */

typedef struct {
  Drawable base;            /* member 0 — (Drawable*)&s is a free upcast */
  uint8_t  lo[512];         /* low table:  128 x {Xlo, Y, tile, attr}    */
  uint8_t  hi[32];          /* high table: 2 bits/sprite (X bit8 + size) — MUST follow lo */
  uint16_t chr_base_word;   /* sprite tile VRAM base (8K-word OBSEL granular) */
  uint8_t  size_pair;       /* OBSEL bits 7-5: the (small,large) size pair    */
} SpriteSet;

static void _sprite_reserve(Drawable *d, VramAlloc *va) {
  (void)va;                 /* OBJ tile VRAM is a fixed page, not bump-allocated */
  SpriteSet *s = (SpriteSet *)d;
  REG_OBSEL = (uint8_t)((s->size_pair << 5) | ((s->chr_base_word >> 13) & 7));
  /* TM is set by Display from the tm_bits shadow — never RMW a write-only register here. */
}

static void _sprite_emit(Drawable *d, UploadQueue *q) {
  SpriteSet *s = (SpriteSet *)d;
  upq_push_oam(q, s->lo, 0x00, 544);   /* lo[512] + hi[32], contiguous, from WRAM bank $00 */
}

static const DrawableVT SPRITE_VT = { _sprite_reserve, _sprite_emit };

/* Construct: wire the vtable, record OBSEL config, hide all 128 sprites. */
static inline void sprite_set_init(SpriteSet *s, uint8_t size_pair, uint16_t chr_base_word) {
  s->base.vt = &SPRITE_VT;
  s->base.tm_bits = TM_OBJ;       /* Display ORs this into its TM shadow */
  s->size_pair = size_pair;
  s->chr_base_word = chr_base_word;
  for (uint16_t o = 0; o < 512; o += 4) {
    s->lo[o] = 0; s->lo[o + 1] = SPR_OFFSCREEN_Y; s->lo[o + 2] = 0; s->lo[o + 3] = 0;
  }
  for (uint8_t i = 0; i < 32; i++) s->hi[i] = 0;
}

/* Full setter: write sprite i's 4 low-table bytes + its 2-bit high-table field.
   attr byte = V H pp ppp N (bit7 vflip, bit6 hflip, bits5-4 priority, bits3-1 palette, bit0 tile#8). */
static inline void sprite_set_put(SpriteSet *s, uint8_t i, int16_t x, uint8_t y,
                                  uint8_t tile, uint8_t attr, uint8_t large) {
  uint16_t o = (uint16_t)i << 2;
  s->lo[o]     = (uint8_t)x;
  s->lo[o + 1] = y;
  s->lo[o + 2] = tile;
  s->lo[o + 3] = attr;
  uint8_t sh = (uint8_t)((i & 3) << 1);
  uint8_t b  = (uint8_t)(s->hi[i >> 2] & (uint8_t)~(3u << sh));
  if (x & 0x100) b |= (uint8_t)(1u << sh);   /* X bit 8 */
  if (large)     b |= (uint8_t)(2u << sh);   /* size: large of the OBSEL pair */
  s->hi[i >> 2] = b;
}

/* Cheap reposition: X (incl. bit 8) + Y only, keeping tile/attr/size. */
static inline void sprite_set_move(SpriteSet *s, uint8_t i, int16_t x, uint8_t y) {
  uint16_t o = (uint16_t)i << 2;
  s->lo[o]     = (uint8_t)x;
  s->lo[o + 1] = y;
  uint8_t sh = (uint8_t)((i & 3) << 1);
  if (x & 0x100) s->hi[i >> 2] |= (uint8_t)(1u << sh);
  else           s->hi[i >> 2] &= (uint8_t)~(1u << sh);
}

static inline void sprite_set_hide(SpriteSet *s, uint8_t i) {
  s->lo[((uint16_t)i << 2) + 1] = SPR_OFFSCREEN_Y;
}

/* Enqueue an upload of `nbytes` of palette into sprite palette group `group` (CGRAM 128 + group*16). */
static inline void sprite_set_palette(SpriteSet *s, UploadQueue *q, uint8_t group,
                                      const void *colors, uint8_t nbytes) {
  (void)s;
  upq_push_cgram(q, (uint8_t)(128 + group * 16), colors, 0x00, nbytes);
}

#endif /* SNESGFX_SPRITE_SET_H */
