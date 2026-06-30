/* Corpus slice: the 3-D wireframe projected-vertex math, HAL-free, run as a pure compute kernel so the
 * differential engine (dev/run.sh corpus-a16) checks it 5 ways: host == default == +mos-a16 ==
 * +mos-xy16 on MAME + bsnes-jg, -verify-machineinstrs clean. Shares examples/65816/wire3d.h with the
 * renderer (examples/snes/wireframe.c) and the host oracle (tools/wire3d-sim.c), so the three can never
 * drift. This is the MATRIX-MULTIPLY + PERSPECTIVE-DIVIDE gate. Golden value from build/wire3d-sim.
 */
#include "../../65816/wire3d.h"

volatile uint16_t corpus_result;

int main(void) {
  corpus_result = wire3d_gate_crc();
  for (;;) {}
  return 0;
}
