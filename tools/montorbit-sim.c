#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/montorbit.h"

int main(void) {
    printf("montorbit gate_crc = 0x%04X\n", montorbit_gate_crc());
    return 0;
}
