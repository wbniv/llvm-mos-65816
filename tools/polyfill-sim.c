#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/polyfill.h"

int main(void) {
    printf("polyfill gate_crc = 0x%04X\n", polyfill_gate_crc());
    return 0;
}
