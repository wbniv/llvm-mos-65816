// Host oracle for the #10 Fourier-epicycles demo: prints epi_gate_crc() — the golden differential
// anchor dev/epicycles.sh asserts against the on-console build + both emulators.
// Build: cc -O2 -I examples/65816 tools/epicycles-sim.c -o /tmp/epi-sim && /tmp/epi-sim
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/epicycles.h"
int main(void) { printf("epicycles gate_crc = 0x%04X\n", epi_gate_crc()); return 0; }
