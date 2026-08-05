#include "absdiff.h"

volatile uint8_t absdiff_probe8a, absdiff_probe8b;
volatile int16_t absdiff_probe16a, absdiff_probe16b;
volatile uint32_t absdiff_probe32a, absdiff_probe32b;

uint32_t absdiff_probe(void) {
    return (uint32_t)absdiff_u8(absdiff_probe8a, absdiff_probe8b)
         ^ ((uint32_t)absdiff_s16(absdiff_probe16a, absdiff_probe16b) << 8)
         ^ absdiff_u32(absdiff_probe32a, absdiff_probe32b);
}
