#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/crcwall.h"

int main(void) {
    printf("crcwall gate_crc = 0x%04X\n", crcwall_gate_crc());
    return 0;
}
