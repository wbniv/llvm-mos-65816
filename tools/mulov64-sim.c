#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/mulov64.h"

int main(void) {
    printf("mulov64 gate_crc = 0x%04X\n", mulov64_gate_crc());
    return 0;
}
