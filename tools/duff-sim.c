#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/duff.h"

int main(void) {
    printf("duff gate_crc = 0x%04X\n", duff_gate_crc());
    return 0;
}
