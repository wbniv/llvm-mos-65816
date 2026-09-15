#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/jt256.h"

int main(void) {
    uint16_t h = jt256_gate_crc();
    printf("jt256 steps=%u plotted=%u handlers_entered=%u/256\n",
           (unsigned)JT_STEPS, (unsigned)jt_nplot, (unsigned)jt256_coverage());
    printf("  regs %04X %04X %04X %04X  acc=%04X\n",
           jt_vm.r[0], jt_vm.r[1], jt_vm.r[2], jt_vm.r[3], jt_vm.acc);
    printf("jt256 gate_crc = 0x%04X\n", h);
    return 0;
}
