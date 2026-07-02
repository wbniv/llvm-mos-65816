#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/speedcap.h"

int main(void) {
    printf("speedcap gate_crc = 0x%04X\n", speedcap_gate_crc());
    return 0;
}
