/* Runtime harness for the dither demo after its frame buffer moved to high WRAM (reached through the
   WRAM data port). Same measured region, end condition and fold as
   ../../2026-09-30-native-width-pressure-sets/o2-large/harness/dither_run.c; the only difference is
   that the 48x48 band indices are read back through the port, in ascending order, where that harness
   read the near array a->out. The byte stream folded is therefore identical, and so is the value
   written to corpus_result (0x15CC at 6 frames, 0x21FF at 12). harness_hook.h is that directory's. */
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
  band_seek();
  for (uint16_t i = 0u; i < (uint16_t)(DW * DH); i++) harness_byte(REG_WMDATA);
  harness_bytes(a->canvas.chr, (uint16_t)sizeof a->canvas.chr);
  harness_words(a->text.shadow, (uint16_t)(sizeof a->text.shadow / sizeof a->text.shadow[0]));
  uint16_t r = harness_result(gate);
  corpus_result = r;
  HARNESS_STOP(r);
}
