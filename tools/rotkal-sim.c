#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/rotkal.h"

int main(void) {
    printf("rotkal gate_crc = 0x%04X\n", rotkal_gate_crc());
    return 0;
}
