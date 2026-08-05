#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/dpbank.h"

int main(void) {
    uint32_t mix;
    uint16_t decoy;
    uint16_t crc = dpbank_model(&mix, &decoy);
    printf("dpbank gate_crc = 0x%04X tally=%u hits_d=%u hits_b=%u mix=0x%08lX decoy_sum=0x%04X\n",
           crc, (unsigned)DPBANK_NMI_STOP, (unsigned)DPBANK_WINDOW_ITERS,
           (unsigned)DPBANK_WINDOW_ITERS, (unsigned long)mix, (unsigned)decoy);
    return 0;
}
