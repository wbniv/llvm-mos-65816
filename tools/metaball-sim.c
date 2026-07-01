#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/metaball.h"

int main(void) {
    printf("metaball gate_crc = 0x%04X\n", metaball_gate_crc());
    return 0;
}
