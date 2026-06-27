#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/rdiff.h"
static rdiff_gate_state gstate;
int main(void) {
    printf("rdiff gate_crc = 0x%04X\n", rdiff_gate_crc(&gstate));
    return 0;
}
