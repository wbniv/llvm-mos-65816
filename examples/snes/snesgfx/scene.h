/* snesgfx — Scene: the heterogeneous container of Drawable* (the justified-vtable case).
 *
 * scene_emit is the loop oop-in-c §6 describes: Drawable* items[N] iterated, ONE virtual call
 * each. A Space Invaders scene = { SpriteSet, TextLayer, ShieldField } → 3 virtual emit()/frame,
 * the entire dispatch budget. Owned by Display; the client never touches the Scene directly.
 *
 * Header-only (static inline). */
#ifndef SNESGFX_SCENE_H
#define SNESGFX_SCENE_H

#include "drawable.h"

#ifndef SCENE_MAX
#define SCENE_MAX 4
#endif

typedef struct {
  Drawable *items[SCENE_MAX];
  uint8_t   n;
} Scene;

static inline void scene_init(Scene *s) { s->n = 0; }

static inline void scene_add(Scene *s, Drawable *d) {
  if (s->n < SCENE_MAX) s->items[s->n++] = d;
}

static inline void scene_reserve(Scene *s, VramAlloc *va) {
  for (uint8_t i = 0; i < s->n; i++) drawable_reserve(s->items[i], va);
}

static inline void scene_emit(Scene *s, UploadQueue *q) {
  for (uint8_t i = 0; i < s->n; i++) drawable_emit(s->items[i], q);  /* one indirect call each */
}

#endif /* SNESGFX_SCENE_H */
