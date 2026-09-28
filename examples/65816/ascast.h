#ifndef ASCAST_H
#define ASCAST_H

#include <stdint.h>

#ifdef __mos__
#define AS_FAR __attribute__((address_space(2)))
#else
#define AS_FAR
#endif

static const uint8_t ac_data[16] = {
    0x13u, 0x27u, 0x3Bu, 0x4Fu, 0x52u, 0x66u, 0x7Au, 0x8Eu,
    0x91u, 0xA5u, 0xB9u, 0xCDu, 0xD0u, 0xE4u, 0xF8u, 0x0Cu
};
static volatile uintptr_t ac_opaque;

__attribute__((noinline)) static AS_FAR const uint8_t *ac_to_far(const uint8_t *p) {
    return (AS_FAR const uint8_t *)p;
}

__attribute__((noinline)) static const uint8_t *ac_to_near(AS_FAR const uint8_t *p) {
    return (const uint8_t *)p;
}

__attribute__((noinline)) static uint8_t ac_read(uintptr_t address) {
    const uint8_t *near_p = (const uint8_t *)address;
    AS_FAR const uint8_t *far_p = ac_to_far(near_p);
    const uint8_t *near_again = ac_to_near(far_p);
    AS_FAR const uint8_t *far_again = ac_to_far(near_again);
    return *far_again;
}

static uint16_t ascast_gate_crc(void) {
    ac_opaque = (uintptr_t)&ac_data[0];
    uint16_t h = 0x2D61u;
    for (uint8_t i = 0; i < 16u; i++) {
        uintptr_t address = ac_opaque + i;
        h = (uint16_t)((h << 1) | (h >> 15)) ^ ac_read(address);
    }
    return h;
}

#undef AS_FAR
#endif
