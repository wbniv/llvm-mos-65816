/* Host oracle for #150 trapguard (Round 8 Cluster B). */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/trapguard.h"

int main(void) {
    uint16_t h = trapguard_gate_crc();
    printf("trapguard ticks=%u trace=%u guarded=%u legal_unvisited=%u illegal_taken=%u acc=0x%04X\n",
           (unsigned)TG_TICKS, (unsigned)tg_ntrace, (unsigned)tg_guarded,
           (unsigned)tg_legal_unvisited(), (unsigned)tg_illegal_taken(), tg_acc);
    printf("trapguard gate_crc = 0x%04X\n", h);
    return 0;
}
