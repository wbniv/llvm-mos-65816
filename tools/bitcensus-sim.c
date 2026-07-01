#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/bitcensus.h"

int main(void) {
    printf("bitcensus gate_crc = 0x%04X\n", bitcensus_gate_crc());
    return 0;
}
