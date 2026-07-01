#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/qsortviz.h"

int main(void) {
    printf("qsortviz gate_crc = 0x%04X\n", qsortviz_gate_crc());
    return 0;
}
