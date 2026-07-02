#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/spaceship.h"

int main(void) {
    printf("spaceship gate_crc = 0x%04X\n", spaceship_gate_crc());
    return 0;
}
