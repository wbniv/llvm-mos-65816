#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/nmitally.h"

int main(void) {
    uint32_t wide;
    uint16_t crc = nmitally_model((uint16_t)NMITALLY_FRAMES, &wide);
    printf("nmitally gate_crc = 0x%04X wide=0x%08lX\n",
           crc, (unsigned long)wide);
    return 0;
}
