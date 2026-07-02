// Unsigned Rank Percentile Field (#98) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster B. Re-stresses the **UNSIGNED half** of patch 0016 (#46
// qsortviz): the three-way-compare idiom `(a>b)-(a<b)` on UNSIGNED operands is canonicalized by
// clang to the generic **G_UCMP** opcode (its signed twin G_SCMP was covered by #46/#97). 0016
// routes BOTH `{G_SCMP,G_UCMP}.lower()` → LegalizerHelper::lowerThreewayCompare, but every prior
// demo emitted only the SIGNED G_SCMP — the unsigned lowering path was completely unexercised.
//
// ESCALATION vs #97 spaceship (signed s16/s32/s64): here the comparators are on uint16/uint32/
// uint64, forcing **G_UCMP at u16, u32, and u64** in one ROM. Unsigned ordering differs from signed
// exactly where the high bit is set (values > 0x7FFF... compare as LARGE, not negative), so a
// lowering that reused the signed compare would sort those wrong and diverge the CRC.
//
// WHY qsort (not a hand compare): a direct `spaceship(a,b) > 0` folds back to a plain `a > b` and
// the G_UCMP vanishes (the #97 lesson). Through qsort's opaque `int(*)(const void*,const void*)`
// callback the comparator genuinely RETURNS the −1/0/+1 ucmp result, so it survives.
//
// DIFFERENTIAL: fold the SORTED unsigned values (qsort is unstable, but equal values are
// interchangeable → the sorted value sequence is identical host vs target). A wrong unsigned
// three-way lowering diverges the CRC. WIDTH DISCIPLINE: explicit uint16/32/64; no bare int in data.
// See docs/plans/2026-07-02-98-snes-ucmprank.md.

#ifndef UCMPRANK_H
#define UCMPRANK_H

#include <stdlib.h>
#include <stdint.h>

#define UR_N 24u   // elements per width panel (qsort O(n log n); u64 compares are the slow leg)

// --- width-specific UNSIGNED spaceship comparators (each RETURNS the −1/0/+1 ucmp result) ---
static int ur_cmp16(const void *a, const void *b) {
    uint16_t x = *(const uint16_t *)a, y = *(const uint16_t *)b;
    return (int)((x > y) - (x < y));      // G_UCMP u16
}
static int ur_cmp32(const void *a, const void *b) {
    uint32_t x = *(const uint32_t *)a, y = *(const uint32_t *)b;
    return (int)((x > y) - (x < y));      // G_UCMP u32
}
static int ur_cmp64(const void *a, const void *b) {
    uint64_t x = *(const uint64_t *)a, y = *(const uint64_t *)b;
    return (int)((x > y) - (x < y));      // G_UCMP u64  ← the unsigned width no prior demo emitted
}

// Deterministic LCG fills spreading values across ALL bits (incl. the high bit — where unsigned and
// signed ordering DIVERGE, so a signed-reused lowering would sort wrong).
static void ur_fill16(uint16_t *a, uint16_t n, uint16_t seed) {
    uint16_t s = seed;
    for (uint16_t i = 0u; i < n; i++) { s = (uint16_t)(s * 25173u + 13849u); a[i] = s; }
}
static void ur_fill32(uint32_t *a, uint16_t n, uint16_t seed) {
    uint16_t s = seed;
    for (uint16_t i = 0u; i < n; i++) {
        s = (uint16_t)(s * 25173u + 13849u); uint16_t t = (uint16_t)(s * 13u + 7u);
        a[i] = (((uint32_t)s << 16) ^ (uint32_t)t);
    }
}
static void ur_fill64(uint64_t *a, uint16_t n, uint16_t seed) {
    uint16_t s = seed;
    for (uint16_t i = 0u; i < n; i++) {
        s = (uint16_t)(s * 25173u + 13849u); uint16_t t = (uint16_t)(s * 13u + 7u);
        a[i] = (((uint64_t)s << 48) ^ ((uint64_t)t << 32)
              ^ ((uint64_t)(uint16_t)(s ^ t) << 16) ^ (uint64_t)(uint16_t)(s + t));
    }
}

static inline uint16_t ur_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

// ---------------------------------------------------------------------------------------------
// Differential gate: qsort each unsigned width-panel with its ucmp spaceship, fold sorted values.
// ---------------------------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N UR_N
#endif

static uint16_t _ur_a16[UR_N];
static uint32_t _ur_a32[UR_N];
static uint64_t _ur_a64[UR_N];

static uint16_t ucmprank_gate_crc(void) {
    uint16_t h = (uint16_t)0u;

    ur_fill16(_ur_a16, (uint16_t)UR_N, (uint16_t)0xA1B2u);
    qsort(_ur_a16, (size_t)UR_N, sizeof _ur_a16[0], ur_cmp16);
    for (uint16_t i = 0u; i < (uint16_t)UR_N; i++) h = ur_fold(h, _ur_a16[i]);

    ur_fill32(_ur_a32, (uint16_t)UR_N, (uint16_t)0xC3D4u);
    qsort(_ur_a32, (size_t)UR_N, sizeof _ur_a32[0], ur_cmp32);
    for (uint16_t i = 0u; i < (uint16_t)UR_N; i++)
        h = ur_fold(h, (uint16_t)(_ur_a32[i] ^ (_ur_a32[i] >> 16)));

    ur_fill64(_ur_a64, (uint16_t)UR_N, (uint16_t)0xE5F6u);
    qsort(_ur_a64, (size_t)UR_N, sizeof _ur_a64[0], ur_cmp64);
    for (uint16_t i = 0u; i < (uint16_t)UR_N; i++) {
        uint64_t v = _ur_a64[i];
        h = ur_fold(h, (uint16_t)(v ^ (v >> 16) ^ (v >> 32) ^ (v >> 48)));
    }
    return h;
}

// -------- ROM display: a percentile-rank field ------------------------------------------------
// UR_CELLS uint32 values; each cell recoloured by its rank (percentile) among all cells. Ranks
// use the same unsigned ordering the gate stresses; the visual is the value field sorted into
// colour bands. (The corpus gate above is the arbiter; the field is the witness.)
#define UR_GRID  16u
#define UR_CELLS ((uint16_t)((uint16_t)UR_GRID * (uint16_t)UR_GRID))   // 256

typedef struct {
    uint32_t val[UR_CELLS];
    uint8_t  rank_color[UR_CELLS];   // 0..3 percentile band
} URField;

static void ur_field_fill(URField *f, uint16_t seed) {
    uint16_t s = seed;
    for (uint16_t i = 0u; i < (uint16_t)UR_CELLS; i++) {
        s = (uint16_t)(s * 25173u + 13849u); uint16_t t = (uint16_t)(s * 13u + 7u);
        f->val[i] = (((uint32_t)s << 16) ^ (uint32_t)t);
    }
}

// Rank each cell = count of cells with a strictly smaller value (unsigned), → 4 percentile bands.
static void ur_field_rank(URField *f) {
    for (uint16_t i = 0u; i < (uint16_t)UR_CELLS; i++) {
        uint16_t less = (uint16_t)0u;
        for (uint16_t j = 0u; j < (uint16_t)UR_CELLS; j++)
            if (f->val[j] < f->val[i]) less++;                 // unsigned ordering
        f->rank_color[i] = (uint8_t)((uint16_t)((uint16_t)less * (uint16_t)4u) / (uint16_t)UR_CELLS);
    }
}

#endif /* UCMPRANK_H */
