#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/vlastack.h"

int main(void) {
    uint16_t h = vlastack_gate_crc();
    printf("vlastack rows=%u width=%u total_runs=%u runs_min=%u runs_max=%u\n",
           (unsigned)VS_ROWS, (unsigned)VS_W, (unsigned)vs_totalruns,
           (unsigned)vs_min_runs(), (unsigned)vs_max_runs());
    printf("vlastack gate_crc = 0x%04X\n", h);
    return 0;
}
