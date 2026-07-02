/* Host oracle for cpu6502 (#102). Compiles natively; prints the expected gate CRC.
   Usage: cc -O2 -I examples tools/cpu6502-sim.c -o /tmp/cpu6502-sim && /tmp/cpu6502-sim */
#include <stdio.h>
#include "cpu6502.h"

int main(void) {
    uint16_t crc = cpu6502_gate_crc();
    printf("cpu6502 gate_crc = 0x%04X\n", (unsigned)crc);
    return 0;
}
