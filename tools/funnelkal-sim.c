#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/funnelkal.h"

int main(void) {
    printf("funnelkal gate_crc = 0x%04X\n", funnelkal_gate_crc());
    return 0;
}
