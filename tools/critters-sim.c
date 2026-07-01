#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/critters.h"

int main(void) {
    printf("critters gate_crc = 0x%04X\n", critters_gate_crc());
    return 0;
}
