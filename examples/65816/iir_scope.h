// Shared, PURE 2-pole IIR resonator bank — host-linkable, no hardware.  Demo #48.
//
// The codegen corner: a **recursive feedback dependency chain**.  Each output sample
//   y[n] = (a1*y[n-1] + a2*y[n-2]) >> Q + x[n]
// depends on the two PREVIOUS outputs, so the compiler cannot reorder or vectorize the loop the
// way it can a feed-forward FFT (#25) — every iteration waits on the last.  Plucking a resonator
// with an impulse makes it ring: a decaying sinusoid.  A bank of four tuned resonators = a plucked
// chord on an oscilloscope.
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - filter state y1/y2 and the products are int32_t (the a1*y term needs 32 bits)
//   - the >> Q on a possibly-negative int32 is an arithmetic shift on both host and target
//   - coefficients are Q12 constants (baked, so identical on host and target)
// See docs/plans/2026-06-30-48-snes-iir-scope.md.
#ifndef IIR_SCOPE_H
#define IIR_SCOPE_H

#include <stdint.h>

// ---------------------------------------------------------------------------------------------
// Configuration

#define IIR_RES     4u        // resonators in the bank (a 4-note chord)
#define IIR_Q       12        // coefficient fixed-point fraction bits
#define SCOPE_W     128u      // oscilloscope width in samples (== BitmapCanvas width)
#define IIR_SPP     3u        // new samples generated per display frame (scroll speed)
#define IIR_PLUCK   18u       // samples between plucks (arpeggiate the chord)
#define IIR_IMPULSE 1000      // pluck impulse amplitude

// Base coefficients for r=0.99, ω = 0.15/0.20/0.25/0.30 rad/sample:
//   a1[k] = round(2*r*cos(ω_k) * 2^Q),   a2 = round(-r*r * 2^Q) = -4015 (shared).
static const int32_t iir_a1_base[IIR_RES] = { 8019, 7948, 7858, 7748 };
static const int32_t iir_a2 = -4015;

// Small vibrato LUT (Q12, one cycle over 16 steps, ±~180) added to each resonator's a1 every
// sample — a subtle runtime pitch wobble.  Because a1 is now a runtime value (a LUT load the
// compiler can't fold), the feedback multiply a1*y[n-1] is a GENUINE runtime 32-bit multiply, the
// codegen the recursive chain is meant to exercise — and the chord audibly/visibly chorus-wobbles.
static const int32_t iir_vib[16] = {
      0,   23,   42,   55,   60,   55,   42,   23,
      0,  -23,  -42,  -55,  -60,  -55,  -42,  -23,
};

// ---------------------------------------------------------------------------------------------
// State

typedef struct {
    int32_t y1[IIR_RES];      // y[n-1] per resonator
    int32_t y2[IIR_RES];      // y[n-2] per resonator
    int16_t buf[SCOPE_W];     // ring of recent summed output (the scope trace)
    uint16_t head;            // next write index (mod SCOPE_W)
    uint16_t since_pluck;     // samples since last pluck
    uint8_t  next_res;        // which resonator to pluck next (arpeggio)
    uint8_t  vib;             // vibrato LUT phase (0..15)
    uint8_t  vsub;            // vibrato sub-counter (advances vib every 8 samples → slow wobble,
                              // well below the resonator frequencies so it can't parametrically pump)
} iir_state;

static void iir_init(iir_state *s) {
    for (uint16_t k = 0; k < IIR_RES; k++) { s->y1[k] = 0; s->y2[k] = 0; }
    for (uint16_t i = 0; i < SCOPE_W; i++) s->buf[i] = 0;
    s->head = 0;
    s->since_pluck = 0;
    s->next_res = 0;
    s->vib = 0;
    s->vsub = 0;
}

// Advance one sample.  Optionally injects an impulse into one resonator on the pluck schedule.
// Returns the summed output of all resonators (the scope amplitude).
static int16_t iir_sample(iir_state *s) {
    int16_t pluck_k = -1;
    if (s->since_pluck == 0u) { pluck_k = (int16_t)s->next_res; }

    int32_t sum = 0;
    for (uint16_t k = 0; k < IIR_RES; k++) {
        // Runtime a1 = base + vibrato (a LUT load the compiler can't fold).
        int32_t a1 = iir_a1_base[k] + iir_vib[(uint8_t)((s->vib + k * 4u) & 15u)];
        // THE FEEDBACK CHAIN — y[n] from the two previous outputs (non-reorderable).
        int32_t y = (int32_t)((a1 * s->y1[k] + iir_a2 * s->y2[k]) >> IIR_Q);
        if ((int16_t)k == pluck_k) y += (int32_t)IIR_IMPULSE;
        s->y2[k] = s->y1[k];
        s->y1[k] = y;
        sum += y;
    }

    // Advance the pluck schedule + vibrato phase.
    if (s->since_pluck == 0u) s->next_res = (uint8_t)((s->next_res + 1u) % IIR_RES);
    s->since_pluck++;
    if (s->since_pluck >= IIR_PLUCK) s->since_pluck = 0u;
    s->vsub = (uint8_t)((s->vsub + 1u) & 7u);
    if (s->vsub == 0u) s->vib = (uint8_t)((s->vib + 1u) & 15u);

    // Clamp the summed trace to int16 for the scope (the sum of 4 rings can exceed a single).
    if (sum > 32000) sum = 32000; else if (sum < -32000) sum = -32000;
    return (int16_t)sum;
}

// Generate one frame's worth of samples into the ring buffer.
static void iir_frame(iir_state *s) {
    for (uint16_t i = 0; i < IIR_SPP; i++) {
        s->buf[s->head] = iir_sample(s);
        s->head = (uint16_t)((s->head + 1u) % SCOPE_W);
    }
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t iir_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_SAMPLES
#define GATE_SAMPLES 400u
#endif

static uint16_t iir_scope_gate_crc(void) {
    static iir_state s;
    iir_init(&s);
    uint16_t h = 0;
    for (uint16_t n = 0; n < (uint16_t)GATE_SAMPLES; n++)
        h = iir_fold(h, (uint16_t)iir_sample(&s));
    return h;
}

#endif /* IIR_SCOPE_H */
