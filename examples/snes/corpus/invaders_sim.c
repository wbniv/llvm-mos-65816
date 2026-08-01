/* Corpus slice: the Space Invaders deterministic attract simulation, HAL-free, run as a pure
 * compute kernel so the differential engine (tools/a16_fuzz.py / dev/run.sh corpus-a16) checks it
 * 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify-machineinstrs clean.
 * Shares examples/snes/invaders_logic.h with the game (examples/snes/invaders.c) and the host
 * oracle (tools/invaders-sim.c), so the three can never drift. Golden value from build/invaders-sim.
 */
#include "../invaders_logic.h"

#ifndef INV_FRAMES
#define INV_FRAMES 600
#endif

volatile uint16_t corpus_result;

int main(void) {
  corpus_result = inv_run_crc((uint16_t)INV_FRAMES);
  for (;;) __asm__ volatile("wai");
  return 0;
}
