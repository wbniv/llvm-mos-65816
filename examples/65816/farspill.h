// Far-Spill Stress (#131) — many derived far pointers live across a clobbering call.
#ifndef FARSPILL_H
#define FARSPILL_H

#include <stdint.h>

#define FARSPILL_PTRS 10u
#define FARSPILL_ROUNDS 96u

static uint8_t farspill_samples[FARSPILL_PTRS];
static volatile uint32_t farspill_noise = 0x6D2B79F5u;

__attribute__((noinline))
static uint32_t farspill_clobber(uint32_t x, uint16_t round) {
    x ^= farspill_noise;
    x ^= (uint32_t)round * 0x9E37u;
    x = x * 1664525u + 1013904223u;
    farspill_noise = (x << 7) | (x >> 25);
    return farspill_noise;
}

static uint16_t farspill_fold(uint16_t h, uint8_t v, uint8_t lane) {
    h = (uint16_t)((h << 3) | (h >> 13));
    return (uint16_t)(h ^ (uint16_t)v ^ (uint16_t)((uint16_t)lane * 0x111u));
}

#if defined(__mos__)
#define FAR __attribute__((address_space(2)))

extern const uint8_t farspill_data[];
static volatile uint32_t farspill_opaque[FARSPILL_PTRS];

__attribute__((noinline))
static uint16_t farspill_round(uint16_t h, uint16_t round) {
    uint32_t base = ((uint32_t)1u << 16) | (uint16_t)(uintptr_t)&farspill_data;
    for (uint8_t i = 0; i < FARSPILL_PTRS; i++)
        farspill_opaque[i] = base + (uint32_t)((round * 7u + i * 5u) & 63u);

    // Each volatile load is single-use and non-rematerializable. All ten converted far pointers
    // become live before the call and are consumed only afterward, exceeding the available Imag32
    // quads and forcing several complete four-byte spill/reload cycles.
    FAR const uint8_t *p0 = (FAR const uint8_t *)farspill_opaque[0];
    FAR const uint8_t *p1 = (FAR const uint8_t *)farspill_opaque[1];
    FAR const uint8_t *p2 = (FAR const uint8_t *)farspill_opaque[2];
    FAR const uint8_t *p3 = (FAR const uint8_t *)farspill_opaque[3];
    FAR const uint8_t *p4 = (FAR const uint8_t *)farspill_opaque[4];
    FAR const uint8_t *p5 = (FAR const uint8_t *)farspill_opaque[5];
    FAR const uint8_t *p6 = (FAR const uint8_t *)farspill_opaque[6];
    FAR const uint8_t *p7 = (FAR const uint8_t *)farspill_opaque[7];
    FAR const uint8_t *p8 = (FAR const uint8_t *)farspill_opaque[8];
    FAR const uint8_t *p9 = (FAR const uint8_t *)farspill_opaque[9];

    uint32_t noise = farspill_clobber((uint32_t)h | ((uint32_t)round << 16), round);
    h ^= (uint16_t)noise ^ (uint16_t)(noise >> 16);

#define FARSPILL_USE(N) do { farspill_samples[N] = *p##N; h = farspill_fold(h, farspill_samples[N], N); } while (0)
    FARSPILL_USE(0); FARSPILL_USE(1); FARSPILL_USE(2); FARSPILL_USE(3); FARSPILL_USE(4);
    FARSPILL_USE(5); FARSPILL_USE(6); FARSPILL_USE(7); FARSPILL_USE(8); FARSPILL_USE(9);
#undef FARSPILL_USE
    return h;
}

#else

static uint8_t farspill_value(uint16_t round, uint8_t lane) {
    uint8_t index = (uint8_t)((round * 7u + lane * 5u) & 63u);
    return (uint8_t)(index * 37u + 11u);
}

static uint16_t farspill_round(uint16_t h, uint16_t round) {
    uint32_t noise = farspill_clobber((uint32_t)h | ((uint32_t)round << 16), round);
    h ^= (uint16_t)noise ^ (uint16_t)(noise >> 16);
    for (uint8_t i = 0; i < FARSPILL_PTRS; i++) {
        farspill_samples[i] = farspill_value(round, i);
        h = farspill_fold(h, farspill_samples[i], i);
    }
    return h;
}

#endif

static uint16_t farspill_model(void) {
    uint16_t h = 0xF131u;
    for (uint16_t round = 0; round < FARSPILL_ROUNDS; round++)
        h = farspill_round(h, round);
    return h;
}

#endif
