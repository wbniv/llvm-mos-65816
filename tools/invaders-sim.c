/* Host oracle for the Space Invaders differential gate (mirrors tools/mandel-render.c).
 *
 * Compiles the SAME examples/snes/invaders_logic.h the SNES game runs, executes the identical
 * deterministic attract sequence for INV_FRAMES frames, and prints the golden rolling CRC. That
 * value is the single source of truth asserted on both emulators (host == default@MAME ==
 * a16@MAME == a16@bsnes-jg).
 *
 * Build:  cc -O2 -I examples/snes tools/invaders-sim.c -o build/invaders-sim
 */
#include <stdio.h>
#include "invaders_logic.h"

#ifndef INV_FRAMES
#define INV_FRAMES 600
#endif

int main(void) {
  uint16_t crc = inv_run_crc((uint16_t)INV_FRAMES);
  printf("invaders %d frames  CRC16=0x%04X\n", (int)INV_FRAMES, crc);
  return 0;
}
