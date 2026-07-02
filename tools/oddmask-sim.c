#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/oddmask.h"

int main(void) {
    printf("oddmask gate_crc = 0x%04X\n", oddmask_gate_crc());
    return 0;
}
