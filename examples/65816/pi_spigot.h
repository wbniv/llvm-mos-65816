// Shared, PURE π spigot + Monte-Carlo math — host-linkable, no hardware.
//
// Rabinowitz-Wagon spigot (1995): produces π digits one at a time via a right-to-left carry
// sweep across a uint16 array with uint32 intermediates. Per inner-loop iteration:
//
//   x = a[i]*10 + q*i;   a[i] = x % (2*i-1);   q = x / (2*i-1)
//
// Codegen stress: 32-bit multiply (q*i) + __udivsi3/__umodsi3 (32÷32) × PI_ELEMS per digit.
// All arithmetic stays uint32 so the same source produces identical results on both
//   host (int=32, uint32=native) and 65816 target (int=16, uint32=two-word ops).
//
// Monte-Carlo: xorshift16 RNG → dart (x,y) in [−32768,32767]² → hit if x²+y² ≤ 0x40000000.
// The 16×16→32 squares stress +mos-a16 native-width multiply.
//
// No hardware here (no snes.h, no MMIO). See docs/plans/2026-06-27-19-snes-pi-spigot-montecarlo.md.
#ifndef PI_SPIGOT_H
#define PI_SPIGOT_H

#include <stdint.h>

// ---------------------------------------------------------------------------------------------
// Configuration

// PI_DIGITS: how many output digits the on-screen demo emits (use this for the App state).
#ifndef PI_DIGITS
#define PI_DIGITS  200
#endif
// Array size: ceil(10/3 * PI_DIGITS) + padding. 200 digits → PI_ELEMS = 676.
#define PI_ELEMS   ((PI_DIGITS * 10 / 3) + 10)

// Iterations of the carry-sweep loop per call to pi_spigot_sweep(). Controls the
// digits-per-second rate. ceil(PI_ELEMS / SWEEP_PER_CALL) calls → one output digit.
// At 150 iters/call × ~250 cycles/iter = ~37 500 cyc/call ≈ 63% of the 60fps budget.
#ifndef SWEEP_PER_CALL
#define SWEEP_PER_CALL 150
#endif

// MC dart throws per call to throw_and_plot() in the demo. 64 × ~150 cyc ≈ 9 600 cyc/call.
#ifndef MC_PER_CALL
#define MC_PER_CALL 64
#endif

// Gate constants (separate from the display-quality PI_DIGITS to keep the gate fast).
// PI_GATE_DIGITS: digits to run in pi_gate_crc() — smaller = faster, still exercises the
// full code path (all __udivsi3, __mulsi3, rep/sep paths are hit even on digit 1).
// Empirical timing on SNES (8-bit slow-ROM, 44 667 cycles/frame):
//   Spigot  1 digit × 675 iters × ~7 000 cyc/iter = ~112 frames
//   MC      2048 throws × ~3 500 cyc/throw = ~163 frames (signed 16-bit inputs sign-extend
//           to 32-bit, hitting the slow 24–32 iteration path in __mulsi3)
//   → PI_GATE_DIGITS=1, PI_GATE_THROWS=256 ≈ 112 + 10 = 122 frames, fits comfortably in
//     both the 180-frame corpus-a16 window and the 500-frame pi gate window.
//   (10 digits + 2048 throws ≈ 1200 frames — way over the pi gate limit.)
#define PI_GATE_DIGITS  1u
#define PI_GATE_THROWS  256u

// ---------------------------------------------------------------------------------------------
// Spigot state (all bank-0, NEAR — no far pointers → builds default+a16+xy16)

typedef struct {
    uint16_t a[PI_ELEMS]; // register array; a[0]=0, a[1..n]=2; a[i] < 2*i-1 after step 1
    uint32_t q;           // running carry across frames (for partial-sweep mode)
    int16_t  sweep_i;     // current loop index (PI_ELEMS-1 downto 0; reset per digit)
    int16_t  predigit;    // held-back output digit; -1 = no output pending yet
    int16_t  nines;       // count of buffered 9s (waiting for carry resolution)
    uint16_t n;           // digits emitted so far (not counting the predigit in flight)
    uint8_t  outq[8];     // burst output queue (carry events emit multiple digits at once)
    uint8_t  oqh, oqt;   // ring-buffer head / tail (indices mod 8)
} pi_spigot_state;

// ---------------------------------------------------------------------------------------------
// Spigot: init + partial-sweep

static void pi_spigot_init(pi_spigot_state *s) {
    s->a[0] = 0;  /* a[0] starts at 0; only a[1..n] = 2 (Rabinowitz-Wagon §3) */
    for (int16_t i = 1; i < (int16_t)PI_ELEMS; i++) s->a[i] = 2;
    s->q        = 0;
    s->sweep_i  = (int16_t)(PI_ELEMS - 1);
    s->predigit = -1;
    s->nines    = 0;
    s->n        = 0;
    s->oqh      = 0;
    s->oqt      = 0;
}

static inline void _pi_enqueue(pi_spigot_state *s, uint8_t d) {
    s->outq[s->oqt & 7u] = d; s->oqt++;
}

// Dequeue one output digit. Returns -1 if queue empty.
static inline int16_t pi_dequeue(pi_spigot_state *s) {
    if (s->oqh == s->oqt) return -1;
    uint8_t d = s->outq[s->oqh & 7u]; s->oqh++; return (int16_t)d;
}

// Run up to `iters` iterations of the carry-sweep loop. When a sweep completes
// (sweep_i reaches 0 → digit resolution), produces 0 or more output digits into the
// queue and re-arms sweep_i for the next digit.
//
// The inner loop — x = a[i]*10 + q*i; a[i] = x%(2i-1); q = x/(2i-1) — is the codegen
// hot path: one 32-bit multiply (q*i), one __udivsi3, one __umodsi3 per iteration.
__attribute__((noinline, unused))
static int pi_spigot_sweep(pi_spigot_state *s, int16_t iters) {
    if (s->n >= PI_DIGITS) return 0;
    int nout = 0;
    while (iters > 0) {
        if (s->sweep_i > 0) {
            int16_t i = s->sweep_i;
            uint32_t x = (uint32_t)s->a[i] * 10u + s->q * (uint32_t)(unsigned)i;
            uint32_t d = (uint32_t)(2u * (unsigned)i - 1u);
            s->a[i]   = (uint16_t)(x % d);
            s->q      = x / d;
            s->sweep_i--;
            iters--;
            continue;
        }
        // sweep_i == 0: digit resolution
        uint32_t x0 = (uint32_t)s->a[0] * 10u + s->q;
        s->a[0] = (uint16_t)(x0 % 10u);
        int16_t d = (int16_t)(x0 / 10u);
        if (d == 9) {
            s->nines++;
        } else if (d > 9) {
            if (s->predigit >= 0) { _pi_enqueue(s, (uint8_t)(s->predigit + 1)); s->n++; nout++; }
            for (int16_t k = 0; k < s->nines; k++) { _pi_enqueue(s, 0); s->n++; nout++; }
            s->predigit = 0; s->nines = 0;
        } else {
            if (s->predigit >= 0) { _pi_enqueue(s, (uint8_t)s->predigit); s->n++; nout++; }
            for (int16_t k = 0; k < s->nines; k++) { _pi_enqueue(s, 9); s->n++; nout++; }
            s->predigit = d; s->nines = 0;
        }
        s->sweep_i = (int16_t)(PI_ELEMS - 1);
        s->q       = 0;
    }
    return nout;
}

// Flush the final predigit (call when n == PI_DIGITS to emit the last held-back digit).
__attribute__((unused))
static void pi_spigot_flush(pi_spigot_state *s) {
    if (s->predigit < 0) return;
    for (int16_t k = 0; k < s->nines; k++) { _pi_enqueue(s, 9); s->n++; }
    _pi_enqueue(s, (uint8_t)s->predigit);
    s->predigit = -1; s->nines = 0;
}

// ---------------------------------------------------------------------------------------------
// Monte-Carlo state

typedef struct {
    uint16_t rng;
    uint32_t hits;
    uint32_t total;
} mc_state;

static inline void mc_init(mc_state *m, uint16_t seed) {
    m->rng = seed ? seed : 0xBEEF; m->hits = 0; m->total = 0;
}

static inline uint16_t _mc_rng16(mc_state *m) {
    uint16_t x = m->rng;
    x ^= (uint16_t)(x << 7); x ^= (uint16_t)(x >> 9); x ^= (uint16_t)(x << 8);
    m->rng = x; return x;
}

// Throw one dart. Returns 1 if inside unit circle, 0 if outside.
// The 16×16→32 squares stress +mos-a16 native multiply.
static inline int mc_throw_one(mc_state *m) {
    int16_t x = (int16_t)_mc_rng16(m), y = (int16_t)_mc_rng16(m);
    int32_t r2 = (int32_t)x * x + (int32_t)y * y;
    int hit = (r2 <= (int32_t)0x40000000L);
    if (hit) m->hits++;
    m->total++;
    return hit;
}

// ---------------------------------------------------------------------------------------------
// CRC utilities

static inline uint16_t pi_fold(uint16_t h, uint16_t v) {
    uint16_t hi = (uint16_t)((h >> 15) & 1u);
    return (uint16_t)((((uint16_t)(h << 1)) | hi) ^ v);
}

// ---------------------------------------------------------------------------------------------
// Differential gate CRC.
//
// Takes pre-allocated state (caller provides — avoids a second 1.3KB static allocation in
// programs that already have a pi_spigot_state in their App struct).
// Re-initializes the provided state, runs PI_GATE_DIGITS spigot digits + PI_GATE_THROWS MC
// darts, and returns a 16-bit CRC. SAME computation on host and 65816 — both must agree.
//
// pi_gate_crc() runs the carry loop INLINE (not via pi_spigot_sweep) so the gate is its own
// noinline callee and doesn't compete for registers with the display loop.
__attribute__((noinline))
static uint16_t pi_gate_crc(pi_spigot_state *sp, mc_state *mc) {
    pi_spigot_init(sp);
    mc_init(mc, 0xBEEF);
    uint16_t h = 0;

    // PI_GATE_DIGITS full sweeps. Each sweep = one pass through all PI_ELEMS elements.
    // We fold the raw pre-buffered value (x0/10) rather than the predigit-delayed output —
    // simpler, still sensitive to any miscompile in the carry chain / divide / multiply.
    for (uint16_t di = 0; di < (uint16_t)PI_GATE_DIGITS; di++) {
        uint32_t q = 0;
        for (int16_t i = (int16_t)(PI_ELEMS - 1); i > 0; i--) {
            uint32_t x = (uint32_t)sp->a[i] * 10u + q * (uint32_t)(unsigned)i;
            uint32_t d = (uint32_t)(2u * (unsigned)i - 1u);
            sp->a[i] = (uint16_t)(x % d);
            q = x / d;
        }
        uint32_t x0 = (uint32_t)sp->a[0] * 10u + q;
        sp->a[0] = (uint16_t)(x0 % 10u);
        h = pi_fold(h, (uint16_t)(x0 / 10u));
    }

    // MC gate: PI_GATE_THROWS dart throws.
    for (uint16_t k = 0; k < (uint16_t)PI_GATE_THROWS; k++)
        h = pi_fold(h, (uint16_t)(uint32_t)mc_throw_one(mc));
    h = pi_fold(h, (uint16_t)(mc->hits ^ mc->total));
    return h;
}

#endif /* PI_SPIGOT_H */
