/* Host oracle for #154 byvaledge (Round 8 Cluster C). */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/byvaledge.h"

int main(void) {
    uint16_t h = byvaledge_gate_crc();
    printf("byvaledge steps=%u byval_violations=%u\n",
           (unsigned)bv_n, (unsigned)bv_violations());
    printf("byvaledge host sizeof BvR32=%u BvR33=%u BvR40=%u (MOS: 4 / 5 / 5)\n",
           (unsigned)sizeof(BvR32), (unsigned)sizeof(BvR33), (unsigned)sizeof(BvR40));
    printf("byvaledge gate_crc = 0x%04X\n", h);
    return 0;
}
