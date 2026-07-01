#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/mvscrl.h"

int main(void) {
    printf("mvscrl gate_crc = 0x%04X\n", mvscrl_gate_crc());
    return 0;
}
