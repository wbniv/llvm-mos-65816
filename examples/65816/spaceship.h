// Width-Sweep Sort Gallery (#97) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster B. Re-stresses patch 0016 (#46 qsortviz): the
// three-way-compare idiom `(a>b)-(a<b)` is canonicalized by clang to the generic G_SCMP opcode,
// which MOSLegalizerInfo routes to `.lower()` → LegalizerHelper::lowerThreewayCompare (icmp+select).
// #46 crashed the backend before the fix, and exercised G_SCMP at ONE width (int16 qsort keys).
//
// ESCALATION: qsort FOUR arrays whose comparators return the spaceship at int8/int16/int32/int64
// keys — forcing G_SCMP at the distinct IR widths **s16 (int8+int16 after C integer promotion),
// s32, and s64**. The s32 and s64 legs are widths qsortviz never reached; lowerThreewayCompare at
// s64 (a 64-bit icmp+select) is completely unexercised by any prior demo.
//
// WHY qsort (not a hand sort): a direct `spaceship(a,b) > 0` folds back to a plain `a > b` and the
// G_SCMP vanishes. Through qsort's opaque `int(*)(const void*,const void*)` callback the comparator
// genuinely RETURNS the −1/0/+1 scmp result (qsort compares it to 0), so the scmp survives — the
// exact mechanism that made #46 emit (and crash on) G_SCMP.
//
// DIFFERENTIAL: fold the sorted VALUES (not identities). qsort is unstable, but equal values are
// interchangeable → the sorted value sequence is identical host vs target regardless of tie-break
// or pivot choice. A wrong three-way lowering at any width diverges the CRC.
// WIDTH DISCIPLINE: explicit int8/16/32/64; no bare int in data; no float.
// See docs/plans/2026-07-02-97-snes-spaceship.md.

#ifndef SPACESHIP_H
#define SPACESHIP_H

#include <stdlib.h>
#include <stdint.h>

#define SP_N 24u   // elements per panel (qsort O(n log n); int64 compares are the slow leg)

// --- width-specific spaceship comparators (each RETURNS the −1/0/+1 scmp result) ---
static int sp_cmp8(const void *a, const void *b) {
    int8_t x = *(const int8_t *)a, y = *(const int8_t *)b;
    return (int)((x > y) - (x < y));      // G_SCMP (int8 promotes to the s16 path)
}
static int sp_cmp16(const void *a, const void *b) {
    int16_t x = *(const int16_t *)a, y = *(const int16_t *)b;
    return (int)((x > y) - (x < y));      // G_SCMP s16
}
static int sp_cmp32(const void *a, const void *b) {
    int32_t x = *(const int32_t *)a, y = *(const int32_t *)b;
    return (int)((x > y) - (x < y));      // G_SCMP s32
}
static int sp_cmp64(const void *a, const void *b) {
    int64_t x = *(const int64_t *)a, y = *(const int64_t *)b;
    return (int)((x > y) - (x < y));      // G_SCMP s64  ← the width #46 never reached
}

// Deterministic LCG fills. Values are spread across ALL bits of each width so the sort ORDER
// depends on the high limbs too (an s64 compare that mishandles a high limb diverges the order),
// and bit-N-1 varies → both signs exercised.
static void sp_fill8(int8_t *a, uint16_t n, uint16_t seed) {
    uint16_t s = seed;
    for (uint16_t i = 0u; i < n; i++) { s = (uint16_t)(s * 25173u + 13849u); a[i] = (int8_t)(s >> 8); }
}
static void sp_fill16(int16_t *a, uint16_t n, uint16_t seed) {
    uint16_t s = seed;
    for (uint16_t i = 0u; i < n; i++) { s = (uint16_t)(s * 25173u + 13849u); a[i] = (int16_t)s; }
}
static void sp_fill32(int32_t *a, uint16_t n, uint16_t seed) {
    uint16_t s = seed;
    for (uint16_t i = 0u; i < n; i++) {
        s = (uint16_t)(s * 25173u + 13849u); uint16_t t = (uint16_t)(s * 13u + 7u);
        a[i] = (int32_t)(((uint32_t)s << 16) ^ (uint32_t)t);
    }
}
static void sp_fill64(int64_t *a, uint16_t n, uint16_t seed) {
    uint16_t s = seed;
    for (uint16_t i = 0u; i < n; i++) {
        s = (uint16_t)(s * 25173u + 13849u); uint16_t t = (uint16_t)(s * 13u + 7u);
        a[i] = (int64_t)(((uint64_t)s << 48) ^ ((uint64_t)t << 32)
                       ^ ((uint64_t)(uint16_t)(s ^ t) << 16) ^ (uint64_t)(uint16_t)(s + t));
    }
}

static inline uint16_t sp_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

// ---------------------------------------------------------------------------------------------
// Differential gate: qsort each width-panel with its spaceship comparator, fold the sorted values.
// ---------------------------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N SP_N
#endif

static int8_t  _sp_a8 [SP_N];
static int16_t _sp_a16[SP_N];
static int32_t _sp_a32[SP_N];
static int64_t _sp_a64[SP_N];

static uint16_t spaceship_gate_crc(void) {
    uint16_t h = (uint16_t)0u;

    sp_fill8(_sp_a8, (uint16_t)SP_N, (uint16_t)0xA101u);
    qsort(_sp_a8, (size_t)SP_N, sizeof _sp_a8[0], sp_cmp8);
    for (uint16_t i = 0u; i < (uint16_t)SP_N; i++) h = sp_fold(h, (uint16_t)(uint8_t)_sp_a8[i]);

    sp_fill16(_sp_a16, (uint16_t)SP_N, (uint16_t)0xB202u);
    qsort(_sp_a16, (size_t)SP_N, sizeof _sp_a16[0], sp_cmp16);
    for (uint16_t i = 0u; i < (uint16_t)SP_N; i++) h = sp_fold(h, (uint16_t)_sp_a16[i]);

    sp_fill32(_sp_a32, (uint16_t)SP_N, (uint16_t)0xC303u);
    qsort(_sp_a32, (size_t)SP_N, sizeof _sp_a32[0], sp_cmp32);
    for (uint16_t i = 0u; i < (uint16_t)SP_N; i++)
        h = sp_fold(h, (uint16_t)((uint32_t)_sp_a32[i] ^ ((uint32_t)_sp_a32[i] >> 16)));

    sp_fill64(_sp_a64, (uint16_t)SP_N, (uint16_t)0xD404u);
    qsort(_sp_a64, (size_t)SP_N, sizeof _sp_a64[0], sp_cmp64);
    for (uint16_t i = 0u; i < (uint16_t)SP_N; i++) {
        uint64_t v = (uint64_t)_sp_a64[i];
        h = sp_fold(h, (uint16_t)(v ^ (v >> 16) ^ (v >> 32) ^ (v >> 48)));
    }
    return h;
}

// -------- ROM display: keep four sorted panels + a shuffle for animation --------
#define SP_BARS 16u    // visible bars per panel column

typedef struct {
    int16_t bar[SP_BARS];   // display values 0..(SP_BARS-1), a permutation being sorted
    uint8_t sorted;         // how many leading bars are in place (insertion-sort progress)
    uint8_t width_id;       // 0=i8 1=i16 2=i32 3=i64 (label)
} SPPanel;

#endif /* SPACESHIP_H */
