/* Host oracle: prints the raycaster gate CRC. dev/raycaster.sh captures it as EXPECT. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/raycaster.h"

int main(void) {
    printf("raycaster gate_crc = 0x%04X\n", rc_gate_crc());
    return 0;
}
