#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/fabsridge.h"

int main(void) {
    printf("fabsridge gate_crc = 0x%04X\n", fabsridge_gate_crc());
    return 0;
}
