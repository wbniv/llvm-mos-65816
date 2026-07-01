#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/cgrade.h"

int main(void) {
    printf("cgrade gate_crc = 0x%04X\n", cgrade_gate_crc());
    return 0;
}
