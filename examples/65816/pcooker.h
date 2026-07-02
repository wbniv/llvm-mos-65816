// Pressure-Cooker Fixed-Point Evaluator (#109) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster E. Re-stresses patch 0011 (scavenger-`$p`): under maximal
// 16-bit-accumulator register pressure the register scavenger routes a live `$p` (the N/Z/carry
// flag processor state) through a dead index register into RC17 — a fix that only matters when a
// **compare's result must stay live across a spill/call**. This evaluator computes one giant
// straight-line 32-bit fixed-point expression per (x,y): it forms a comparison EARLY, then makes
// **several `__mulsi3`/`__divsi3` libcalls** (which clobber the flags + scratch), and only THEN
// consumes the comparison — so the compare's N/Z is forced live across the call-clobbered region
// under a dozen simultaneously-live 32-bit temps. The a16/xy16 legs are the load-bearing ones
// (0011 is accum-gated); default 8-bit is the contrast.
//
// DIFFERENTIAL: signed 32-bit integer arithmetic is exact → bit-identical host vs target. A wrong
// flag-liveness spill flips the select and diverges the field CRC. WIDTH DISCIPLINE: explicit
// int16/int32; no bare int; no float; divisors kept strictly positive (no divide-by-zero). See plan.

#ifndef PCOOKER_H
#define PCOOKER_H

#include <stdint.h>

// One implicit-surface sample. `cond` is computed BEFORE d/e/f/g/h2 (each an __mulsi3/__divsi3),
// then consumed in the final select — the compare-live-across-calls shape 0011 fixed. A dozen
// 32-bit temps (a,b,c,r2,cond,d,e,f,g,h2,base) are simultaneously live → maximal pressure.
__attribute__((noinline))
static int32_t pc_eval(int16_t x, int16_t y, int16_t t) {
    int32_t X = (int32_t)x, Y = (int32_t)y, T = (int32_t)t;
    int32_t a  = (int32_t)(X * X);                          // __mulsi3
    int32_t b  = (int32_t)(Y * Y);                          // __mulsi3
    int32_t c  = (int32_t)(X * Y);                          // __mulsi3
    int32_t r2 = (int32_t)(a + b);
    int cond   = (int)((int32_t)(r2 - (int32_t)4000) > (int32_t)0);   // COMPARE — consumed later
    int32_t d  = (int32_t)((int32_t)(a * (int32_t)7)  / (int32_t)(b + (int32_t)13));   // mul + div
    int32_t e  = (int32_t)((int32_t)(c * (int32_t)5)  / (int32_t)(a + (int32_t)17));   // mul + div
    int32_t f  = (int32_t)((int32_t)(r2 * (int32_t)3) / (int32_t)((int32_t)(T * T) + (int32_t)101)); // mul + div
    int32_t g  = (int32_t)((int32_t)(d + e) * (int32_t)(f + (int32_t)1));              // mul
    int32_t h2 = (int32_t)((int32_t)(g)     / (int32_t)((int32_t)(c * c) + (int32_t)29));            // mul + div
    int32_t base = (int32_t)(d + e + f + g + h2);           // all temps still live here
    return cond ? (int32_t)(base + (int32_t)1000000) : (int32_t)(base - (int32_t)1000000);   // USE cond after the calls
}

// Threshold the sample to a 0..3 colour band (the implicit surface's level set).
static inline uint8_t pc_color(int32_t v) {
    uint32_t u = (uint32_t)v;
    return (uint8_t)((uint8_t)(u >> 18) & 3u);
}

static inline uint16_t pc_fold(uint16_t h, int32_t v) {
    uint32_t u = (uint32_t)v;
    h = (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ (uint16_t)(u & 0xFFFFu));
    h = (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ (uint16_t)(u >> 16));
    return h;
}

// ---------------------------------------------------------------------------------------------
// Differential gate: evaluate the field over a small grid at a few time steps; fold every sample.
// ---------------------------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 3u          // time steps; each does GRID*GRID heavy evals — keep small
#endif
#define PC_GRID 12u

static uint16_t pcooker_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    for (uint16_t step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        int16_t t = (int16_t)((int16_t)step * (int16_t)9 - (int16_t)11);
        for (int16_t y = (int16_t)0; y < (int16_t)PC_GRID; y++)
            for (int16_t x = (int16_t)0; x < (int16_t)PC_GRID; x++) {
                int32_t v = pc_eval((int16_t)((int16_t)(x - (int16_t)6) * (int16_t)11),
                                    (int16_t)((int16_t)(y - (int16_t)6) * (int16_t)11), t);
                h = pc_fold(h, v);
            }
    }
    return h;
}

#define PC_WIN 16u

#endif /* PCOOKER_H */
