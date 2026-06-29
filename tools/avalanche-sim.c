/* Host oracle for the #22 SNES 64-bit Avalanche demo: prints the differential gate hash
 * (h64_gate_crc() from examples/65816/avalanche.h, compiled host-side with native uint64_t).
 * dev/avalanche.sh captures this as EXPECT and asserts the on-console corpus_result (bsnes-jg + MAME)
 * matches it bit-for-bit. 64-bit integer ops are exact, so no contraction/rounding caveats apply. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/avalanche.h"

int main(void) {
    printf("avalanche gate_crc = 0x%04X\n", h64_gate_crc());
    return 0;
}
