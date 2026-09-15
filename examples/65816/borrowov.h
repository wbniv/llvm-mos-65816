// Reservoir Ladder (#144) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster A. The corner: **`G_USUBO` / `G_SSUBO`**
// (MOSLegalizerInfo.cpp:296 rule; custom cases at :2031 / :2034) — subtract-with-overflow,
// which the backend lowers separately from the add forms.
//
// A coverage audit of demos #1-#141 found `__builtin_sub_overflow` used **zero** times
// tree-wide, while `__builtin_add_overflow` appears 7x (#44 hdr-bloom) and
// `__builtin_mul_overflow` 14x (#76 smulorbit, #101 mulov64). The sub forms are not the add
// forms rotated: for the unsigned case the interesting flag is a BORROW out, the inverse sense
// of the carry the add form tests, and for the signed case the overflow predicate is a
// different sign-agreement test (operands of OPPOSITE sign can overflow a subtract, operands
// of the SAME sign cannot — exactly backwards from add).
//
// MECHANISM: a cascade of reservoirs draining into each other. Every transfer is a checked
// subtract from the source and a checked add into the destination; a detected underflow is a
// FIRST-CLASS event — the transfer is rejected, the source bounces, and the schedule moves on.
// Three widths run at once so all four lowerings are compiled in one ROM:
//   * uint16_t  -> G_USUBO, borrow out of a 16-bit subtract
//   * int16_t   -> G_SSUBO at the native accumulator width
//   * int32_t   -> G_SSUBO at double width (a limb-wise subtract plus a sign test)
// and the unsigned 16-bit level is deliberately driven to the 0 boundary and the signed one to
// both INT16_MIN and INT16_MAX, so each predicate is evaluated on both sides of its edge.
//
// DIFFERENTIAL: the folded value is the OUTCOME — the accept/reject counts, the event trace
// and the final level vectors — never a raw undefined quantity. `__builtin_sub_overflow` is
// fully standard-defined (it computes the infinite-precision difference and reports whether it
// fits), so host and target must agree bit-for-bit.
// WIDTH DISCIPLINE: explicit uint8/16/32; every multiply goes through uint32_t.
// See docs/plans/2026-09-16-round8-unentered-backend-paths.md.

#ifndef BORROWOV_H
#define BORROWOV_H

#include <stdint.h>

#define BO_N      12u    /* reservoirs                       */
#define BO_TICKS 240u    /* scheduled transfers per gate run  */
#define BO_TRACE 240u    /* recorded events                   */

static uint16_t bo_u16[BO_N];      /* unsigned levels  — G_USUBO (borrow)        */
static int16_t  bo_s16[BO_N];      /* signed levels    — G_SSUBO, native width   */
static int32_t  bo_s32[BO_N];      /* signed levels    — G_SSUBO, double width   */

static uint16_t bo_accept_u, bo_reject_u;
static uint16_t bo_accept_s, bo_reject_s;
static uint16_t bo_accept_l, bo_reject_l;
static uint8_t  bo_event[BO_TRACE];   /* per-tick: bit0 u16 reject, bit1 s16, bit2 s32 */
static uint8_t  bo_src[BO_TRACE];     /* which reservoir was drained (for the visual)  */
static uint16_t bo_nevent;

static uint16_t bo_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}

static void bo_reset(void) {
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BO_N; i++) {
        bo_u16[i] = (uint16_t)((uint16_t)(i * (uint16_t)97u) + (uint16_t)140u);
        bo_s16[i] = (int16_t)((int16_t)((int16_t)i * (int16_t)1103) - (int16_t)6000);
        bo_s32[i] = (int32_t)((int32_t)i * (int32_t)91733 - (int32_t)500000);
    }
    bo_accept_u = bo_reject_u = (uint16_t)0u;
    bo_accept_s = bo_reject_s = (uint16_t)0u;
    bo_accept_l = bo_reject_l = (uint16_t)0u;
    bo_nevent = (uint16_t)0u;
}

// ONE scheduled transfer, in all three widths. noinline so the three checked subtracts stay
// live together under real register pressure instead of being scattered by the inliner.
__attribute__((noinline))
static uint8_t bo_transfer(uint8_t src, uint8_t dst, uint16_t amt) {
    uint8_t ev = (uint8_t)0u;

    /* --- unsigned 16-bit: the interesting flag is a BORROW out of the subtract --- */
    uint16_t nu;
    if (__builtin_sub_overflow(bo_u16[src], amt, &nu)) {
        ev = (uint8_t)(ev | (uint8_t)1u);                 /* underflow: reject, bounce */
        bo_reject_u = (uint16_t)(bo_reject_u + 1u);
        bo_u16[src] = (uint16_t)(bo_u16[src] + (uint16_t)(amt >> 2));
    } else {
        bo_u16[src] = nu;
        bo_u16[dst] = (uint16_t)(bo_u16[dst] + amt);
        bo_accept_u = (uint16_t)(bo_accept_u + 1u);
    }

    /* --- signed 16-bit ---------------------------------------------------------------
       The signed reservoir is TOPPED UP by subtracting a NEGATIVE amount, which is exactly
       the operand pairing that can overflow a subtract (opposite signs) and cannot overflow
       an add — the pairing #44's __builtin_add_overflow could never produce. The source
       climbs toward INT16_MAX while the destination is drained toward INT16_MIN, so both
       edges of the predicate are crossed repeatedly over the schedule. */
    int16_t ns;
    int16_t samt = (int16_t)(-(int16_t)((int16_t)(amt & 0x0FFFu) + (int16_t)3000));
    if (__builtin_sub_overflow(bo_s16[src], samt, &ns)) {
        ev = (uint8_t)(ev | (uint8_t)2u);                 /* would pass INT16_MAX */
        bo_reject_s = (uint16_t)(bo_reject_s + 1u);
        bo_s16[src] = (int16_t)(bo_s16[src] - (int16_t)9000);   /* pull back off the edge */
    } else {
        bo_s16[src] = ns;
        int16_t nd;
        if (__builtin_sub_overflow(bo_s16[dst], (int16_t)-samt, &nd)) {
            ev = (uint8_t)(ev | (uint8_t)2u);             /* would pass INT16_MIN */
            bo_reject_s = (uint16_t)(bo_reject_s + 1u);
            bo_s16[dst] = (int16_t)(bo_s16[dst] + (int16_t)9000);
        } else {
            bo_s16[dst] = nd;
            bo_accept_s = (uint16_t)(bo_accept_s + 1u);
        }
    }

    /* --- signed 32-bit: the same predicate over a limb-wise subtract, scaled so the
       int32 edges are reached on the same schedule --- */
    int32_t nl;
    int32_t lamt = (int32_t)((int32_t)samt * (int32_t)65521);
    if (__builtin_sub_overflow(bo_s32[src], lamt, &nl)) {
        ev = (uint8_t)(ev | (uint8_t)4u);
        bo_reject_l = (uint16_t)(bo_reject_l + 1u);
        bo_s32[src] = (int32_t)(bo_s32[src] - (int32_t)600000000);
    } else {
        bo_s32[src] = nl;
        int32_t nd32;
        if (__builtin_sub_overflow(bo_s32[dst], (int32_t)-lamt, &nd32)) {
            ev = (uint8_t)(ev | (uint8_t)4u);
            bo_reject_l = (uint16_t)(bo_reject_l + 1u);
            bo_s32[dst] = (int32_t)(bo_s32[dst] + (int32_t)600000000);
        } else {
            bo_s32[dst] = nd32;
            bo_accept_l = (uint16_t)(bo_accept_l + 1u);
        }
    }

    return ev;
}

// The schedule. Amounts are deliberately large enough, often enough, that the unsigned level
// is driven THROUGH zero and the signed ones to both INT16_MIN and INT16_MAX — a schedule that
// never underflows would compile the same code and prove nothing.
__attribute__((noinline))
static void bo_run(void) {
    uint16_t s = (uint16_t)0x7A31u;
    for (uint16_t t = (uint16_t)0u; t < (uint16_t)BO_TICKS; t++) {
        s = (uint16_t)(bo_mul(s, (uint16_t)25173u) + (uint16_t)13849u);
        uint8_t  src = (uint8_t)((s >> 4) % (uint16_t)BO_N);
        uint8_t  dst = (uint8_t)((uint8_t)(src + (uint8_t)1u + (uint8_t)((s >> 12) & 3u))
                                 % (uint8_t)BO_N);
        uint16_t amt = (uint16_t)((s & 0x0FFFu) + 1u);
        uint8_t  ev  = bo_transfer(src, dst, amt);
        if (bo_nevent < (uint16_t)BO_TRACE) {
            bo_event[bo_nevent] = ev;
            bo_src[bo_nevent]   = src;
            bo_nevent++;
        }
    }
}

static uint16_t bo_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(bo_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: run the schedule, fold outcomes and final levels.
// --------------------------------------------------------------------------
static uint16_t borrowov_gate_crc(void) {
    uint16_t h = (uint16_t)0x3C5Fu;
    bo_reset();
    bo_run();
    h = bo_mix(h, bo_accept_u); h = bo_mix(h, bo_reject_u);
    h = bo_mix(h, bo_accept_s); h = bo_mix(h, bo_reject_s);
    h = bo_mix(h, bo_accept_l); h = bo_mix(h, bo_reject_l);
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BO_N; i++) {
        h = bo_mix(h, bo_u16[i]);
        h = bo_mix(h, (uint16_t)bo_s16[i]);
        h = bo_mix(h, (uint16_t)((uint32_t)bo_s32[i] & 0xFFFFu));
        h = bo_mix(h, (uint16_t)(((uint32_t)bo_s32[i] >> 16) & 0xFFFFu));
    }
    for (uint16_t i = (uint16_t)0u; i < bo_nevent; i++)
        h = bo_mix(h, (uint16_t)((uint16_t)bo_event[i] | (uint16_t)((uint16_t)bo_src[i] << 8)));
    return h;
}

/* Total rejections — the visual's readout, and a cross-check that the schedule genuinely
   crosses every boundary (all-zero would mean no overflow predicate was ever true). */
static uint16_t bo_rejects(void) {
    return (uint16_t)((uint16_t)(bo_reject_u + bo_reject_s) + bo_reject_l);
}

#endif /* BORROWOV_H */
