#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/bitshuffle.h"

int main(void) {
    printf("bitshuffle gate_crc = 0x%04X\n", bitshuffle_gate_crc());
    return 0;
}
