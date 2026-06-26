/* snesgfx — VramAlloc: a bump allocator for VRAM char/tilemap regions.
 *
 * INTERNAL collaborator (owned by Display). Hands out word-addressed regions so two
 * drawables never clobber each other's VRAM. char bases are $1000-word granular
 * (BG12NBA/BG34NBA), tilemap bases $400-word granular (BG?SC) — callers round as needed.
 * Sprite (OBJ) tile VRAM is OBSEL-granular (8K-word) and is placed at a fixed page by
 * SpriteSet, so it does not go through this allocator.
 *
 * Header-only (static inline), like the rest of snesgfx and the snes.h HAL it sits on. */
#ifndef SNESGFX_VRAM_H
#define SNESGFX_VRAM_H

#include <stdint.h>

typedef struct {
  uint16_t chr_next;   /* next free char word  */
  uint16_t map_next;   /* next free tilemap word */
} VramAlloc;

static inline void vram_init(VramAlloc *v, uint16_t chr0_word, uint16_t map0_word) {
  v->chr_next = chr0_word;
  v->map_next = map0_word;
}

/* Reserve `nwords` of character VRAM; returns its word base. */
static inline uint16_t vram_chr(VramAlloc *v, uint16_t nwords) {
  uint16_t base = v->chr_next;
  v->chr_next = (uint16_t)(base + nwords);
  return base;
}

/* Reserve `nwords` of tilemap VRAM; returns its word base. */
static inline uint16_t vram_map(VramAlloc *v, uint16_t nwords) {
  uint16_t base = v->map_next;
  v->map_next = (uint16_t)(base + nwords);
  return base;
}

#endif /* SNESGFX_VRAM_H */
