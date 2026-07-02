#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/ucmprank.h"

int main(void) {
    printf("ucmprank gate_crc = 0x%04X\n", ucmprank_gate_crc());
    return 0;
}
