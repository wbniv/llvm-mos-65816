/* Host oracle for #148 strcmprace (Round 8 Cluster B). */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/strcmprace.h"

int main(void) {
    static const char *nm[3] = { "strcmp", "strncmp", "memcmp" };
    uint16_t h = strcmprace_gate_crc();
    printf("strcmprace lanes=%u width=%u comparisons=%u uncovered_cells=%u\n",
           (unsigned)SR_N, (unsigned)SR_W, (unsigned)sr_nlog, (unsigned)sr_uncovered());
    for (int f = 0; f < 3; f++)
        printf("  %-8s neg=%u zero=%u pos=%u\n", nm[f],
               (unsigned)sr_cnt[f][0], (unsigned)sr_cnt[f][1], (unsigned)sr_cnt[f][2]);
    printf("strcmprace gate_crc = 0x%04X\n", h);
    return 0;
}
