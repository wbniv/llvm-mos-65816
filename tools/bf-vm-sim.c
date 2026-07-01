#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/bf_vm.h"

int main(void) {
    /* Show the program output for a human sanity check, then the gate CRC. */
    bf_vm v;
    bf_init(&v, BF_SOURCE);
    while (!v.halted && v.steps < GATE_N) bf_run(&v, 256u);
    fputs("bf output: \"", stdout);
    for (uint16_t i = 0; i < v.out_head && i < BF_OUT_N; i++) {
        uint8_t c = v.out[i];
        if (c == '\n') fputs("\\n", stdout);
        else putchar(c);
    }
    printf("\"  (%u ops, %u bytes)\n", (unsigned)v.steps, (unsigned)v.out_head);
    printf("bf-vm gate_crc = 0x%04X\n", bf_vm_gate_crc());
    return 0;
}
