/* Host oracle for #149 packrec (Round 8 Cluster B). */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/packrec.h"

int main(void) {
    uint16_t h = packrec_gate_crc();
    printf("packrec bytes=%u records=%u shapeA=%u shapeB=%u odd_wide_reads=%u check=%lu\n",
           (unsigned)PK_BYTES, (unsigned)pk_n, (unsigned)pk_na, (unsigned)pk_nb,
           (unsigned)pk_odd_wide_reads(), (unsigned long)pk_check);
    printf("packrec sizeof PkA=%u PkB=%u (packed) / %u %u (plain)\n",
           (unsigned)sizeof(struct PkA), (unsigned)sizeof(struct PkB),
           (unsigned)sizeof(struct PkAPlain), (unsigned)sizeof(struct PkBPlain));
    printf("packrec gate_crc = 0x%04X\n", h);
    return 0;
}
