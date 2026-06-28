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

/* Disable a previously display_add'd layer: clear its TM bits from the shadow and rewrite the
   write-only TM register. Used to tear down a transient overlay (e.g. a TitleLayer shown during a
   demo's slow pre-loop compute) so the demo's own layer takes over. TM is a plain PPU control
   register (not VRAM/CGRAM/OAM), so this is safe to call outside v-blank. */
static inline void display_hide_layer(Display *d, Drawable *layer) {
  d->tm = (uint8_t)(d->tm & (uint8_t)~layer->tm_bits);
  REG_TM = d->tm;
}

/* One frame: wait a FRESH v-blank, force-blank during DMA (allows VRAM writes at any
   scanline — timing drift from a slightly-over-budget compute loop can push the DMA tail
   into active display; force-blank ensures those writes are never rejected).
   scene_emit() runs BEFORE snes_wait_vblank so it does not eat into the 36-scanline
   vblank window: it only touches WRAM (no PPU ports) so it is safe at any scanline. */
static inline void display_frame(Display *d) {
  (void)REG_RDNMI;                          /* clear a stale flag latched during the compute */
  scene_emit(&d->scene, &d->q);             /* build upload queue (WRAM only — any scanline) */
  snes_wait_vblank();                       /* block until the next v-blank actually begins   */
  REG_INIDISP = 0x80;                       /* force-blank: DMA succeeds at any vcounter      */
  upq_flush(&d->q);                         /* DMA — CPU stalls per job until transfer done   */
  REG_INIDISP = INIDISP_ON;                 /* restore brightness                             */
  d->shown = 1;
}

/* Hold the current screen (e.g. a just-added TitleLayer) for `frames` v-blanks. Each frame still
   emits the scene, so a demo's initial (blank) layer is harmless underneath the overlay. Use this to
   guarantee a minimum on-screen title time for demos with little pre-loop compute; demos with a long
   pre-loop compute (e.g. Newton's gate hash) need 0 here because the compute itself holds the title.
   NOTE: these frames shift a fixed-time gate screenshot — re-confirm the demo's render still completes
   before its dev/<demo>.sh capture (bump -seconds_to_run / jgxcheck frames if not). */
static inline void display_hold(Display *d, uint16_t frames) {
  while (frames--) display_frame(d);
}

#endif /* SNESGFX_DISPLAY_H */
