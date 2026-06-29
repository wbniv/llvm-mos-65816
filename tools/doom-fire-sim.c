#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/doom-fire.h"
static doomfire_gate_state gstate;
int main(void) {
    printf("doom-fire gate_crc = 0x%04X\n", doomfire_gate_crc(&gstate));
    return 0;
}
