#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/disbits.h"

int main(void) {
    printf("disbits gate_crc = 0x%04X\n", disbits_gate_crc());
    return 0;
}
