#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/lzdec.h"

int main(void) {
    printf("lzdec gate_crc = 0x%04X\n", lzdec_gate_crc());
    return 0;
}
