#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/nrecip.h"

int main(void) {
    printf("nrecip gate_crc = 0x%04X\n", nrecip_gate_crc());
    return 0;
}
