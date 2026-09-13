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
                          /* OR'd into Display's TM shadow (TM $212C is WRITE-ONLY: never |=). */
  uint8_t first_frame_complete;  /* the "first frame is complete" OPT-IN — see below.         */
};

/* first_frame_complete — a per-drawable assertion written by reserve(), read by Display.
 *
 * Setting it to 1 asserts: "everything my first VISIBLE frame shows, I painted myself inside the
 * boot force-blank — the tilemap, the chr, AND the CGRAM entries those tiles index (CGRAM[0], the
 * backdrop, included wherever my area can show it). Nothing my first visible frame depends on
 * arrives through the UploadQueue, i.e. through my emit()."
 *
 * Display uses it for an early blank release: when EVERY drawable in the scene asserts it, the
 * first display_frame() skips scene_emit(), so the screen comes up one frame earlier — more where
 * the first emit() is expensive — showing exactly what reserve() painted. One non-asserting
 * drawable disables it for the whole scene, so the default is the behaviour we have today.
 *
 * It is a correctness claim, not an optimisation hint, and it is checked. Asserting it falsely
 * shows one frame of whatever VRAM/CGRAM held before; on hardware and at bsnes-jg's default
 * entropy that is random, so `dev/bootblank.sh --firstframe` catches it as a nondeterministic
 * first visible frame. Most drawables must NOT set it: snesgfx deliberately routes CGRAM through
 * the UploadQueue, so the common `if (!pal_sent) upq_push_cgram(...)` idiom in emit() means the
 * first visible frame WOULD depend on the queue — 119 of the 122 Display demos are in that class.
 * See docs/plans/2026-09-14-display-first-frame-optin.md.
 *
 * Default 0 is guaranteed for every construction path (static, automatic, designated initialiser,
 * memset, ad-hoc demo-local init) because drawable_reserve() clears it immediately before
 * dispatching; a reserve() that wants the opt-in sets it to 1 as its last act. */
static inline void drawable_reserve(Drawable *d, VramAlloc *va) {
  d->first_frame_complete = 0;    /* opt-in is OFF unless this reserve() asserts it */
  d->vt->reserve(d, va);
}
static inline void drawable_emit   (Drawable *d, UploadQueue *q) { d->vt->emit(d, q); }

#endif /* SNESGFX_DRAWABLE_H */
