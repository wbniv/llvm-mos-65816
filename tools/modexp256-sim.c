#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/modexp256.h"

int main(void) {
    printf("modexp256 gate_crc = 0x%04X\n", modexp256_gate_crc());
    return 0;
}
