/* Host oracle for the Barnes-Hut quadtree gate.
 * Build: cc -O2 -I examples/65816 tools/bhut-sim.c -o build/bhut-sim
 */
#include <stdio.h>
#include "bhut.h"

int main(void) {
    uint16_t h = bh_gate_crc();
    printf("bhut gate  N=%u particles  %u steps  hash=0x%04X\n",
           (unsigned)BH_N, (unsigned)BH_GATE_STEPS, (unsigned)h);
    /* Also print final positions for sanity check */
    bh_init();
    for (int s = 0; s < BH_GATE_STEPS; s++) bh_step();
    printf("Final positions:\n");
    for (int i = 0; i < BH_N; i++)
        printf("  par[%d] = (%d, %d)\n", i, (int)bh_par[i].x, (int)bh_par[i].y);
    return 0;
}
