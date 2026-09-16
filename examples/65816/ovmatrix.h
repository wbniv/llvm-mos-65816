// Overflow Family Matrix (#155) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster C — the boundary and width escalations.
//
// THE ESCALATION: the battery has covered every overflow builtin, but always ONE AT A TIME.
//
//   #44  hdr-bloom   __builtin_add_overflow                      G_UADDO / G_SADDO
//   #76  smulorbit   __builtin_mul_overflow  (16/32)             G_UMULO / G_SMULO
//   #101 mulov64     __builtin_mul_overflow  (64)                G_UMULO / G_SMULO at s64
//   #144 borrowov    __builtin_sub_overflow  (16/32)             G_USUBO / G_SSUBO
//
// Each of those isolates one family, at one or two widths, in a loop of its own. This demo puts
// ALL SIX generic opcodes in ONE noinline kernel at ALL THREE widths — {add, sub, mul} x
// {16, 32, 64} x {unsigned, signed} = 18 cells — with every cell's operands and every cell's
// result live across the others. The signed and unsigned forms of each family sit adjacent, so
// the two custom lowerings (which differ in flag SENSE, not just in operand type) are selected
// and register-allocated next to each other under real pressure rather than in isolation.
//
// MEASURED BEFORE THE DEMO WAS WRITTEN — and it changed the design. A first probe with ONE
// CONSTANT OPERAND per builtin formed only:
//
//     G_UADDO=2  G_SADDO=2  G_UMULO=2  G_SMULO=2  G_USUBO=1  G_SSUBO=0
//
// i.e. constant folding erases cells outright, and G_SSUBO — the family #144 exists for —
// disappeared entirely. A demo written with literal operands would have compiled cleanly and
// covered less than it claimed. So BOTH operands of every cell here are driven from runtime
// state, and the gate asserts that every one of the 18 cells fired BOTH outcomes (overflow and
// clean) at least once. A cell that only ever overflows, or only ever does not, is a cell whose
// other arm was never compiled into the measurement.
//
// DIFFERENTIAL: integer-exact at every width. `__builtin_*_overflow` is fully defined — the
// operation is performed at infinite precision and then wrapped into the result type — so host
// and target must agree bit-for-bit, with no implementation-defined corner anywhere. The CRC
// folds each cell's accumulated result and its overflow/clean counts.
// WIDTH DISCIPLINE: explicit uint8/16/32/64; nothing depends on the width of `int`.
// See docs/plans/2026-09-16-round8-cluster-c-boundary-and-width-escalations.md.

#ifndef OVMATRIX_H
#define OVMATRIX_H

#include <stdint.h>

#define OV_CELLS  18u
#define OV_STEPS  96u

/* Cell index = family*6 + width*2 + signedness.
   family: 0 add, 1 sub, 2 mul.  width: 0 = 16, 1 = 32, 2 = 64.  sign: 0 unsigned, 1 signed. */
#define OV_IDX(F, W, S) ((uint8_t)((F) * 6u + (W) * 2u + (S)))

static uint16_t ov_fire[OV_CELLS];    /* times this cell reported overflow */
static uint16_t ov_clean[OV_CELLS];   /* times it did not                  */
static uint32_t ov_res[OV_CELLS];     /* folded result stream per cell      */

/* The six live lanes. Every cell reads its own lane and writes it back, so all 18 results are
   live across each other inside the kernel. */
static uint16_t ov_u16;
static int16_t  ov_i16;
static uint32_t ov_u32;
static int32_t  ov_i32;
static uint64_t ov_u64;
static int64_t  ov_i64;

static uint16_t ov_mul16(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}

/* One cell. `r` is the wrapped result whatever happens — the builtin defines it — so nothing
   undefined is ever folded. The result is narrowed to 32 bits for the fold, which loses nothing
   that matters: a wrong high half of an s64 result changes the low half too in every case this
   kernel produces, and the per-cell overflow counts are folded separately. */
#define OV_CELL(IDX, TY, OP, X, Y, LANE)                                          \
    do {                                                                          \
        TY ov_a = (TY)(X);                                                        \
        TY ov_b = (TY)(Y);                                                         \
        TY ov_r;                                                                  \
        if (__builtin_##OP##_overflow(ov_a, ov_b, &ov_r))                          \
            ov_fire[IDX] = (uint16_t)(ov_fire[IDX] + 1u);                          \
        else                                                                       \
            ov_clean[IDX] = (uint16_t)(ov_clean[IDX] + 1u);                        \
        ov_res[IDX] = (uint32_t)(ov_res[IDX] * 3u                                  \
                                 + (uint32_t)((uint64_t)(ov_r) & 0xFFFFFFFFu));    \
        (LANE) = ov_r;                                                             \
    } while (0)

// --------------------------------------------------------------------------
// THE KERNEL. All 18 cells in one noinline function, every operand from runtime state.
// --------------------------------------------------------------------------
__attribute__((noinline))
static void ov_kernel(uint16_t s) {
    /* Per-step magnitudes, all runtime. `small` keeps most steps clean; `near` sits a
       data-dependent distance below the type's limit so the same cell overflows on some steps
       and not on others. */
    uint16_t small = (uint16_t)((s & 0x1FFu) + 1u);
    uint16_t gap   = (uint16_t)((s >> 5) & 0x3FFu);

    /* ---- add ---- */
    OV_CELL(OV_IDX(0u, 0u, 0u), uint16_t, add,
            ov_u16, (uint16_t)(0xFFFFu - (uint16_t)(gap * 64u)), ov_u16);
    OV_CELL(OV_IDX(0u, 0u, 1u), int16_t, add,
            (int16_t)(ov_i16 | 1), (int16_t)(32767 - (int16_t)gap), ov_i16);
    OV_CELL(OV_IDX(0u, 1u, 0u), uint32_t, add,
            ov_u32, (uint32_t)(0xFFFFFFFFu - (uint32_t)gap * 4194304u), ov_u32);
    OV_CELL(OV_IDX(0u, 1u, 1u), int32_t, add,
            (int32_t)(ov_i32 | 1), (int32_t)(2147483647 - (int32_t)gap * 65536), ov_i32);
    OV_CELL(OV_IDX(0u, 2u, 0u), uint64_t, add,
            ov_u64, (uint64_t)(0xFFFFFFFFFFFFFFFFull - (uint64_t)gap * 18014398509481984ull),
            ov_u64);
    OV_CELL(OV_IDX(0u, 2u, 1u), int64_t, add,
            (int64_t)(ov_i64 | 1),
            (int64_t)(9223372036854775807ll - (int64_t)gap * 281474976710656ll), ov_i64);

    /* ---- sub ---- */
    OV_CELL(OV_IDX(1u, 0u, 0u), uint16_t, sub,
            (uint16_t)(ov_u16 ^ small), (uint16_t)(gap * 64u), ov_u16);
    OV_CELL(OV_IDX(1u, 0u, 1u), int16_t, sub,
            (int16_t)(ov_i16 | 1), (int16_t)(-32768 + (int16_t)gap), ov_i16);
    OV_CELL(OV_IDX(1u, 1u, 0u), uint32_t, sub,
            (uint32_t)(ov_u32 ^ (uint32_t)small), (uint32_t)gap * 4194304u, ov_u32);
    OV_CELL(OV_IDX(1u, 1u, 1u), int32_t, sub,
            (int32_t)(ov_i32 | 1), (int32_t)(-2147483647 - 1 + (int32_t)gap * 65536), ov_i32);
    OV_CELL(OV_IDX(1u, 2u, 0u), uint64_t, sub,
            (uint64_t)(ov_u64 ^ (uint64_t)small),
            (uint64_t)gap * 18014398509481984ull, ov_u64);
    OV_CELL(OV_IDX(1u, 2u, 1u), int64_t, sub,
            (int64_t)(ov_i64 | 1),
            (int64_t)(-9223372036854775807ll - 1 + (int64_t)gap * 281474976710656ll), ov_i64);

    /* ---- mul ---- */
    OV_CELL(OV_IDX(2u, 0u, 0u), uint16_t, mul,
            (uint16_t)((ov_u16 & 0x3FFu) | 1u), (uint16_t)(small | 1u), ov_u16);
    OV_CELL(OV_IDX(2u, 0u, 1u), int16_t, mul,
            (int16_t)((ov_i16 & 0x3FF) | 1), (int16_t)((int16_t)(small | 1u) - 256), ov_i16);
    OV_CELL(OV_IDX(2u, 1u, 0u), uint32_t, mul,
            (uint32_t)((ov_u32 & 0x03FFFFFFu) | 1u), (uint32_t)(small | 1u), ov_u32);
    OV_CELL(OV_IDX(2u, 1u, 1u), int32_t, mul,
            (int32_t)((ov_i32 & 0x03FFFFFF) | 1), (int32_t)((int32_t)(small | 1u) - 256), ov_i32);
    OV_CELL(OV_IDX(2u, 2u, 0u), uint64_t, mul,
            (uint64_t)((ov_u64 & 0x03FFFFFFFFFFFFFFull) | 1ull), (uint64_t)(small | 1u), ov_u64);
    OV_CELL(OV_IDX(2u, 2u, 1u), int64_t, mul,
            (int64_t)((ov_i64 & 0x03FFFFFFFFFFFFFFll) | 1ll),
            (int64_t)((int32_t)(small | 1u) - 256), ov_i64);
}

static void ov_reset(void) {
    for (uint8_t c = (uint8_t)0u; c < (uint8_t)OV_CELLS; c++) {
        ov_fire[c] = (uint16_t)0u;
        ov_clean[c] = (uint16_t)0u;
        ov_res[c] = (uint32_t)0u;
    }
    ov_u16 = (uint16_t)0x1357u;
    ov_i16 = (int16_t)0x2468;
    ov_u32 = (uint32_t)0x89ABCDEFu;
    ov_i32 = (int32_t)0x12345678;
    ov_u64 = (uint64_t)0x0123456789ABCDEFull;
    ov_i64 = (int64_t)0x0FEDCBA987654321ll;
}

static void ov_run(void) {
    uint16_t s = (uint16_t)0x9E3Bu;
    ov_reset();
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)OV_STEPS; i++) {
        s = (uint16_t)(ov_mul16(s, (uint16_t)25173u) + (uint16_t)13849u);
        ov_kernel(s);
    }
}

static uint16_t ov_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(ov_mul16(h, (uint16_t)25173u) + (uint16_t)13849u);
}
static uint16_t ov_mix32(uint16_t h, uint32_t v) {
    h = ov_mix(h, (uint16_t)(v & 0xFFFFu));
    return ov_mix(h, (uint16_t)((v >> 16) & 0xFFFFu));
}
static uint16_t ov_mix64(uint16_t h, uint64_t v) {
    h = ov_mix32(h, (uint32_t)(v & 0xFFFFFFFFu));
    return ov_mix32(h, (uint32_t)((v >> 32) & 0xFFFFFFFFu));
}

// --------------------------------------------------------------------------
// Differential gate.
// --------------------------------------------------------------------------
static uint16_t ovmatrix_gate_crc(void) {
    uint16_t h = (uint16_t)0x7C4Eu;
    ov_run();
    for (uint8_t c = (uint8_t)0u; c < (uint8_t)OV_CELLS; c++) {
        h = ov_mix(h, ov_fire[c]);
        h = ov_mix(h, ov_clean[c]);
        h = ov_mix32(h, ov_res[c]);
    }
    h = ov_mix(h, ov_u16);
    h = ov_mix(h, (uint16_t)ov_i16);
    h = ov_mix32(h, ov_u32);
    h = ov_mix32(h, (uint32_t)ov_i32);
    h = ov_mix64(h, ov_u64);
    h = ov_mix64(h, (uint64_t)ov_i64);
    return h;
}

/* The cross-check the gate asserts: EVERY cell must have fired both ways. A one-sided cell means
   its other arm was folded away or never reached, and the matrix would be covering less than it
   claims. Returns the number of two-sided cells, which must be OV_CELLS. */
static uint8_t ov_two_sided_cells(void) {
    uint8_t n = (uint8_t)0u;
    for (uint8_t c = (uint8_t)0u; c < (uint8_t)OV_CELLS; c++)
        if (ov_fire[c] > (uint16_t)0u && ov_clean[c] > (uint16_t)0u) n = (uint8_t)(n + 1u);
    return n;
}

#endif /* OVMATRIX_H */
