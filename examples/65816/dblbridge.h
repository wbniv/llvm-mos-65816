// Precision Bridge (#146) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster B. The corner: **`G_FPEXT` S32->S64 and
// `G_FPTRUNC` S64->S32** (MOSLegalizerInfo.cpp:375 / :376, both `.libcallFor`) — the
// float<->double promotion pair, lowered to `__extendsfdf2` / `__truncdfsf2`.
//
// A coverage audit of demos #1-#141 found **zero** corpus slices linking either symbol. #57
// mandel-double runs a `double` escape loop AND a `float` twin, but never converts between
// them — the only float libcall it forms on the way in is `__floatunsidf` (integer->double).
// Nothing in the battery promotes a float to a double or demotes one back.
//
// MECHANISM: the same chaotic map, iterated two ways over the same state type.
//   * LANE A — pure `float`: every intermediate is rounded to binary32.
//   * LANE B — `double` bridge: the `float` state is PROMOTED to binary64 (__extendsfdf2),
//     the whole step is computed at double precision, and the result is DEMOTED back to
//     binary32 (__truncdfsf2). One rounding at the end instead of three along the way.
// Both lanes carry identical binary32 state, and the map's constants are chosen to be
// EXACTLY representable in binary32 (r = 3.90625 = 125/32, x0 = k/32), so the two lanes
// differ ONLY in where the rounding happens. They agree for a while, then separate — and the
// step at which they first separate is a first-class output, which is exactly the quantity a
// wrong rounding mode or a fused multiply-add on either side would move.
//
// DIFFERENTIAL: correctly-rounded IEEE-754 only — `+`, `-`, `*`, and the two conversions. No
// libm, no transcendental, nothing implementation-defined. The CRC folds the `uint32_t` BIT
// PATTERN of every state of both lanes (never a printed or compared decimal), plus the
// divergence step and the disagreement count of each orbit.
//
// HOST DETERMINISM — two hazards, both closed here rather than hoped away:
//   * FMA CONTRACTION. GCC at -O2 defaults to -ffp-contract=fast and will fuse `a*b + c`
//     ACROSS statements; MOS has no FMA, so a contracted host would silently disagree. Belt
//     and braces: every host oracle compile in this cluster passes `-ffp-contract=off`, AND
//     each multiply / add / subtract below is written as its OWN statement so there is no
//     contractable expression in the first place. Do not merge these lines.
//   * EXTENDED PRECISION. x86-64 uses SSE, not x87, so binary32/binary64 are not silently
//     evaluated at 80 bits. (FLT_EVAL_METHOD == 0.)
// WIDTH DISCIPLINE: explicit uint8/16/32 for everything integral; floats are only ever
// observed through their bit patterns.
// See docs/plans/2026-09-16-round8-cluster-b-conversion-comparison-layout.md.

#ifndef DBLBRIDGE_H
#define DBLBRIDGE_H

#include <stdint.h>

#define DB_ORB    6u    /* orbits (seeds)          */
#define DB_STEPS 64u    /* iterations per orbit    */
#define DB_PLOTH 96u    /* plot height, in pixels  */

/* The map: x' = r * x * (1 - x), r = 125/32 = 3.90625 — chaotic (r < 4, orbit stays in
   [0,1]) and EXACTLY representable in binary32, so (double)DB_R_F == DB_R_D exactly and the
   two lanes differ only in intermediate rounding. */
#define DB_R_F  3.90625f
#define DB_R_D  3.90625

static uint8_t  db_ya[DB_ORB][DB_STEPS];   /* lane A trace, scaled for the visual */
static uint8_t  db_yb[DB_ORB][DB_STEPS];   /* lane B trace                        */
static uint8_t  db_div[DB_ORB];            /* first differing step, or DB_STEPS   */
static uint16_t db_dis[DB_ORB];            /* how many steps differed             */
static uint16_t db_ext_steps;              /* promotions performed (lane B steps) */

/* Observe a float as its IEEE-754 binary32 bit pattern. memcpy-free and strict-aliasing-safe
   via a union — the ONLY way this demo ever looks at a float value. */
static uint32_t db_bits(float v) {
    union { float f; uint32_t u; } c;
    c.f = v;
    return c.u;
}

/* LANE A: the whole step at binary32. Three statements, three roundings. */
__attribute__((noinline))
static float db_step_f(float x) {
    float a;
    float b;
    float c;
    a = 1.0f - x;      /* own statement: no contraction */
    b = x * a;
    c = DB_R_F * b;
    return c;
}

/* LANE B: promote (G_FPEXT -> __extendsfdf2), compute the step at binary64, demote
   (G_FPTRUNC -> __truncdfsf2). One rounding, at the end. Same three statements, same order,
   so the ONLY difference from lane A is the working precision. */
__attribute__((noinline))
static float db_step_d(float x) {
    double d;
    double a;
    double b;
    double c;
    float  y;
    d = (double)x;     /* __extendsfdf2 */
    a = 1.0 - d;
    b = d * a;
    c = DB_R_D * b;
    y = (float)c;      /* __truncdfsf2  */
    return y;
}

/* Scale a state in [0,1] to a plot row. Truncating float->int, fully specified.
   The range guard is an INTEGER sign test on the bit pattern, not a float compare: `x < 0.0f`
   would pull in __ltsf2/__gtsf2, and this demo is already 1.4 KB over the LoROM near window
   before those (see the ROM-SIZE CONSTRAINT block in examples/snes/dblbridge.c). The guard is
   belt-and-braces anyway — the logistic map with r = 125/32 < 4 has f(x) = r*x*(1-x) in
   [0, r/4] = [0, 0.9765625] for x in [0,1], so the state provably never leaves [0,1] in
   either lane and the clamp never fires. Keeping it costs nothing and keeps the float->int
   conversion free of undefined behaviour by construction rather than by argument. */
static uint8_t db_plot(float x) {
    float s;
    uint16_t v;
    if (db_bits(x) & 0x80000000u) return (uint8_t)0u;   /* negative: integer sign test */
    s = x * (float)DB_PLOTH;
    v = (uint16_t)s;
    if (v >= (uint16_t)DB_PLOTH) v = (uint16_t)(DB_PLOTH - 1u);
    return (uint8_t)v;
}

static uint16_t db_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)((uint16_t)((uint32_t)h * 25173u) + (uint16_t)13849u);
}

static uint16_t db_mix32(uint16_t h, uint32_t v) {
    h = db_mix(h, (uint16_t)(v & 0xFFFFu));
    return db_mix(h, (uint16_t)((v >> 16) & 0xFFFFu));
}

static void db_reset(void) {
    db_ext_steps = (uint16_t)0u;
    for (uint8_t o = (uint8_t)0u; o < (uint8_t)DB_ORB; o++) {
        db_div[o] = (uint8_t)DB_STEPS;
        db_dis[o] = (uint16_t)0u;
        for (uint8_t s = (uint8_t)0u; s < (uint8_t)DB_STEPS; s++) {
            db_ya[o][s] = (uint8_t)0u;
            db_yb[o][s] = (uint8_t)0u;
        }
    }
}

/* Seeds: k/32 for k = 5..10 — every one exact in binary32, so both lanes start from a state
   with no rounding history at all and the FIRST disagreement is provably the map's, not the
   seed's. Written as a const table of compile-time constants rather than computed from the
   index: `(float)(o + 5) * 0.03125f` would link __floatunsisf for no benefit, and this demo
   has no near-window budget to spare (see the ROM-SIZE CONSTRAINT block in
   examples/snes/dblbridge.c). The values are identical either way — all are exact. */
static const float db_seeds[DB_ORB] = {
    0.15625f,   /*  5/32 */
    0.1875f,    /*  6/32 */
    0.21875f,   /*  7/32 */
    0.25f,      /*  8/32 */
    0.28125f,   /*  9/32 */
    0.3125f,    /* 10/32 */
};

static float db_seed(uint8_t o) {
    return db_seeds[o];
}

// --------------------------------------------------------------------------
// Differential gate: run both lanes of every orbit, fold the bit patterns.
// --------------------------------------------------------------------------
static uint16_t dblbridge_gate_crc(void) {
    uint16_t h = (uint16_t)0x51A3u;
    db_reset();

    for (uint8_t o = (uint8_t)0u; o < (uint8_t)DB_ORB; o++) {
        float xa = db_seed(o);
        float xb = db_seed(o);

        for (uint8_t s = (uint8_t)0u; s < (uint8_t)DB_STEPS; s++) {
            xa = db_step_f(xa);
            xb = db_step_d(xb);
            db_ext_steps = (uint16_t)(db_ext_steps + 1u);

            uint32_t ba = db_bits(xa);
            uint32_t bb = db_bits(xb);

            db_ya[o][s] = db_plot(xa);
            db_yb[o][s] = db_plot(xb);

            if (ba != bb) {
                if (db_div[o] == (uint8_t)DB_STEPS) db_div[o] = s;
                db_dis[o] = (uint16_t)(db_dis[o] + 1u);
            }

            h = db_mix32(h, ba);
            h = db_mix32(h, bb);
            h = db_mix(h, (uint16_t)((uint16_t)db_ya[o][s] |
                                     (uint16_t)((uint16_t)db_yb[o][s] << 8)));
        }
        h = db_mix(h, (uint16_t)db_div[o]);
        h = db_mix(h, db_dis[o]);
    }
    h = db_mix(h, db_ext_steps);
    return h;
}

/* The earliest divergence across all orbits, and the latest. The gate asserts the earliest is
   > 0 (the lanes MUST start identical — a seed that rounds differently would make the demo
   measure the seed, not the map) and the latest is < DB_STEPS (they MUST actually separate —
   if they never did, the two lanes would be the same computation and the demo would compile
   the conversions while proving nothing about them). */
static uint8_t db_div_min(void) {
    uint8_t m = (uint8_t)DB_STEPS;
    for (uint8_t o = (uint8_t)0u; o < (uint8_t)DB_ORB; o++)
        if (db_div[o] < m) m = db_div[o];
    return m;
}

static uint8_t db_div_max(void) {
    uint8_t m = (uint8_t)0u;
    for (uint8_t o = (uint8_t)0u; o < (uint8_t)DB_ORB; o++)
        if (db_div[o] > m) m = db_div[o];
    return m;
}

#endif /* DBLBRIDGE_H */
