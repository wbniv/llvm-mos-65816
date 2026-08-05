#include <stdio.h>
#include "../examples/65816/mixedwidth.h"

int main(void) {
    printf("mixedwidth gate_crc = 0x%04X\n", mixedwidth_model());
    return 0;
}
