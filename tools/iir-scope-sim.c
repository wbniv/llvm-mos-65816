#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/iir_scope.h"

int main(void) {
    iir_state s;
    iir_init(&s);
    int16_t peak = 0;
    for (uint16_t n = 0; n < GATE_SAMPLES; n++) {
        int16_t y = iir_sample(&s);
        int16_t a = y < 0 ? (int16_t)-y : y;
        if (a > peak) peak = a;
    }
    printf("iir-scope: peak |y| = %d over %u samples\n", peak, (unsigned)GATE_SAMPLES);
    printf("iir-scope gate_crc = 0x%04X\n", iir_scope_gate_crc());
    return 0;
}
