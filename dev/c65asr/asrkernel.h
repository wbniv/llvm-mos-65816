// asrkernel.h — arithmetic-right-shift kernel, shared by the host oracle and the
// 65CE02 target build, for validating llvm-mos PR #585 (G_ASHRE / native ASR).
//
// #585 makes a one-bit arithmetic right shift select the native 65CE02 `asr`
// when the result is live. Nothing in our SNES battery can execute 65CE02 code,
// so this kernel is the executable check: it folds a large number of signed
// right shifts — every width, every shift amount, both signs, and the
// carry-chained multi-byte forms — into one 16-bit checksum that a wrong sign
// fill, a wrong carry chain, or a dropped bit all perturb.
//
// WIDTH DISCIPLINE: everything is explicitly sized; no bare int arithmetic that
// could differ between the 16-bit target int and the host's 32-bit int.

#ifndef ASRKERNEL_H
#define ASRKERNEL_H

#include <stdint.h>

static inline uint16_t ak_fold(uint16_t acc, uint16_t v) {
    // rotate-left-1 then xor: order-sensitive, so a permuted result diverges too
    acc = (uint16_t)(((uint16_t)(acc << 1)) | (uint16_t)((acc >> 15) & 1u));
    return (uint16_t)(acc ^ v);
}

static uint16_t asr_kernel(void) {
    uint16_t acc = (uint16_t)0xACE1u;
    uint16_t i;
    uint8_t s;

    // --- 8-bit signed, every shift amount, across the full value range ------
    for (i = (uint16_t)0u; i < (uint16_t)256u; i++) {
        int8_t v = (int8_t)(uint8_t)i;
        for (s = (uint8_t)0u; s < (uint8_t)8u; s++) {
            int8_t r = (int8_t)(v >> s);
            acc = ak_fold(acc, (uint16_t)(uint8_t)r);
        }
    }

    // --- 16-bit signed, every shift amount, over a strided value sweep ------
    for (i = (uint16_t)0u; i < (uint16_t)512u; i++) {
        int16_t v = (int16_t)(uint16_t)(i * (uint16_t)127u + (uint16_t)0x8001u);
        for (s = (uint8_t)0u; s < (uint8_t)16u; s++) {
            int16_t r = (int16_t)(v >> s);
            acc = ak_fold(acc, (uint16_t)r);
        }
    }

    // --- 32-bit signed: the multi-byte carry chain, where only the top byte
    //     takes G_ASHRE and the lower three take G_LSHRE ---------------------
    for (i = (uint16_t)0u; i < (uint16_t)256u; i++) {
        int32_t v = (int32_t)((uint32_t)i * (uint32_t)0x00FEDC01u + (uint32_t)0x80000001u);
        for (s = (uint8_t)0u; s < (uint8_t)32u; s++) {
            int32_t r = (int32_t)(v >> s);
            acc = ak_fold(acc, (uint16_t)(uint32_t)r);
            acc = ak_fold(acc, (uint16_t)((uint32_t)r >> 16));
        }
    }

    // --- the store-folded / dead-result shapes #585 routes down the ROR RMW
    //     path rather than native ASR -------------------------------------
    {
        static int16_t g16;
        static int8_t  g8;
        for (i = (uint16_t)0u; i < (uint16_t)64u; i++) {
            g16 = (int16_t)(uint16_t)(i * (uint16_t)1031u + (uint16_t)0x9000u);
            g16 = (int16_t)(g16 >> 1);
            g16 = (int16_t)(g16 >> 1);
            g8  = (int8_t)(uint8_t)(i * (uint8_t)7u + (uint8_t)0x80u);
            g8  = (int8_t)(g8 >> 1);
            acc = ak_fold(acc, (uint16_t)g16);
            acc = ak_fold(acc, (uint16_t)(uint8_t)g8);
        }
    }

    // --- signed bitfield read-back (G_SEXT_INREG -> shl/ashr pair), the shape
    //     that exposed the getDemandedBits regression ----------------------
    {
        struct { int16_t a : 5, b : 4, c : 4; uint16_t d : 3; } bf;
        for (i = (uint16_t)0u; i < (uint16_t)256u; i++) {
            bf.a = (int16_t)(i & (uint16_t)31u);
            bf.b = (int16_t)((i >> 2) & (uint16_t)15u);
            bf.c = (int16_t)((i >> 4) & (uint16_t)15u);
            bf.d = (uint16_t)(i & (uint16_t)7u);
            bf.c = (int16_t)((int16_t)(bf.c + bf.b) >> 1);
            acc = ak_fold(acc, (uint16_t)bf.a);
            acc = ak_fold(acc, (uint16_t)bf.b);
            acc = ak_fold(acc, (uint16_t)bf.c);
            acc = ak_fold(acc, (uint16_t)bf.d);
        }
    }

    return acc;
}

#endif
