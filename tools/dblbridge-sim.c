/* Host oracle for #146 dblbridge (Round 8 Cluster B).
   MUST be compiled with -ffp-contract=off: GCC at -O2 defaults to -ffp-contract=fast and will
   fuse a*b + c ACROSS statements, and MOS has no FMA — a contracted host would silently
   disagree with the target. (The header also writes every operation as its own statement, so
   there is nothing to contract; the flag is the second belt.) */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/dblbridge.h"

int main(void) {
    uint16_t h = dblbridge_gate_crc();
    printf("dblbridge orbits=%u steps=%u promotions=%u div_min=%u div_max=%u\n",
           (unsigned)DB_ORB, (unsigned)DB_STEPS, (unsigned)db_ext_steps,
           (unsigned)db_div_min(), (unsigned)db_div_max());
    for (uint8_t o = 0; o < (uint8_t)DB_ORB; o++)
        printf("  orbit %u: diverges at step %u, %u of %u steps differ\n",
               (unsigned)o, (unsigned)db_div[o], (unsigned)db_dis[o], (unsigned)DB_STEPS);
    printf("dblbridge gate_crc = 0x%04X\n", h);
    return 0;
}
