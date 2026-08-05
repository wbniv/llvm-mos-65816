#include <stdio.h>
#include "../examples/65816/asmisland.h"
int main(void) {
    printf("asmisland gate_crc = 0x%04X\n", asmisland_model());
    return 0;
}
