#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/trimerge.h"

int main(void) {
    printf("trimerge gate_crc = 0x%04X\n", trimerge_gate_crc());
    return 0;
}
