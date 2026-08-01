/* Corpus slice: the spirograph curve-point math, HAL-free, run as a pure compute kernel so the
 * differential engine (dev/run.sh corpus-a16) checks it 5 ways: host == default == +mos-a16 ==
 * +mos-xy16 on MAME + bsnes-jg, -verify-machineinstrs clean. Shares examples/65816/spiro.h with the
 * renderer (examples/snes/spirograph.c) and the host oracle (tools/spiro-sim.c), so the three can
 * never drift. Golden value from build/spiro-sim.
 */
#include "../../65816/spiro.h"

volatile uint16_t corpus_result;

int main(void) {
  corpus_result = spiro_gate_crc();
  for (;;) __asm__ volatile("wai");
  return 0;
}
