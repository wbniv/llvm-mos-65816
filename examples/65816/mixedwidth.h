// Split-Personality Link (#126) — per-function native/default width boundaries.
#ifndef MIXEDWIDTH_H
#define MIXEDWIDTH_H

#include <stdint.h>

#if defined(__mos__)
#define MW_NOINLINE __attribute__((noinline))
#define MW_NATIVE __attribute__((noinline, target("mos-a16")))
#define MW_BYTE __attribute__((noinline, target("no-mos-a16,no-mos-xy16")))
#else
#define MW_NOINLINE
#define MW_NATIVE
#define MW_BYTE
#endif

#define MIXEDWIDTH_STEPS 192u

static MW_NATIVE uint16_t mw_native(uint16_t x, uint16_t k) {
    x = (uint16_t)(x + k);
    x = (uint16_t)((x << 5) | (x >> 11));
    x ^= (uint16_t)0xA5C3u;
    x = (uint16_t)(x + (uint16_t)(k * 3u + 1u));
    return x;
}

static MW_BYTE uint16_t mw_byte(uint16_t x, uint8_t k) {
    uint8_t lo = (uint8_t)x;
    uint8_t hi = (uint8_t)(x >> 8);
    lo = (uint8_t)((uint8_t)(lo + k) ^ (uint8_t)(hi >> 1));
    hi = (uint8_t)((uint8_t)(hi + 0x3Du) ^ (uint8_t)(lo << 1));
    return (uint16_t)((uint16_t)lo | ((uint16_t)hi << 8));
}

static MW_NOINLINE uint16_t mw_default_bridge(uint16_t x, uint16_t k) {
    return mw_byte(mw_native(x, k), (uint8_t)k);
}

static uint16_t mixedwidth_model(void) {
    uint16_t x = (uint16_t)0x1357u;
    uint16_t h = (uint16_t)0x4D57u;
    for (uint16_t i = 1u; i <= (uint16_t)MIXEDWIDTH_STEPS; i++) {
        x = mw_default_bridge(x, i);
        h = (uint16_t)((uint16_t)((h << 3) | (h >> 13)) ^ x ^ i);
    }
    return h;
}

#endif
