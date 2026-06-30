/* Host oracle for the cardioid differential gate.
 * Compiles examples/65816/cardioid.h on the host and prints the golden gate hash —
 * the single source of truth asserted on both emulators.
 * Build: cc -O2 -I examples/65816 tools/cardioid-sim.c -o build/cardioid-sim
 */
#include <stdio.h>
#include "cardioid.h"

int main(void) {
    uint16_t h = card_gate_crc();
    printf("cardioid gate  k=2..8 x N=%u  hash=0x%04X\n", (unsigned)CARD_N, (unsigned)h);
    return 0;
}
