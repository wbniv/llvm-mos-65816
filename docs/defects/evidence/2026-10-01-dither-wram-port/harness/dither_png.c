/* Framebuffer harness: the dither demo with its real v-blank pacing, frozen after PNG_K dither
   iterations so that two builds can be compared pixel for pixel at the same animation state.

   The canvas accumulates (canvas_plot ORs), so the picture depends on how many dither_frame calls
   have run, not on how many video frames have elapsed; a build that dithers faster is therefore
   further along at a fixed emulator frame. This harness stops every build at the same iteration:
   display_frame's v-blank wait still runs, and once the demo's t reaches 3 * PNG_K the hook waits
   for v-blank forever instead of returning, so that call's upload never happens and the screen
   keeps the state flushed up to the previous iteration. corpus_result is the demo's own gate write. */
#include <snes.h>
static void png_vblank(void *d);
#define snes_wait_vblank() png_vblank(d)
#include "examples/snes/dither.c"

#ifndef PNG_K
#define PNG_K 10u
#endif

static void png_vblank(void *dp) {
  App *a = (App *)dp;
  (snes_wait_vblank)();
  if (a->t >= (uint16_t)(3u * PNG_K))
    for (;;) (snes_wait_vblank)();
}
