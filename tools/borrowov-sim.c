#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/borrowov.h"

int main(void) {
    uint16_t h = borrowov_gate_crc();
    printf("borrowov ticks=%u u16 acc/rej=%u/%u  s16 acc/rej=%u/%u  s32 acc/rej=%u/%u  rejects=%u\n",
           (unsigned)BO_TICKS,
           (unsigned)bo_accept_u, (unsigned)bo_reject_u,
           (unsigned)bo_accept_s, (unsigned)bo_reject_s,
           (unsigned)bo_accept_l, (unsigned)bo_reject_l,
           (unsigned)bo_rejects());
    printf("borrowov gate_crc = 0x%04X\n", h);
    return 0;
}
