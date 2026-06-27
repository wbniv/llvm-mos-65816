/* Host oracle for the π spigot differential gate (mirrors tools/spiro-sim.c).
 *
 * Compiles the SAME examples/65816/pi_spigot.h the SNES program runs and prints the golden
 * gate CRC — the single source of truth asserted on both emulators across all compilation modes.
 *
 * Build:  cc -O2 -I examples/65816 tools/pi-sim.c -o build/pi-sim
 */
#include <stdio.h>
#include "pi_spigot.h"

static pi_spigot_state sp;
static mc_state mc;

int main(void) {
    uint16_t h = pi_gate_crc(&sp, &mc);
    printf("pi spigot+mc gate  PI_DIGITS=%d  PI_GATE_DIGITS=%u  MC_THROWS=%u  hash=0x%04X\n",
           (int)PI_DIGITS, (unsigned)PI_GATE_DIGITS, (unsigned)PI_GATE_THROWS, (unsigned)h);
    return 0;
}
