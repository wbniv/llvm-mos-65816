/* Runtime harness: the dither demo (examples/snes/dither.c, #70) for DITHER_RUN_FRAMES frames of
   its real frame loop, without v-blank waits. See harness_hook.h. The measured region is the demo's
   whole main: app_init, the title (its held frames run back to back), the dither gate CRC, and
   DITHER_RUN_FRAMES iterations of dither_frame (ds_dither + 4 canvas_plot per pixel) and
   display_frame (scene emit + budgeted upload). Deterministic input: a.t starts at 0 and steps by 3. */
#include "harness_hook.h"
#include "examples/snes/dither.c"

#ifndef DITHER_RUN_FRAMES
#define DITHER_RUN_FRAMES 12u
#endif

void harness_vblank(void *dp) {
  App *a = (App *)dp;
  REG_NMITIMEN = 0u;
  REG_HDMAEN = 0u;
  if (a->t != (uint16_t)(3u * DITHER_RUN_FRAMES)) return;
  uint16_t gate = corpus_result;
  harness_word(gate);
  harness_word(a->t);
  harness_bytes(a->out, (uint16_t)sizeof a->out);
  harness_bytes(a->canvas.chr, (uint16_t)sizeof a->canvas.chr);
  harness_words(a->text.shadow, (uint16_t)(sizeof a->text.shadow / sizeof a->text.shadow[0]));
  uint16_t r = harness_result(gate);
  corpus_result = r;
  HARNESS_STOP(r);
}
