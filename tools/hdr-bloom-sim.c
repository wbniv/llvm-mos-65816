#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/hdr_bloom.h"

int main(void) {
    bloom_state s;
    bloom_init(&s);
    for (uint16_t t = 0; t < GATE_STEPS; t++) { bloom_step(&s); bloom_count_clamped(&s); }
    printf("hdr-bloom: %u cells clamped after %u steps (of %u)\n",
           (unsigned)s.clamped, (unsigned)GATE_STEPS, (unsigned)BLOOM_N);
    printf("hdr-bloom gate_crc = 0x%04X\n", hdr_bloom_gate_crc());
    return 0;
}
