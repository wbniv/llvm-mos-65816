/* Host oracle: prints the Conway's Game of Life gate CRC. dev/life.sh captures it as EXPECT. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/life.h"

int main(void) {
    printf("life gate_crc = 0x%04X\n", life_gate_crc());
    return 0;
}
