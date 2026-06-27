/* tools/newton-sim.c — host oracle for the Newton's-method fractal gate (#2).
 * Compiles with: cc -O2 -I examples examples/snes/corpus/newton_sim.c  (corpus)
 *            or: cc -O2 -I examples tools/newton-sim.c  (oracle; same CRC printed)
 * Used by dev/newton.sh §1 to obtain the golden EXPECT value.                   */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/newton.h"

int main(void) {
    uint16_t h = newton_gate_crc();
    printf("newton gate_crc = 0x%04X\n", h);
    return 0;
}
