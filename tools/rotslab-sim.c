#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/rotslab.h"

int main(void) {
    printf("rotslab gate_crc = 0x%04X\n", rotslab_gate_crc());
    return 0;
}
