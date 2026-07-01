#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/seqvm.h"

int main(void) {
    printf("seqvm gate_crc = 0x%04X\n", seqvm_gate_crc());
    return 0;
}
