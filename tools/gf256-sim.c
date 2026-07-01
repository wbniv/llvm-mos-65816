#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/gf256.h"

int main(void) {
    printf("gf256 gate_crc = 0x%04X\n", gf256_gate_crc());
    return 0;
}
