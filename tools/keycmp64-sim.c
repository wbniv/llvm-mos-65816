#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/keycmp64.h"

int main(void) {
    printf("keycmp64 gate_crc = 0x%04X\n", keycmp64_gate_crc());
    return 0;
}
