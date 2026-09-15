// Callee-Saved Restore Curve (#117) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster G — the CSR-RESTORE-OFFSET guard for the 65816-native
// platforms/snes/setjmp.S fix (bug #35). corpus/setjmp_sim.c jumps with no live callee-saved
// registers at all; #116 backtrack varies the UNWIND DEPTH. This one pins the other axis: the
// 14-byte __rc18..__rc31 callee-saved block that jmp_buf carries as `csrs[14]`.
//
// MECHANISM: CJ_NCOEF (= 14, the width of that block) coefficient BYTES are loaded into locals,
// the setjmp is taken, and a noinline worker keeps 14 of its OWN byte values live across calls —
// so it necessarily occupies every callee-saved slot — then longjmps back, bypassing the epilogue
// that would otherwise restore them. The only path by which the caller's coefficients survive is
// longjmp's own csrs[] restore. An off-by-one in those offsets corrupts exactly ONE coefficient,
// which warps exactly one axis of the rendered curve and diverges the gate CRC.
//
// The coefficients drive a harmonograph: two detuned sine terms per axis under a decaying
// envelope, evaluated through a 32-bit multiply chain (__mulsi3) so the curve is integer-exact.
//
// DIFFERENTIAL: the gate CRC folds the POST-longjmp coefficient vector of every pass, the setjmp
// return value, the worker's scribble accumulator, and every rendered curve sample.
// WIDTH DISCIPLINE: explicit uint8/16/32; no bare int except setjmp's own return value.
// CLOBBER DISCIPLINE: every value that CHANGES between a setjmp and its longjmp is file-scope.
// The 14 coefficient locals are deliberately the exception the C standard permits and this test
// depends on: they are set BEFORE the setjmp and never modified, so the implementation must
// preserve them (C99 7.13.2.1p3 makes only *changed* automatics indeterminate).
// See docs/plans/2026-09-15-116-118-setjmp-cluster-g-demos.md.

#ifndef CSRJMP_H
#define CSRJMP_H

#include <stdint.h>
#include "sjcompat.h"

#define CJ_NCOEF   14u   /* = sizeof(jmp_buf.csrs): __rc18..__rc31 */
#define CJ_PASSES   6u   /* independent coefficient sets           */
#define CJ_NSAMP   48u   /* curve samples folded (and drawn) per pass */

/* 64-entry sine, amplitude +-127. Shift-free index (& 63); integer-exact on host and target. */
static const int8_t cj_sin[64] = {
       0,   12,   25,   37,   49,   60,   71,   81,
      90,   98,  106,  112,  117,  122,  125,  126,
     127,  126,  125,  122,  117,  112,  106,   98,
      90,   81,   71,   60,   49,   37,   25,   12,
       0,  -12,  -25,  -37,  -49,  -60,  -71,  -81,
     -90,  -98, -106, -112, -117, -122, -125, -126,
    -127, -126, -125, -122, -117, -112, -106,  -98,
     -90,  -81,  -71,  -60,  -49,  -37,  -25,  -12,
};

static jmp_buf cj_jb;

static uint8_t  cj_coef[CJ_NCOEF];              /* coefficients loaded before the setjmp */
static uint8_t  cj_seen[CJ_NCOEF];              /* landing slot for the restored locals */
static uint8_t  cj_obs[CJ_PASSES][CJ_NCOEF];    /* the same bytes read back AFTER the longjmp */
static uint8_t  cj_rv[CJ_PASSES];               /* setjmp return value per pass */
static uint8_t  cj_pass;                        /* current pass (file-scope: it changes across jumps) */
static uint16_t cj_sink;                        /* the worker's scribble accumulator */
static uint16_t cj_burns;                       /* calls the worker made before jumping */

/* Deterministic coefficient set: distinct, non-zero, and different in every byte position, so a
   restore that reads one slot too high or low lands on a visibly different value. */
__attribute__((noinline))
static void cj_seed(uint8_t pass) {
    uint16_t s = (uint16_t)((uint16_t)(pass * (uint16_t)2477u) + (uint16_t)0x9E37u);
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)CJ_NCOEF; i++) {
        s = (uint16_t)((uint16_t)(s * (uint16_t)25173u) + (uint16_t)13849u);
        cj_coef[i] = (uint8_t)((uint8_t)(s >> 8) | (uint8_t)1u);   /* never 0 */
    }
}

/* A call the worker's live values must survive — forces them into callee-saved slots. */
__attribute__((noinline))
static uint8_t cj_burn(uint8_t x) {
    cj_burns++;
    return (uint8_t)((uint8_t)((uint8_t)(x * (uint8_t)37u) + (uint8_t)91u) ^ (uint8_t)0x5Au);
}

// The scribbler. 14 byte values simultaneously live ACROSS calls -> every callee-saved slot is
// occupied and rewritten. It never returns: the longjmp bypasses the epilogue that would restore
// the caller's __rc18..__rc31, so only longjmp's own csrs[] copy can recover them.
__attribute__((noinline))
static void cj_worker(uint8_t pass) {
    uint8_t v0  = cj_burn((uint8_t)(pass + (uint8_t)1u));
    uint8_t v1  = cj_burn((uint8_t)(v0  ^ (uint8_t)0x11u));
    uint8_t v2  = cj_burn((uint8_t)(v1  ^ (uint8_t)0x22u));
    uint8_t v3  = cj_burn((uint8_t)(v2  ^ (uint8_t)0x33u));
    uint8_t v4  = cj_burn((uint8_t)(v3  ^ (uint8_t)0x44u));
    uint8_t v5  = cj_burn((uint8_t)(v4  ^ (uint8_t)0x55u));
    uint8_t v6  = cj_burn((uint8_t)(v5  ^ (uint8_t)0x66u));
    uint8_t v7  = cj_burn((uint8_t)(v6  ^ (uint8_t)0x77u));
    uint8_t v8  = cj_burn((uint8_t)(v7  ^ (uint8_t)0x88u));
    uint8_t v9  = cj_burn((uint8_t)(v8  ^ (uint8_t)0x99u));
    uint8_t v10 = cj_burn((uint8_t)(v9  ^ (uint8_t)0xAAu));
    uint8_t v11 = cj_burn((uint8_t)(v10 ^ (uint8_t)0xBBu));
    uint8_t v12 = cj_burn((uint8_t)(v11 ^ (uint8_t)0xCCu));
    uint8_t v13 = cj_burn((uint8_t)(v12 ^ (uint8_t)0xDDu));

    uint16_t acc = (uint16_t)0u;
    for (uint8_t k = (uint8_t)0u; k < (uint8_t)3u; k++) {
        acc = (uint16_t)(acc + (uint16_t)cj_burn((uint8_t)(v0  + k)));
        acc = (uint16_t)(acc ^ (uint16_t)cj_burn((uint8_t)(v1  + k)));
        acc = (uint16_t)(acc + (uint16_t)cj_burn((uint8_t)(v2  + k)));
        acc = (uint16_t)(acc ^ (uint16_t)cj_burn((uint8_t)(v3  + k)));
        acc = (uint16_t)(acc + (uint16_t)cj_burn((uint8_t)(v4  + k)));
        acc = (uint16_t)(acc ^ (uint16_t)cj_burn((uint8_t)(v5  + k)));
        acc = (uint16_t)(acc + (uint16_t)cj_burn((uint8_t)(v6  + k)));
        acc = (uint16_t)(acc ^ (uint16_t)cj_burn((uint8_t)(v7  + k)));
        acc = (uint16_t)(acc + (uint16_t)cj_burn((uint8_t)(v8  + k)));
        acc = (uint16_t)(acc ^ (uint16_t)cj_burn((uint8_t)(v9  + k)));
        acc = (uint16_t)(acc + (uint16_t)cj_burn((uint8_t)(v10 + k)));
        acc = (uint16_t)(acc ^ (uint16_t)cj_burn((uint8_t)(v11 + k)));
        acc = (uint16_t)(acc + (uint16_t)cj_burn((uint8_t)(v12 + k)));
        acc = (uint16_t)(acc ^ (uint16_t)cj_burn((uint8_t)(v13 + k)));
    }
    cj_sink = acc;
    longjmp(cj_jb, (int)((uint8_t)(pass + (uint8_t)1u)));
}

/* One harmonograph sample: two detuned sine terms per axis under a decaying envelope.
   Output is canvas-space (0..127 nominal, clipped by the caller). */
static void cj_point(const uint8_t *c, uint8_t i, int16_t *xo, int16_t *yo) {
    uint8_t t = (uint8_t)((uint8_t)(i * (uint8_t)5u) + c[13]);
    uint8_t env = (uint8_t)(255u - (uint8_t)(((uint16_t)i * (uint16_t)c[12]) >> 7));

    int16_t sx1 = (int16_t)cj_sin[(uint8_t)((uint8_t)((uint8_t)(c[1] & 7u) * t) + c[2]) & 63u];
    int16_t sx2 = (int16_t)cj_sin[(uint8_t)((uint8_t)((uint8_t)(c[4] & 7u) * t) + c[5]) & 63u];
    int16_t sy1 = (int16_t)cj_sin[(uint8_t)((uint8_t)((uint8_t)(c[7] & 7u) * t) + c[8]) & 63u];
    int16_t sy2 = (int16_t)cj_sin[(uint8_t)((uint8_t)((uint8_t)(c[10] & 7u) * t) + c[11]) & 63u];

    int32_t xa = (int32_t)((int32_t)c[0] * (int32_t)sx1 + (int32_t)c[3] * (int32_t)sx2);
    int32_t ya = (int32_t)((int32_t)c[6] * (int32_t)sy1 + (int32_t)c[9] * (int32_t)sy2);
    *xo = (int16_t)((int16_t)64 + (int16_t)((xa * (int32_t)env) >> 18));
    *yo = (int16_t)((int16_t)64 + (int16_t)((ya * (int32_t)env) >> 18));
}

static uint16_t cj_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)((uint16_t)(h * (uint16_t)25173u) + (uint16_t)13849u);
}

/* Copy one pass's landed coefficient bytes into the per-pass record. */
__attribute__((noinline))
static void cj_record(uint8_t rv) {
    cj_rv[cj_pass] = rv;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)CJ_NCOEF; i++) cj_obs[cj_pass][i] = cj_seen[i];
}

// Fold the recorded results. noinline and separate from the setjmp loop deliberately: the loop's
// 14 coefficient locals already own every callee-saved slot, and folding in the same frame piles
// the curve evaluator's own live set on top of them for no added coverage.
__attribute__((noinline))
static uint16_t cj_fold(void) {
    uint16_t h = (uint16_t)0x5A5Au;
    for (uint8_t p = (uint8_t)0u; p < (uint8_t)CJ_PASSES; p++) {
        h = cj_mix(h, (uint16_t)cj_rv[p]);
        for (uint8_t i = (uint8_t)0u; i < (uint8_t)CJ_NCOEF; i++)
            h = cj_mix(h, (uint16_t)cj_obs[p][i]);
        for (uint8_t i = (uint8_t)0u; i < (uint8_t)CJ_NSAMP; i++) {
            int16_t x, y;
            cj_point(cj_obs[p], i, &x, &y);
            h = cj_mix(h, (uint16_t)x);
            h = cj_mix(h, (uint16_t)y);
        }
    }
    h = cj_mix(h, cj_sink);
    h = cj_mix(h, cj_burns);
    return h;
}

// --------------------------------------------------------------------------
// Differential gate: CJ_PASSES setjmp/scribble/longjmp rounds, folding the restored coefficient
// vector of each plus the curve it renders.
// --------------------------------------------------------------------------
static uint16_t csrjmp_gate_crc(void) {
    cj_sink = (uint16_t)0u;
    cj_burns = (uint16_t)0u;
    for (uint8_t p = (uint8_t)0u; p < (uint8_t)CJ_PASSES; p++) {
        cj_rv[p] = (uint8_t)0u;
        for (uint8_t i = (uint8_t)0u; i < (uint8_t)CJ_NCOEF; i++) cj_obs[p][i] = (uint8_t)0u;
    }

    for (cj_pass = (uint8_t)0u; cj_pass < (uint8_t)CJ_PASSES; cj_pass++) {
        cj_seed(cj_pass);
        /* The 14 locals under test: loaded here, never modified, read back after the longjmp. */
        uint8_t c0  = cj_coef[0],  c1  = cj_coef[1],  c2  = cj_coef[2],  c3  = cj_coef[3];
        uint8_t c4  = cj_coef[4],  c5  = cj_coef[5],  c6  = cj_coef[6],  c7  = cj_coef[7];
        uint8_t c8  = cj_coef[8],  c9  = cj_coef[9],  c10 = cj_coef[10], c11 = cj_coef[11];
        uint8_t c12 = cj_coef[12], c13 = cj_coef[13];

        int rv = setjmp(cj_jb);
        if (rv == 0) cj_worker(cj_pass);          /* never returns */

        /* Land the restored locals at a constant address — the two-dimensional cj_obs[][] write
           needs a 16-bit computed index whose live range would stack on top of the 14 values
           still in the callee-saved block; cj_record() carries them the rest of the way. */
        cj_seen[0]  = c0;  cj_seen[1]  = c1;  cj_seen[2]  = c2;  cj_seen[3]  = c3;
        cj_seen[4]  = c4;  cj_seen[5]  = c5;  cj_seen[6]  = c6;  cj_seen[7]  = c7;
        cj_seen[8]  = c8;  cj_seen[9]  = c9;  cj_seen[10] = c10; cj_seen[11] = c11;
        cj_seen[12] = c12; cj_seen[13] = c13;
        cj_record((uint8_t)rv);
    }

    return cj_fold();
}

#endif /* CSRJMP_H */
