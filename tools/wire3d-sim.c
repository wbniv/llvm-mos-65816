/* Host oracle for the 3-D Wireframe demo (#16): compiles examples/65816/wire3d.h on the host
 * (int = 32) and prints the projected-vertex gate hash — the golden value the differential asserts
 * the 65816 target (int = 16) reproduces bit-for-bit. Build: cc -O2 -I examples tools/wire3d-sim.c */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/wire3d.h"

int main(void) {
  printf("wire3d gate_crc = 0x%04X\n", wire3d_gate_crc());
  return 0;
}
