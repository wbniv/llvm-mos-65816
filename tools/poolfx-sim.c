#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/poolfx.h"

int main(void) {
    printf("poolfx gate_crc = 0x%04X\n", poolfx_gate_crc());
    return 0;
}
