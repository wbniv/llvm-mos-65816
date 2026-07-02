// Three-Way Merge Diff (#99) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster B. Re-stresses patch 0016 (#46 qsortviz, `{G_SCMP,G_UCMP}
// .lower()` → LegalizerHelper::lowerThreewayCompare) with the three-way-compare result used **AS
// CONTROL FLOW**, not as a qsort return value compared to 0. A 2-input merge branches on the sign
// of `(a>b)-(a<b)`: −1 → advance-left, +1 → advance-right, 0 → EMIT-BOTH (the equal case). #97
// spaceship and #98 ucmprank fed the scmp/ucmp result to qsort (compared to 0); here the −1/0/+1
// value itself selects among three code paths — a distinct downstream use of the same lowering.
//
// WHY a noinline comparator: written inline, `((a>b)-(a<b)) < 0` folds straight back to `a < b`
// and the G_SCMP vanishes (the #97 lesson). Through an opaque `noinline` comparator that RETURNS
// the −1/0/+1 result, the scmp is materialized as the return value (exactly qsort's mechanism), and
// the merge then switches on it. Exercised at s32 AND s64 (the wide compare as control flow).
//
// DIFFERENTIAL: a merge of sorted streams is a deterministic reordering → the merged sequence is
// bit-identical host vs target. A wrong three-way lowering picks the wrong branch and diverges the
// CRC. Streams are centered on 0 (both signs) with periodic collisions so the equal/emit-both
// branch fires. WIDTH DISCIPLINE: explicit int32/int64; no bare int in data; no float.
// See docs/plans/2026-07-02-99-snes-trimerge.md.

#ifndef TRIMERGE_H
#define TRIMERGE_H

#include <stdint.h>

#define TM_N 20u   // elements per input stream

// noinline three-way comparators — each RETURNS the −1/0/+1 scmp result (kept alive across the call).
__attribute__((noinline))
static int tm_cmp32(int32_t a, int32_t b) { return (int)((a > b) - (a < b)); }   // G_SCMP s32
__attribute__((noinline))
static int tm_cmp64(int64_t a, int64_t b) { return (int)((a > b) - (a < b)); }   // G_SCMP s64

// 2-input merge; the sign of the three-way compare selects the branch (advance-L / emit-both / advance-R).
static uint16_t tm_merge32(const int32_t *L, uint16_t nl, const int32_t *R, uint16_t nr, int32_t *out) {
    uint16_t i = 0u, j = 0u, k = 0u;
    while (i < nl && j < nr) {
        int c = tm_cmp32(L[i], R[j]);
        if (c < 0)      { out[k++] = L[i++]; }                     // advance left
        else if (c > 0) { out[k++] = R[j++]; }                     // advance right
        else            { out[k++] = L[i++]; out[k++] = R[j++]; }  // emit both (equal, c == 0)
    }
    while (i < nl) out[k++] = L[i++];
    while (j < nr) out[k++] = R[j++];
    return k;
}
static uint16_t tm_merge64(const int64_t *L, uint16_t nl, const int64_t *R, uint16_t nr, int64_t *out) {
    uint16_t i = 0u, j = 0u, k = 0u;
    while (i < nl && j < nr) {
        int c = tm_cmp64(L[i], R[j]);
        if (c < 0)      { out[k++] = L[i++]; }
        else if (c > 0) { out[k++] = R[j++]; }
        else            { out[k++] = L[i++]; out[k++] = R[j++]; }
    }
    while (i < nl) out[k++] = L[i++];
    while (j < nr) out[k++] = R[j++];
    return k;
}

static inline uint16_t tm_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

// Fill a sorted (ascending) stream centered on 0, spanning the width's bytes, with `mul` setting the
// stride so two streams (mul=2, mul=3) collide periodically → the emit-both branch fires.
static void tm_fill32(int32_t *a, uint16_t n, int32_t mul, int32_t off) {
    for (uint16_t i = 0u; i < n; i++)
        a[i] = (int32_t)(((int32_t)((int32_t)i - (int32_t)(n / 2u)) * (int32_t)0x00010001 * mul) + off);
}
static void tm_fill64(int64_t *a, uint16_t n, int64_t mul, int64_t off) {
    for (uint16_t i = 0u; i < n; i++)
        a[i] = (int64_t)(((int64_t)((int32_t)i - (int32_t)(n / 2u)) * (int64_t)0x0001000100010001LL * mul) + off);
}

// ---------------------------------------------------------------------------------------------
// Differential gate: GATE_N rounds, each merges s32 and s64 stream pairs (varying offset) and folds
// the merged outputs. The three-way compare drives control flow in every merge step.
// ---------------------------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 8u
#endif

static int32_t _tm_l32[TM_N], _tm_r32[TM_N], _tm_o32[2u * TM_N];
static int64_t _tm_l64[TM_N], _tm_r64[TM_N], _tm_o64[2u * TM_N];

static uint16_t trimerge_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    for (uint16_t step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        int32_t off = (int32_t)((int32_t)step * (int32_t)7 - (int32_t)16);

        tm_fill32(_tm_l32, (uint16_t)TM_N, (int32_t)3, off);
        tm_fill32(_tm_r32, (uint16_t)TM_N, (int32_t)2, (int32_t)(-off));
        uint16_t k32 = tm_merge32(_tm_l32, (uint16_t)TM_N, _tm_r32, (uint16_t)TM_N, _tm_o32);
        for (uint16_t i = 0u; i < k32; i++)
            h = tm_fold(h, (uint16_t)((uint32_t)_tm_o32[i] ^ ((uint32_t)_tm_o32[i] >> 16)));

        tm_fill64(_tm_l64, (uint16_t)TM_N, (int64_t)3, (int64_t)off);
        tm_fill64(_tm_r64, (uint16_t)TM_N, (int64_t)2, (int64_t)(-off));
        uint16_t k64 = tm_merge64(_tm_l64, (uint16_t)TM_N, _tm_r64, (uint16_t)TM_N, _tm_o64);
        for (uint16_t i = 0u; i < k64; i++) {
            uint64_t v = (uint64_t)_tm_o64[i];
            h = tm_fold(h, (uint16_t)(v ^ (v >> 16) ^ (v >> 32) ^ (v >> 48)));
        }
    }
    return h;
}

// -------- ROM display: braid two input lanes into one merged lane ------------------------------
#define TM_LANE 16u   // visible rows per lane column

#endif /* TRIMERGE_H */
