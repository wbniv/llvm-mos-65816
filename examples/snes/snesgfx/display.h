/* snesgfx — Display: the root rendering context (the client's only entry point).
 *
 * Owns the boot bracket, the UploadQueue, the VramAlloc, and the Scene as PRIVATE collaborators.
 * The two hardware correctness invariants live here and cannot be bypassed by the client:
 *   - the boot bracket: snes_ppu_reset_blank() zeroes ALL PPU control regs + holds force-blank.
 *     This is the ONLY force-blank in snesgfx — the console powers on blanked, drawables do their
 *     bulk VRAM setup inside that window, and the first display_frame() releases it. It is never
 *     re-asserted: blanking mid-run to widen the DMA window blanks the top of the picture if the
 *     transfer overruns v-blank, which is a visible flicker. Clear the screen instead;
 *   - the access window: the queue flushes (DMA) only inside the v-blank display_frame waits for,
 *     and only up to UPQ_VBLANK_BUDGET bytes of it.
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
  uint8_t     shown;   /* boot force-blank released yet? (set by the first display_frame) */
  uint8_t     late_add;/* 1 = a display_add arrived after `shown` — see display_add()      */
  uint8_t     bright;  /* current INIDISP master brightness 0..15 (the post-flush value)          */
  uint8_t     btgt;    /* brightness target — display_frame ramps `bright` one step toward it      */
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
  d->late_add = 0;
  d->bright = INIDISP_ON;                   /* default full brightness — the ramp is a no-op    */
  d->btgt   = INIDISP_ON;                   /* until a fade is requested (display_fade_to)        */
  REG_BGMODE   = BGMODE_1;                  /* BG1/BG2 4bpp, BG3 2bpp */
  REG_TM       = 0;                          /* all layers off until drawables enable theirs */
  REG_NMITIMEN = NMITIMEN_NMI | NMITIMEN_AUTOJOY; /* v-blank pacing + default automatic pad latch */
}

/* Add a drawable, reserve its VRAM / set its layer registers, and enable its layer on the main
   screen via the TM shadow (never a read-modify-write of the write-only TM register).

   MUST be called before the first display_frame(). reserve() implementations bulk-write VRAM
   through REG_VMDATA, which is only legal while the boot force-blank is still up; the first
   display_frame() releases it and it is never re-asserted, so a later display_add would write
   VRAM during active display and silently corrupt it. `late_add` records the violation rather
   than letting it pass unnoticed — all current demos call app_init (display_init + every
   display_add, no frames) before title_begin, which is the shape that keeps this true. */
static inline void display_add(Display *d, Drawable *layer) {
  if (d->shown) d->late_add = 1;
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

/* One frame: build the queue, then flush it inside a FRESH v-blank.
   NO force-blank. This used to bracket the flush in force-blank so an over-long DMA could not be
   rejected — but a force-blank released after v-blank has already ended blanks the top scanlines
   of the picture, which the viewer sees as a flicker at the top of the screen. The queue now
   stays inside the window on its own (UPQ_VBLANK_BUDGET), so nothing needs blanking.
   scene_emit() runs BEFORE snes_wait_vblank so it does not eat into the ~38-scanline v-blank
   window: it only touches WRAM (no PPU ports) so it is safe at any scanline.
   The RDNMI clear sits AFTER scene_emit deliberately — emit can be slow enough to span a
   v-blank, and consuming that stale flag would let the flush start in ACTIVE DISPLAY, which
   without force-blank means dropped/corrupt VRAM writes. Clearing here costs at most one frame
   of latency and guarantees the flush begins at the top of a real v-blank. */
static inline void display_frame(Display *d) {
  scene_emit(&d->scene, &d->q);             /* build upload queue (WRAM only — any scanline) */
  (void)REG_RDNMI;                          /* discard any v-blank that elapsed during emit   */
  snes_wait_vblank();                       /* block until the next v-blank actually begins   */
  upq_flush(&d->q);                         /* DMA, budgeted to fit the window                */
  /* Ramp the master brightness one step toward its target (the title-screen fade in/out). With
     btgt == bright (the default) this is a no-op and the screen is simply full-on. */
  if (d->bright < d->btgt)      d->bright++;
  else if (d->bright > d->btgt) d->bright--;
  REG_INIDISP = (uint8_t)(d->bright & 0x0Fu); /* force-blank bit can never escape this API     */
  d->shown = 1;
}

/* Set the brightness fade target (0 = black .. 15 = full). display_frame ramps toward it 1/frame. */
static inline void display_fade_to(Display *d, uint8_t target) {
  d->btgt = (uint8_t)(target & 0x0Fu);
}

/* Block, ramping the master brightness to `target` (one step per v-blank), so the screen fades to
   `target` over ~|bright-target| frames. The scene still emits each frame, so a fading title's
   slide/shimmer/backdrop keep animating through the fade. */
static inline void display_fade(Display *d, uint8_t target) {
  d->btgt = target;
  while (d->bright != target) display_frame(d);
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
