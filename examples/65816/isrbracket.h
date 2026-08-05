// Mid-Bracket Interrupt Torture (#124) — deterministic shared model.
#ifndef ISRBRACKET_H
#define ISRBRACKET_H

#include <stdint.h>

#define ISRBRACKET_FRAMES 1024u

static inline uint32_t isrbracket_irq_step(uint32_t v, uint16_t frame) {
    v ^= (uint32_t)frame * UINT32_C(0x00010001);
    return (v << 5) | (v >> 27);
}

static inline uint16_t isrbracket_fold(uint16_t h, uint8_t v) {
    return (uint16_t)(((h << 3) | (h >> 13)) ^ v);
}

static uint16_t isrbracket_expected(void) {
    uint32_t mix = UINT32_C(0x1240A16F);
    for (uint16_t i=1u; i<=ISRBRACKET_FRAMES; i++) mix=isrbracket_irq_step(mix,i);
    uint16_t h=UINT16_C(0xB124);
    h=isrbracket_fold(h,(uint8_t)ISRBRACKET_FRAMES);
    h=isrbracket_fold(h,(uint8_t)(ISRBRACKET_FRAMES>>8));
    h=isrbracket_fold(h,(uint8_t)mix); h=isrbracket_fold(h,(uint8_t)(mix>>8));
    h=isrbracket_fold(h,(uint8_t)(mix>>16)); h=isrbracket_fold(h,(uint8_t)(mix>>24));
    h=isrbracket_fold(h,0u); h=isrbracket_fold(h,0u); // expected mismatch count
    return h;
}

#endif
