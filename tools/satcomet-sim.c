#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/satcomet.h"

int main(void) {
    printf("satcomet gate_crc = 0x%04X\n", satcomet_gate_crc());
    return 0;
}
