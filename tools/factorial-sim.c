/* Host oracle: bignum factorial gate CRC (#20 compiler stress-test demo).
 * Compiles on the host (64-bit x86) with cc -O2 -I examples/65816.
 * The gate script (dev/factorial.sh) runs this and captures the printed hash as EXPECT. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/factorial.h"

int main(void) {
    uint16_t h = factorial_gate_crc();
    printf("factorial gate_crc = 0x%04X\n", (unsigned)h);
    return 0;
}
