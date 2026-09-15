#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/retryjmp.h"

int main(void) {
    uint16_t h = retryjmp_gate_crc();
    printf("retryjmp attempts=%u wins=%u calls=%u\n",
           (unsigned)RJ_ATTEMPTS, (unsigned)rj_wins, (unsigned)rj_calls);
    for (unsigned i = 0; i < RJ_ATTEMPTS; i++)
        printf("  attempt %2u code=%3u deepest=%u result=0x%04X\n",
               i, (unsigned)rj_code[i], (unsigned)rj_depth[i], (unsigned)rj_result[i]);
    printf("retryjmp gate_crc = 0x%04X\n", h);
    return 0;
}
