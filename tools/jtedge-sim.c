/* Host oracle for #152 jtedge (Round 8 Cluster C). */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/jtedge.h"

int main(void) {
    uint16_t h = jtedge_gate_crc();
    printf("jtedge steps=%u disagreements=%u default_arm_hits=%u plotted=%u\n",
           (unsigned)JE_STEPS, (unsigned)je_disagreements(), (unsigned)je_misses(),
           (unsigned)je_nplot);
    printf("jtedge acc127=%u acc128=%u acc129=%u\n",
           (unsigned)je_vm[0].acc, (unsigned)je_vm[1].acc, (unsigned)je_vm[2].acc);
    printf("jtedge gate_crc = 0x%04X\n", h);
    return 0;
}
