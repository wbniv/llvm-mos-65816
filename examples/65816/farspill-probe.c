#include "farspill.h"

__attribute__((section(".far_rodata")))
const uint8_t farspill_data[64] = {
     11,  48,  85, 122, 159, 196, 233,  14,  51,  88, 125, 162, 199, 236,  17,  54,
     91, 128, 165, 202, 239,  20,  57,  94, 131, 168, 205, 242,  23,  60,  97, 134,
    171, 208, 245,  26,  63, 100, 137, 174, 211, 248,  29,  66, 103, 140, 177, 214,
    251,  32,  69, 106, 143, 180, 217, 254,  35,  72, 109, 146, 183, 220,   1,  38
};

volatile uint16_t farspill_probe_result;

void farspill_probe(void) {
    farspill_probe_result = farspill_round(0x5311u, 17u);
}
