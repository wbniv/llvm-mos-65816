#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/ovmove.h"

int main(void) {
    printf("ovmove gate_crc = 0x%04X\n", ovmove_gate_crc());
    return 0;
}
