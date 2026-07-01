#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/divclock.h"

int main(void) {
    printf("divclock gate_crc = 0x%04X\n", divclock_gate_crc());
    return 0;
}
