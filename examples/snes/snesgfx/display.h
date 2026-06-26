/* snesgfx — Display: the root rendering context (the client's only entry point).
 *
 * Owns the boot bracket, the UploadQueue, the VramAlloc, and the Scene as PRIVATE collaborators.
 * The two hardware correctness invariants live here and cannot be bypassed by the client:
 *   - the boot bracket: snes_ppu_reset_blank() zeroes ALL PPU control regs + holds force-blank,
 *     and force-blank is released LAST (after the first complete upload) — handoff §1's #1
 *     determinism trap, owned by the constructor;
 *   - the access window: the queue flushes (DMA) only inside the v-blank display_frame waits for.
 * The client constructs a Display, hands it drawables, and calls display_frame() — no bare
 * snes_ / REG_ pokes (no-bare-functions rule).
 *
 * Header-only (static inline). This build selects BGMODE_1 (BG1 4bpp + BG3 2bpp + OBJ). */
#ifndef SNESGFX_DISPLAY_H
#define SNESGFX_DISPLAY_H

#include <snes.h>
#include "upload.h"
#include "vram.h"
#include "scene.h"

typedef struct {
  UploadQueue q;       /* private collaborator */
  VramAlloc   va;      /* private collaborator */
  Scene       scene;   /* the drawables        */
  uint8_t     tm;      /* TM ($212C) shadow — TM is WRITE-ONLY, so we never read-modify-write it */
  uint8_t     shown;   /* force-blank released yet? */
} Display;

/* Constructor: the boot bracket. Force-blank + zero all PPU control regs, init the owned
   queue/alloc/scene, select BG mode, arm the v-blank NMI flag. Screen stays force-blanked
   until the first complete frame (display_frame releases it). */
static inline void display_init(Display *d) {
  snes_ppu_reset_blank();                 /* force-blank + zero $2101..$2133 (skips data ports) */
  upq_init(&d->q, 0);                      /* GP-DMA channel 0 */
  vram_init(&d->va, 0x0000, 0x0000);       /* BG regions bump-allocate from word 0 (OBJ uses a fixed page) */
  scene_init(&d->scene);
  d->tm = 0;
  d->shown = 0;
  REG_BGMODE   = BGMODE_1;                  /* BG1/BG2 4bpp, BG3 2bpp */
  REG_TM       = 0;                          /* all layers off until drawables enable theirs */
  REG_NMITIMEN = NMITIMEN_NMI;              /* enable the v-blank NMI flag so snes_wait_vblank() works */
}

/* Add a drawable, reserve its VRAM / set its layer registers, and enable its layer on the main
   screen via the TM shadow (never a read-modify-write of the write-only TM register). */
static inline void display_add(Display *d, Drawable *layer) {
  scene_add(&d->scene, layer);
  drawable_reserve(layer, &d->va);
  d->tm = (uint8_t)(d->tm | layer->tm_bits);
  REG_TM = d->tm;
}

/* One frame: wait a FRESH v-blank (discard a stale flag first), let each drawable emit into the
   queue, flush it via DMA, and on the FIRST frame release force-blank LAST — screen on only
   after a complete upload (no flash, deterministic). */
static inline void display_frame(Display *d) {
  (void)REG_RDNMI;                          /* clear a stale flag latched during the compute */
  snes_wait_vblank();                       /* block until the next v-blank actually begins   */
  scene_emit(&d->scene, &d->q);             /* one virtual emit() per drawable                */
  upq_flush(&d->q);                         /* the only PPU-data-port writes, in v-blank      */
  if (!d->shown) { REG_INIDISP = INIDISP_ON; d->shown = 1; }
}

#endif /* SNESGFX_DISPLAY_H */
