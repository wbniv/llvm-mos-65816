#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/truncstair.h"

int main(void) {
    printf("truncstair gate_crc = 0x%04X\n", truncstair_gate_crc());
    return 0;
}
