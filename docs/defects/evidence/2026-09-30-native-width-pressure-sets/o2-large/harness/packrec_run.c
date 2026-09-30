/* Runtime harness: the packrec demo (examples/snes/packrec.c) for PACKREC_RUN_FRAMES frames of its
   real frame loop, without v-blank waits. See harness_hook.h. The region is the demo's whole main:
   setup, the title, the packrec gate CRC (the packed-record parse), then per frame the tick and
   display_frame, and every STEP_FRAMES-th frame parse_step (draw_record's byte_cell canvas plots,
   canvas_clear on wrap) and the HUD line. Deterministic input: the gate's fixed stream; a.t counts
   loop frames from 0. */
#include "harness_hook.h"
#include "examples/snes/packrec.c"

#ifndef PACKREC_RUN_FRAMES
#define PACKREC_RUN_FRAMES 240u
#endif

void harness_vblank(void *dp) {
  App *a = (App *)dp;
  REG_NMITIMEN = 0u;
  REG_HDMAEN = 0u;
  if (a->t != (uint16_t)PACKREC_RUN_FRAMES) return;
  uint16_t gate = corpus_result;
  harness_word(gate);
  harness_word(a->t);
  harness_word(pr_rec);
  harness_word(pr_hold);
  harness_word(pk_n);
  harness_word(pk_odd_wide);
  harness_word((uint16_t)pk_check);
  harness_word((uint16_t)(pk_check >> 16));
  harness_bytes(a->canvas.chr, (uint16_t)sizeof a->canvas.chr);
  harness_words(a->text.shadow, (uint16_t)(sizeof a->text.shadow / sizeof a->text.shadow[0]));
  uint16_t r = harness_result(gate);
  corpus_result = r;
  HARNESS_STOP(r);
}
