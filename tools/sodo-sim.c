#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/sodo.h"

int main(void) {
    printf("sodo gate_crc = 0x%04X\n", sodo_gate_crc());
    return 0;
}
