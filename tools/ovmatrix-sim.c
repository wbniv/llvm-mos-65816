/* Host oracle for #155 ovmatrix (Round 8 Cluster C). */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/ovmatrix.h"

int main(void) {
    uint16_t h = ovmatrix_gate_crc();
    static const char *fam[3] = { "add", "sub", "mul" };
    static const unsigned wid[3] = { 16u, 32u, 64u };
    printf("ovmatrix steps=%u cells=%u two_sided_cells=%u\n",
           (unsigned)OV_STEPS, (unsigned)OV_CELLS, (unsigned)ov_two_sided_cells());
    for (unsigned f = 0; f < 3; f++)
        for (unsigned w = 0; w < 3; w++)
            for (unsigned s = 0; s < 2; s++) {
                unsigned c = OV_IDX(f, w, s);
                printf("ovmatrix cell %-3s %c%-2u  overflow=%-4u clean=%-4u\n",
                       fam[f], s ? 'i' : 'u', wid[w],
                       (unsigned)ov_fire[c], (unsigned)ov_clean[c]);
            }
    printf("ovmatrix gate_crc = 0x%04X\n", h);
    return 0;
}
