// Seismograph Absolute Trace (#121) — signed 64-bit absolute value across limb seams.
#ifndef LLABS64_H
#define LLABS64_H

#include <stdint.h>

extern long long llabs(long long);

#define LLABS64_STEPS 128u

static int64_t llabs64_input;
static int64_t llabs64_libc_out;
static int64_t llabs64_idiom_out;

__attribute__((noinline)) static int64_t llabs64_via_libc(int64_t x) {
    return (int64_t)llabs((long long)x);
}

__attribute__((noinline)) static int64_t llabs64_via_idiom(int64_t x) {
    return x < 0 ? -x : x;
}

static int64_t llabs64_sample(uint16_t step) {
    static const int64_t samples[16] = {
        INT64_C(0), INT64_C(1), -INT64_C(1), INT64_C(0x7FFF),
        -INT64_C(0x8001), INT64_C(0xFFFF), -INT64_C(0x10001), INT64_C(0x7FFFFFFF),
        -INT64_C(0x80000000), INT64_C(0x100000001), -INT64_C(0x100010001),
        INT64_C(0x0001000100010001), -INT64_C(0x0001000100010001),
        INT64_MAX, INT64_MIN + INT64_C(1), -INT64_C(0x4000000100010001)
    };
    int64_t x = samples[step & 15u];
    uint64_t wobble = (uint64_t)(step >> 4) * UINT64_C(0x0000000100010001);
    return x >= 0 ? (int64_t)((uint64_t)x ^ wobble) : -(int64_t)(((uint64_t)(-x)) ^ wobble);
}

static uint16_t llabs64_fold(uint16_t h, uint64_t v) {
    for (uint8_t i = 0; i < 4u; i++) {
        h = (uint16_t)((h << 5) | (h >> 11));
        h ^= (uint16_t)v;
        v >>= 16;
    }
    return h;
}

__attribute__((noinline)) static uint16_t llabs64_step(uint16_t h, uint16_t step) {
    llabs64_input = llabs64_sample(step);
    llabs64_libc_out = llabs64_via_libc(llabs64_input);
    llabs64_idiom_out = llabs64_via_idiom(llabs64_input);
    h = llabs64_fold(h, (uint64_t)llabs64_input);
    h = llabs64_fold(h, (uint64_t)llabs64_libc_out);
    h = llabs64_fold(h, (uint64_t)llabs64_idiom_out);
    return (uint16_t)(h ^ (llabs64_libc_out == llabs64_idiom_out ? UINT16_C(0xA641) : UINT16_C(0xDEAD)));
}

static uint16_t llabs64_model(void) {
    uint16_t h = UINT16_C(0x1217);
    for (uint16_t i = 0; i < LLABS64_STEPS; i++) h = llabs64_step(h, i);
    return h;
}

#endif
