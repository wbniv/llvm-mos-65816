#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/ropeedit.h"

int main(void) {
    printf("ropeedit gate_crc = 0x%04X\n", ropeedit_gate_crc());
    return 0;
}
