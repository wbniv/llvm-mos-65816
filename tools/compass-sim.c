#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/compass.h"

int main(void) {
    printf("compass gate_crc = 0x%04X\n", compass_gate_crc());
    return 0;
}
