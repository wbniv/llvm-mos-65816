#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/smulorbit.h"

int main(void) {
    printf("smulorbit gate_crc = 0x%04X\n", smulorbit_gate_crc());
    return 0;
}
