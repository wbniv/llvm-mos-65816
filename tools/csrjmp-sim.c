#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/csrjmp.h"

int main(void) {
    uint16_t h = csrjmp_gate_crc();
    printf("csrjmp passes=%u coefs=%u burns=%u sink=0x%04X\n",
           (unsigned)CJ_PASSES, (unsigned)CJ_NCOEF, (unsigned)cj_burns, (unsigned)cj_sink);
    for (unsigned p = 0; p < CJ_PASSES; p++) {
        printf("  pass %u rv=%u coef", p, (unsigned)cj_rv[p]);
        for (unsigned i = 0; i < CJ_NCOEF; i++) printf(" %02X", (unsigned)cj_obs[p][i]);
        printf("\n");
    }
    printf("csrjmp gate_crc = 0x%04X\n", h);
    return 0;
}
