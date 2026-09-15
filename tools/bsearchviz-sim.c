/* Host oracle for #147 bsearchviz (Round 8 Cluster B). */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/bsearchviz.h"

int main(void) {
    uint16_t h = bsearchviz_gate_crc();
    printf("bsearchviz keys=%u queries=%u hits=%u misses=%u cmp_calls=%u bad_index=%u probe_sig=0x%04X\n",
           (unsigned)BS_N, (unsigned)BS_Q, (unsigned)bs_hits, (unsigned)bs_misses,
           (unsigned)bs_calls, (unsigned)bs_verify_indices(), bs_probe_sig());
    printf("bsearchviz gate_crc = 0x%04X\n", h);
    return 0;
}
