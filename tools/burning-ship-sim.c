/* Host oracle: prints the Burning Ship gate CRC. dev/burning-ship.sh captures it as EXPECT. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/burning_ship.h"

int main(void) {
    printf("burning-ship gate_crc = 0x%04X\n", bs_gate_crc());
    return 0;
}
