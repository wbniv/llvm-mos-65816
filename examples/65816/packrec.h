// Unaligned Record Reader (#149) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster B. **READ THIS FRAMING BEFORE THE CODE.**
//
// The ideas doc proposed `__attribute__((packed))` as a distinct LOWERING: a naturally-typed
// `uint16_t`/`uint32_t` member at an odd byte offset decomposing into a multi-byte access,
// unlike the shift-and-mask #52 disbits gets for bitfields. **Measured in this tree, that is
// not true on MOS, and the reason is structural:**
//
//   struct P { uint8_t t; uint16_t w; uint32_t d; uint8_t e; };             /* unpacked */
//   struct __attribute__((packed)) Q { ...same members... };                /* packed   */
//   _Static_assert(sizeof(struct P) == sizeof(struct Q), "");               /* PASSES   */
//   _Static_assert(__builtin_offsetof(struct P, w) == 1, "");               /* PASSES   */
//   _Static_assert(_Alignof(uint32_t) == 1, "");                            /* PASSES   */
//
// Every scalar on MOS already has ABI alignment 1, so an unpacked struct has NO PADDING TO
// REMOVE and `packed` is a layout no-op. The IR agrees from the other side: an ordinary
// `uint32_t` global is emitted as `@g = global i32 align 1`, so the `load i32 ... align 1`
// a packed member produces is indistinguishable from any other load. There is no second
// lowering here to enter. That is Round 8's second negative result, recorded so a later round
// does not re-derive it.
//
// SO WHAT IS THIS DEMO FOR? A narrower and honest job: it is the tree's **only regression
// guard for the padding-free-layout invariant**. Zero packed structs — and, more to the
// point, zero layout assertions of any kind — exist across demos #1-#141. That invariant is
// load-bearing for every binary-format parse anyone writes with this toolchain: if a future
// backend change ever raised `_Alignof(uint16_t)` or `_Alignof(uint32_t)` to 2, every record
// stride and every member offset would shift and every such parse would silently start
// reading the wrong bytes, with no diagnostic and no crash. This demo pins it.
//
// MECHANISM: a packed binary telemetry stream with TWO record shapes of coprime, odd sizes
// (7 and 10 bytes) selected by a tag byte, parsed live out of a byte blob through a computed
// record pointer. The odd strides are the point — after the first record the cursor is at an
// odd absolute offset and stays irregular, so every wide field is read from an offset the
// compiler cannot fold to a constant alignment.
//
// DIFFERENTIAL: integer-exact. The CRC folds every parsed field of every record, every record
// start offset, and the per-shape counts.
// WIDTH DISCIPLINE: explicit uint8/16/32; every multiply goes through uint32_t.
// See docs/plans/2026-09-16-round8-cluster-b-conversion-comparison-layout.md.

#ifndef PACKREC_H
#define PACKREC_H

#include <stdint.h>

#define PK_BYTES  480u   /* the raw stream                 */
#define PK_MAX     96u   /* recorded parsed records        */

/* Shape A — 10 bytes. Every wide member sits at an ODD offset. */
struct __attribute__((packed)) PkA {
    uint8_t  tag;     /* +0 */
    uint16_t seq;     /* +1  odd */
    uint32_t stamp;   /* +3  odd */
    uint16_t val;     /* +7  odd */
    uint8_t  flags;   /* +9 */
};

/* Shape B — 7 bytes, coprime with A's 10, so the cursor's parity keeps changing. */
struct __attribute__((packed)) PkB {
    uint8_t  tag;     /* +0 */
    uint32_t acc;     /* +1  odd */
    uint16_t delta;   /* +5  odd */
};

/* The unpacked twins, used ONLY by the layout assertions below — never pointer-cast, because
   on a strict-alignment host that would be undefined behaviour. */
struct PkAPlain { uint8_t tag; uint16_t seq; uint32_t stamp; uint16_t val; uint8_t flags; };
struct PkBPlain { uint8_t tag; uint32_t acc; uint16_t delta; };

/* --- THE INVARIANT THIS DEMO EXISTS TO GUARD ----------------------------------------
   Packed and unpacked must agree, member for member and in total size, because every
   scalar's ABI alignment is 1. If any of these ever fails, the target grew padding and
   every binary-record parse in every program built with this toolchain is now wrong. */
_Static_assert(sizeof(struct PkA) == 10u, "PkA must be exactly 10 bytes");
_Static_assert(sizeof(struct PkB) == 7u,  "PkB must be exactly 7 bytes");
_Static_assert(__builtin_offsetof(struct PkA, seq)   == 1u, "PkA.seq at +1");
_Static_assert(__builtin_offsetof(struct PkA, stamp) == 3u, "PkA.stamp at +3");
_Static_assert(__builtin_offsetof(struct PkA, val)   == 7u, "PkA.val at +7");
_Static_assert(__builtin_offsetof(struct PkA, flags) == 9u, "PkA.flags at +9");
_Static_assert(__builtin_offsetof(struct PkB, acc)   == 1u, "PkB.acc at +1");
_Static_assert(__builtin_offsetof(struct PkB, delta) == 5u, "PkB.delta at +5");
/* The negative result itself, asserted rather than described: on this target `packed` removes
   nothing, because there was nothing to remove. (On a host with 2/4-byte scalar alignment
   these DO differ — so the assertions below are target-conditional.) */
#if defined(__mos__)
_Static_assert(sizeof(struct PkAPlain) == sizeof(struct PkA),
               "MOS: packed must be a layout no-op (every scalar already has alignment 1)");
_Static_assert(sizeof(struct PkBPlain) == sizeof(struct PkB), "MOS: same for PkB");
_Static_assert(_Alignof(uint16_t) == 1u, "MOS: uint16_t alignment is 1");
_Static_assert(_Alignof(uint32_t) == 1u, "MOS: uint32_t alignment is 1");
#endif

static uint8_t  pk_blob[PK_BYTES];
static uint16_t pk_off[PK_MAX];      /* each record's absolute start offset */
static uint8_t  pk_shape[PK_MAX];    /* 0 = A, 1 = B                        */
static uint32_t pk_field[PK_MAX][4]; /* the parsed fields, shape-dependent  */
static uint16_t pk_n;
static uint16_t pk_na, pk_nb;
static uint16_t pk_odd_wide;         /* wide reads landing at odd offsets   */
static uint32_t pk_check;            /* running sum of every parsed field   */

static uint16_t pk_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}

static void pk_reset(void) {
    uint16_t s = (uint16_t)0x4D2Bu;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)PK_BYTES; i++) {
        s = (uint16_t)(pk_mul(s, (uint16_t)25173u) + (uint16_t)13849u);
        pk_blob[i] = (uint8_t)((s >> 7) & 0xFFu);
    }
    pk_n = pk_na = pk_nb = (uint16_t)0u;
    pk_odd_wide = (uint16_t)0u;
    pk_check = (uint32_t)0u;
    for (uint16_t r = (uint16_t)0u; r < (uint16_t)PK_MAX; r++) {
        pk_off[r] = (uint16_t)0u;
        pk_shape[r] = (uint8_t)0u;
        for (uint8_t f = (uint8_t)0u; f < (uint8_t)4u; f++) pk_field[r][f] = (uint32_t)0u;
    }
}

// Parse ONE record at an arbitrary byte offset. noinline and taking the offset as a parameter
// so the compiler cannot fold the record pointer to a known alignment or a known shape — the
// whole point is that the wide members are read from an offset it does not know.
__attribute__((noinline))
static uint8_t pk_parse_at(uint16_t off) {
    uint8_t tag = pk_blob[off];
    if (tag & (uint8_t)1u) {
        const struct PkA *r = (const struct PkA *)(const void *)(pk_blob + off);
        uint16_t seq   = r->seq;      /* +1  */
        uint32_t stamp = r->stamp;    /* +3  */
        uint16_t val   = r->val;      /* +7  */
        uint8_t  flags = r->flags;    /* +9  */
        if (pk_n < (uint16_t)PK_MAX) {
            pk_off[pk_n]   = off;
            pk_shape[pk_n] = (uint8_t)0u;
            pk_field[pk_n][0] = (uint32_t)seq;
            pk_field[pk_n][1] = stamp;
            pk_field[pk_n][2] = (uint32_t)val;
            pk_field[pk_n][3] = (uint32_t)flags;
            pk_n = (uint16_t)(pk_n + 1u);
        }
        pk_check = (uint32_t)(pk_check + (uint32_t)seq + stamp + (uint32_t)val
                              + (uint32_t)flags);
        if ((uint16_t)(off + 1u) & 1u) pk_odd_wide = (uint16_t)(pk_odd_wide + 1u);
        if ((uint16_t)(off + 3u) & 1u) pk_odd_wide = (uint16_t)(pk_odd_wide + 1u);
        if ((uint16_t)(off + 7u) & 1u) pk_odd_wide = (uint16_t)(pk_odd_wide + 1u);
        pk_na = (uint16_t)(pk_na + 1u);
        return (uint8_t)sizeof(struct PkA);
    } else {
        const struct PkB *r = (const struct PkB *)(const void *)(pk_blob + off);
        uint32_t acc   = r->acc;      /* +1 */
        uint16_t delta = r->delta;    /* +5 */
        if (pk_n < (uint16_t)PK_MAX) {
            pk_off[pk_n]   = off;
            pk_shape[pk_n] = (uint8_t)1u;
            pk_field[pk_n][0] = acc;
            pk_field[pk_n][1] = (uint32_t)delta;
            pk_field[pk_n][2] = (uint32_t)0u;
            pk_field[pk_n][3] = (uint32_t)0u;
            pk_n = (uint16_t)(pk_n + 1u);
        }
        pk_check = (uint32_t)(pk_check + acc + (uint32_t)delta);
        if ((uint16_t)(off + 1u) & 1u) pk_odd_wide = (uint16_t)(pk_odd_wide + 1u);
        if ((uint16_t)(off + 5u) & 1u) pk_odd_wide = (uint16_t)(pk_odd_wide + 1u);
        pk_nb = (uint16_t)(pk_nb + 1u);
        return (uint8_t)sizeof(struct PkB);
    }
}

// Walk the whole stream. Records are 7 or 10 bytes, so the cursor's parity alternates
// irregularly and most wide fields land at odd absolute offsets.
__attribute__((noinline))
static void pk_run(void) {
    uint16_t off = (uint16_t)0u;
    while ((uint16_t)(off + 10u) <= (uint16_t)PK_BYTES && pk_n < (uint16_t)PK_MAX) {
        uint8_t step = pk_parse_at(off);
        off = (uint16_t)(off + (uint16_t)step);
    }
}

static uint16_t pk_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(pk_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}

static uint16_t pk_mix32(uint16_t h, uint32_t v) {
    h = pk_mix(h, (uint16_t)(v & 0xFFFFu));
    return pk_mix(h, (uint16_t)((v >> 16) & 0xFFFFu));
}

// --------------------------------------------------------------------------
// Differential gate: parse the whole stream, fold every field.
// --------------------------------------------------------------------------
static uint16_t packrec_gate_crc(void) {
    uint16_t h = (uint16_t)0x2A76u;
    pk_reset();
    pk_run();
    h = pk_mix(h, pk_n);
    h = pk_mix(h, pk_na);
    h = pk_mix(h, pk_nb);
    h = pk_mix(h, pk_odd_wide);
    h = pk_mix32(h, pk_check);
    for (uint16_t r = (uint16_t)0u; r < pk_n; r++) {
        h = pk_mix(h, pk_off[r]);
        h = pk_mix(h, (uint16_t)pk_shape[r]);
        for (uint8_t f = (uint8_t)0u; f < (uint8_t)4u; f++)
            h = pk_mix32(h, pk_field[r][f]);
    }
    return h;
}

/* Cross-checks the gate asserts: both record shapes must actually occur, and wide members
   must actually land at odd absolute offsets — a stream that happened to be all-A at even
   offsets would compile the same code and prove nothing about the layout. */
static uint16_t pk_odd_wide_reads(void) { return pk_odd_wide; }

#endif /* PACKREC_H */
