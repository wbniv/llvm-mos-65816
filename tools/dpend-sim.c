/* Host oracle for the double-pendulum gate (#14 compiler stress-test demo).
 * Compiles with: cc -O2 -I examples/65816 tools/dpend-sim.c -o build/dpend-sim
 * Prints the golden 16-bit gate CRC that the gate script captures as EXPECT. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/dpend.h"

int main(void) {
    uint16_t h = dpend_gate_crc();
    printf("double-pendulum gate_crc = 0x%04X\n", (unsigned)h);
    return 0;
}
