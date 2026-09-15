#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/bigbyval.h"

int main(void) {
    uint16_t h = bigbyval_gate_crc();
    printf("bigbyval stages=%u verts=%u mat_bits=%u vert_bits=%u mutations=%u copy_violations=%u\n",
           (unsigned)BV_STAGES, (unsigned)BV_VERTS,
           (unsigned)(sizeof(BvMat) * 8u), (unsigned)(sizeof(BvVert) * 8u),
           (unsigned)bv_mutations, (unsigned)bv_copy_violations());
    printf("bigbyval gate_crc = 0x%04X\n", h);
    return 0;
}
