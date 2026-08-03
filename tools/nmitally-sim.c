/* Host oracle for #123 nmitally — ground truth for the differential gate. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/nmitally.h"

int main(void) {
    printf("nmitally gate_crc = 0x%04X (ticks=%u)\n",
           nmitally_gate_crc(), (unsigned)NMITALLY_TICKS);
    return 0;
}
