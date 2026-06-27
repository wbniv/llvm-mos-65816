/* Host oracle: prints the ca1d gate CRC. dev/1d-ca.sh captures it as EXPECT. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/ca1d.h"

int main(void) {
    printf("ca1d gate_crc = 0x%04X\n", ca_gate_crc());
    return 0;
}
