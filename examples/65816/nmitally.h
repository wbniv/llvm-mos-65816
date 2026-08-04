// VBlank Interrupt Tally (#123) — shared deterministic model.
#ifndef NMITALLY_H
#define NMITALLY_H

#include <stdint.h>

#define NMITALLY_FRAMES 120u

static inline uint32_t nmitally_step32(uint32_t v, uint16_t frame) {
    return (uint32_t)(v + (uint32_t)0x00010001u + (uint32_t)frame);
}

static inline uint16_t nmitally_fold(uint16_t h, uint8_t v) {
    return (uint16_t)((uint16_t)((h << 5) | (h >> 11)) ^ (uint16_t)v);
}

static uint16_t nmitally_model(uint16_t frames, uint32_t *wide_out) {
    uint16_t tally = 0u;
    uint32_t wide = (uint32_t)0x13579BDFu;
    for (uint16_t frame = 1u; frame <= frames; frame++) {
        tally = (uint16_t)(tally + 1u);
        wide = nmitally_step32(wide, frame);
    }
    uint16_t h = (uint16_t)0x4E4Du;
    h = nmitally_fold(h, (uint8_t)tally);
    h = nmitally_fold(h, (uint8_t)(tally >> 8));
    h = nmitally_fold(h, (uint8_t)wide);
    h = nmitally_fold(h, (uint8_t)(wide >> 8));
    h = nmitally_fold(h, (uint8_t)(wide >> 16));
    h = nmitally_fold(h, (uint8_t)(wide >> 24));
    if (wide_out) *wide_out = wide;
    return h;
}

#endif
