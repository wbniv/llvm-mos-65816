// Limb-Seam Barrel (#138) — runtime s64 shifts across 16/32-bit limb boundaries.
#ifndef SHIFT64SEAM_H
#define SHIFT64SEAM_H

#include <stdint.h>

#define SHIFT64SEAM_STEPS 96u

static volatile uint64_t shift64seam_count;
static uint64_t shift64seam_left_out;
static uint64_t shift64seam_right_out;
static int64_t shift64seam_arith_out;

__attribute__((noinline)) static uint64_t shift64seam_left(uint64_t x, uint64_t count) {
    return x << count;
}

__attribute__((noinline)) static uint64_t shift64seam_right(uint64_t x, uint64_t count) {
    return x >> count;
}

__attribute__((noinline)) static int64_t shift64seam_arith(int64_t x, uint64_t count) {
    return x >> count;
}

static uint8_t shift64seam_amount(uint16_t step) {
    static const uint8_t counts[16] = {
        0u,1u,7u,15u,16u,17u,23u,31u,32u,33u,39u,47u,48u,49u,62u,63u
    };
    return counts[step & 15u];
}

static uint16_t shift64seam_fold64(uint16_t h, uint64_t v) {
    for (uint8_t i=0; i<4u; i++) {
        h=(uint16_t)((h<<3)|(h>>13));
        h^=(uint16_t)v;
        v>>=16;
    }
    return h;
}

__attribute__((noinline)) static uint16_t shift64seam_step(uint16_t h, uint16_t step) {
    uint8_t c8=shift64seam_amount(step);
    shift64seam_count=(uint64_t)c8; // Explicitly widened: avoids the known G_ANYEXT s8->s64 gap.
    uint64_t c=shift64seam_count;
    uint64_t u=UINT64_C(0xD3A5C96E7812B40F) ^ ((uint64_t)step*UINT64_C(0x0101010101010101));
    int64_t s=(int64_t)(u|UINT64_C(0x8000000000000000));
    shift64seam_left_out=shift64seam_left(u,c);
    shift64seam_right_out=shift64seam_right(u,c);
    shift64seam_arith_out=shift64seam_arith(s,c);
    h=shift64seam_fold64(h,shift64seam_left_out);
    h=shift64seam_fold64(h,shift64seam_right_out);
    h=shift64seam_fold64(h,(uint64_t)shift64seam_arith_out);
    return (uint16_t)(h^c8);
}

static uint16_t shift64seam_model(void) {
    uint16_t h=0x8138u;
    for (uint16_t i=0;i<SHIFT64SEAM_STEPS;i++) h=shift64seam_step(h,i);
    return h;
}

#endif
