/* snesgfx — Drawable: the render-layer interface (the justified per-object vtable).
 *
 * This is the ONE place snesgfx uses dynamic dispatch: a Scene holds Drawable* of genuinely
 * different kinds (SpriteSet, TextLayer, ShieldField, Mode7Layer), so the call site doesn't
 * know the concrete type. Dispatch is COARSE — `emit()` is called once per drawable per frame,
 * never in a per-tile/per-entity inner loop (oop-in-c §4/§5: a virtual call is ~8 ZP ops +
 * JMP(vector), not inlinable). Game entities are static-dispatch objects, not Drawables.
 *
 * Header-only (static inline). A concrete drawable embeds `Drawable base` as member 0 so the
 * upcast (Drawable*)&thing is free (single-inheritance, base-struct-first). */
#ifndef SNESGFX_DRAWABLE_H
#define SNESGFX_DRAWABLE_H

#include "vram.h"
#include "upload.h"

typedef struct Drawable Drawable;

typedef struct {
  void (*reserve)(Drawable *self, VramAlloc *va);   /* claim VRAM / set layer regs (once) */
  void (*emit)   (Drawable *self, UploadQueue *q);  /* enqueue this frame's uploads        */
} DrawableVT;

struct Drawable {
  const DrawableVT *vt;   /* base object: vtable pointer FIRST */
  uint8_t tm_bits;        /* main-screen enable bit(s) for this layer (TM_OBJ/TM_BG1/...) — */
};                        /* OR'd into Display's TM shadow (TM $212C is WRITE-ONLY: never |=). */

static inline void drawable_reserve(Drawable *d, VramAlloc *va) { d->vt->reserve(d, va); }
static inline void drawable_emit   (Drawable *d, UploadQueue *q) { d->vt->emit(d, q); }

#endif /* SNESGFX_DRAWABLE_H */
