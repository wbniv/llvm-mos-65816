/* Host oracle for the #1 SNES Julia-set demo: prints the differential gate hash (julia_gate_crc()
 * from examples/65816/julia.h, compiled host-side). dev/julia.sh captures this as EXPECT and asserts
 * the on-console corpus_result (bsnes-jg + MAME) matches it. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/julia.h"

int main(void) {
    printf("julia gate_crc = 0x%04X\n", julia_gate_crc());
    return 0;
}
