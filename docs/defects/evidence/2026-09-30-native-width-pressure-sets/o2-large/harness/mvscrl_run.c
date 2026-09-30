/* Runtime harness: the mvscrl demo (examples/snes/mvscrl.c) for MVSCRL_RUN_STEPS memmove scroll steps
   of its real frame loop (8 frames per step), without v-blank waits. See harness_hook.h. The region
   is the demo's whole main: app_init (16 ring rows painted), the title, the mvscrl gate CRC, then per
   frame build_bands + hscrolldb_commit, every 8th frame mv_step + two paint_ring_row, every 8th
   (offset 4) the HUD, and display_frame. Deterministic input: a.t starts at 0 and steps by 7. */
#include "harness_hook.h"
#include "examples/snes/mvscrl.c"

#ifndef MVSCRL_RUN_STEPS
#define MVSCRL_RUN_STEPS 16u
#endif

void harness_vblank(void *dp) {
  App *a = (App *)dp;
  REG_NMITIMEN = 0u;
  REG_HDMAEN = 0u;
  if (a->t != (uint16_t)(7u * MVSCRL_RUN_STEPS)) return;
  uint16_t gate = corpus_result;
  harness_word(gate);
  harness_word(a->t);
  harness_byte(a->pos);
  harness_bytes(&a->mv.upper[0][0], (uint16_t)sizeof a->mv.upper);
  harness_bytes(&a->mv.lower[0][0], (uint16_t)sizeof a->mv.lower);
  harness_bytes(a->vdb.buf[0].tab, (uint16_t)sizeof a->vdb.buf[0].tab);
  harness_bytes(a->vdb.buf[1].tab, (uint16_t)sizeof a->vdb.buf[1].tab);
  harness_byte(a->vdb.cur);
  harness_bytes(a->canvas.chr, (uint16_t)sizeof a->canvas.chr);
  harness_words(a->text.shadow, (uint16_t)(sizeof a->text.shadow / sizeof a->text.shadow[0]));
  uint16_t r = harness_result(gate);
  corpus_result = r;
  HARNESS_STOP(r);
}
