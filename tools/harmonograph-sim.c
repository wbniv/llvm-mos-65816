/* Host oracle: prints the harmonograph gate CRC. dev/harmonograph.sh captures it as EXPECT. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/harmonograph.h"

int main(void) {
    printf("harmonograph gate_crc = 0x%04X\n", harmo_gate_crc());
    return 0;
}
