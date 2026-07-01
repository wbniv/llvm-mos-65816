#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/satcast.h"

int main(void) {
    printf("satcast gate_crc = 0x%04X\n", satcast_gate_crc());
    return 0;
}
