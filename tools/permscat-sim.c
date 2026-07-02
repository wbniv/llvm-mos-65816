#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/permscat.h"

int main(void) {
    printf("permscat gate_crc = 0x%04X\n", permscat_gate_crc());
    return 0;
}
