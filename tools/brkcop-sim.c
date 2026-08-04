#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/brkcop.h"

int main(void) {
    uint16_t brk_hits, cop_hits, sent;
    uint16_t crc = brkcop_model(&brk_hits, &cop_hits, &sent);
    printf("brkcop gate_crc = 0x%04X brk=%u cop=%u sent=0x%04X\n",
           crc, (unsigned)brk_hits, (unsigned)cop_hits, (unsigned)sent);
    return 0;
}
