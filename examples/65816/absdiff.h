// Motion-Detect Difference Field (#119) — absolute-difference combiner coverage.
#ifndef ABSDIFF_H
#define ABSDIFF_H

#include <stdint.h>

#define ABSDIFF_STEPS 192u

__attribute__((noinline))
static uint8_t absdiff_u8(uint8_t a, uint8_t b) {
    return a > b ? (uint8_t)(a - b) : (uint8_t)(b - a);
}

__attribute__((noinline))
static uint16_t absdiff_s16(int16_t a, int16_t b) {
    // Callers keep both operands in [-16384,16383], so both subtractions are defined.
    return (uint16_t)(a > b ? (int16_t)(a - b) : (int16_t)(b - a));
}

__attribute__((noinline))
static uint32_t absdiff_u32(uint32_t a, uint32_t b) {
    return a > b ? a - b : b - a;
}

static uint16_t absdiff_crc_step(uint16_t h, uint8_t d8, uint16_t d16, uint32_t d32) {
    h = (uint16_t)((h << 5) | (h >> 11));
    h ^= (uint16_t)d8;
    h = (uint16_t)(h + d16 + (uint16_t)d32 + (uint16_t)(d32 >> 16));
    return (uint16_t)(h ^ (uint16_t)(h >> 7));
}

static uint16_t absdiff_model(void) {
    uint16_t h = (uint16_t)0xA119u;
    for (uint16_t i = 0; i < (uint16_t)ABSDIFF_STEPS; i++) {
        uint8_t a8 = (uint8_t)(i * 29u + (i >> 2));
        uint8_t b8 = (uint8_t)(i * 11u + 0x5Du);
        int16_t a16 = (int16_t)((int16_t)((i * 173u) & 0x3FFFu) - 8192);
        int16_t b16 = (int16_t)((int16_t)((i * 97u + 0x1555u) & 0x3FFFu) - 8192);
        uint32_t a32 = (uint32_t)i * 2654435761u + (uint32_t)0x10203040u;
        uint32_t b32 = (uint32_t)i * 2246822519u + (uint32_t)0x89ABCDEFu;
        h = absdiff_crc_step(h, absdiff_u8(a8, b8), absdiff_s16(a16, b16),
                             absdiff_u32(a32, b32));
    }
    return h;
}

#endif
