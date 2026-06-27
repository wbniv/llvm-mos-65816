/* Host oracle for the spirograph differential gate (mirrors tools/invaders-sim.c / mandel-render.c).
 *
 * Compiles the SAME examples/65816/spiro.h the SNES program runs and prints the golden gate hash —
 * the single source of truth asserted on both emulators (host == default == +mos-a16 == +mos-xy16).
 *
 * Build:  cc -O2 -I examples/65816 tools/spiro-sim.c -o build/spiro-sim
 */
#include <stdio.h>
#include "spiro.h"

int main(void) {
  uint16_t h = spiro_gate_crc();
  printf("spirograph gate  K=%u/mode x %d modes  hash=0x%04X\n",
         (unsigned)SPIRO_K_GATE, (int)SPIRO_NMODES, (unsigned)h);
  return 0;
}
