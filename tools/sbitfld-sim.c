#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/sbitfld.h"

int main(void) {
    printf("sbitfld gate_crc = 0x%04X\n", sbitfld_gate_crc());
    return 0;
}
