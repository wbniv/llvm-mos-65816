/* Host oracle for the N-body differential gate (mirrors tools/pi-sim.c / tools/spiro-sim.c).
 *
 * Compiles the SAME examples/65816/n-body.h the SNES program runs and prints the golden gate
 * hash — the single source of truth asserted on both emulators (host == default == +mos-a16
 * == +mos-xy16).
 *
 * Build:  cc -O2 -I examples/65816 tools/nbody-sim.c -o build/nbody-sim
 */
#include <stdio.h>
#include "n-body.h"

int main(void) {
    uint16_t h = nbody_gate_crc();
    printf("n-body gate  N=%d bodies  steps=%u  hash=0x%04X\n",
           NBODY_N, (unsigned)NBODY_GATE_STEPS, (unsigned)h);
    return 0;
}
