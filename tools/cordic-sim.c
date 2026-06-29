/* Host oracle for the #12 CORDIC rotator differential gate (mirrors tools/pi-sim.c).
 *
 * Compiles the SAME examples/65816/cordic.h the SNES program runs and prints the golden gate CRC — the
 * single source of truth asserted on both emulators across all compilation modes. Because the CORDIC core
 * keeps every intermediate inside int16 (no overflow) and uses only compile-time-constant shifts, the
 * host (32-bit int) and target (16-bit int) compute a bit-identical CRC.
 *
 * Build:  cc -O2 -std=c99 -I examples tools/cordic-sim.c -o build/cordic-sim
 */
#include <stdio.h>
#include "../examples/65816/cordic.h"

int main(void) {
    printf("cordic rotator gate  GATE_N=%u  QSTEPS=%d  DSTEP=%d  gate_crc=0x%04X\n",
           (unsigned)CORDIC_GATE_N, (int)CORDIC_QSTEPS, (int)CORDIC_DSTEP,
           (unsigned)cordic_gate_crc());
    return 0;
}
