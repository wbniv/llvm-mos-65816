/* harmonograph.h — shared, PURE Lissajous / harmonograph math: the single source of truth for the
 * host oracle (tools/harmonograph-sim.c), the corpus differential slice
 * (examples/snes/corpus/harmonograph_sim.c), and the on-screen renderer (examples/snes/harmonograph.c).
 * Same body on host (int = 32) and the 65816 target (int = 16), so host == target bit-for-bit by
 * construction — every width cast is load-bearing.
 *
 * A lateral harmonograph: four damped pendulums, two per axis, each tracing a decaying sinusoid —
 *   x(t) = A0·sin(f0·t + p0)·e^(−d0·t) + A1·sin(f1·t + p1)·e^(−d1·t)
 *   y(t) = A2·sin(f2·t + p2)·e^(−d2·t) + A3·sin(f3·t + p3)·e^(−d3·t)
 * The two oscillators on each axis are slightly DETUNED (f1 ≈ f0·(1+ε)), so the figure slowly
 * rotates; the exponential damping makes it spiral inward and settle — "the decaying traced curve".
 *
 * Codegen under test (distinct from the undamped #11 spirograph): a sin-LUT inner loop PLUS, per
 * sample, EIGHT 16/32-bit multiplies — four amplitude products `sin·env` and four envelope-decay
 * products `env·decay` (the running exponential, a sustained fixed-point multiply + accumulation) —
 * all `__mulsi3`, plus the 32-bit shift/add. All integer ⇒ host == target. No far pointers ⇒ the
 * data lives in bank-0 WRAM ⇒ the full 5-way differential bar. See
 * docs/plans/2026-06-28-9-snes-harmonograph.md. */
#ifndef HARMONOGRAPH_H
#define HARMONOGRAPH_H

#include <stdint.h>

/* Keep the per-sample step a noinline callee so its live range is bounded — under -Os the compiler
 * otherwise inlines the eight 32-bit products + four LUT loads + accumulators into one giant main(),
 * overflowing the +mos-a16/+mos-xy16 imaginary-register file (handoff §4; same reason spiro.h's
 * SPIRO_FN is noinline). Harmless attribute on the host. */
#ifndef HARMO_FN
#define HARMO_FN __attribute__((noinline)) static
#endif

/* 256-entry signed Q8.8 sine LUT: round(256·sin(2π·a/256)), range ±256 (1.0 == 256). cos(a)=sin(a+64).
 * Identical table to spiro.h / sincos.h, inlined so the header is self-contained + host-linkable. */
static const int16_t HARMO_SIN_LUT[256] = {
     0,    6,   13,   19,   25,   31,   38,   44,   50,   56,   62,   68,   74,   80,   86,   92,
    98,  104,  109,  115,  121,  126,  132,  137,  142,  147,  152,  157,  162,  167,  172,  177,
   181,  185,  190,  194,  198,  202,  206,  209,  213,  216,  220,  223,  226,  229,  231,  234,
   237,  239,  241,  243,  245,  247,  248,  250,  251,  252,  253,  254,  255,  255,  256,  256,
   256,  256,  256,  255,  255,  254,  253,  252,  251,  250,  248,  247,  245,  243,  241,  239,
   237,  234,  231,  229,  226,  223,  220,  216,  213,  209,  206,  202,  198,  194,  190,  185,
   181,  177,  172,  167,  162,  157,  152,  147,  142,  137,  132,  126,  121,  115,  109,  104,
    98,   92,   86,   80,   74,   68,   62,   56,   50,   44,   38,   31,   25,   19,   13,    6,
     0,   -6,  -13,  -19,  -25,  -31,  -38,  -44,  -50,  -56,  -62,  -68,  -74,  -80,  -86,  -92,
   -98, -104, -109, -115, -121, -126, -132, -137, -142, -147, -152, -157, -162, -167, -172, -177,
  -181, -185, -190, -194, -198, -202, -206, -209, -213, -216, -220, -223, -226, -229, -231, -234,
  -237, -239, -241, -243, -245, -247, -248, -250, -251, -252, -253, -254, -255, -255, -256, -256,
  -256, -256, -256, -255, -255, -254, -253, -252, -251, -250, -248, -247, -245, -243, -241, -239,
  -237, -234, -231, -229, -226, -223, -220, -216, -213, -209, -206, -202, -198, -194, -190, -185,
  -181, -177, -172, -167, -162, -157, -152, -147, -142, -137, -132, -126, -121, -115, -109, -104,
   -98,  -92,  -86,  -80,  -74,  -68,  -62,  -56,  -50,  -44,  -38,  -31,  -25,  -19,  -13,   -6,
};
#define HARMO_SIN(a) (HARMO_SIN_LUT[(uint8_t)(a)])

#define HARMO_NOSC   4u    /* four damped oscillators: 0,1 → x ; 2,3 → y */
#define HARMO_SHIFT  16    /* (sin ±256)·(env ≈ ±7000) >> 16 → ≈ ±27 px per term */
/* The envelope carries ENVF extra fractional bits for a smooth decay. Bound: env·decay must fit
 * int32 — env_max = (amp_max << ENVF) and decay < 2^15, so (amp_max << ENVF) · 2^15 < 2^31 ⇒
 * amp_max << ENVF < 2^16. With amp ≤ 7200, ENVF = 2 keeps env_max ≈ 28800 (·32768 ≈ 9.4e8 ≪ 2^31). */
#define HARMO_ENVF    2

/* One damped oscillator (a pendulum). df = phase increment per sample (acc is uint16, wraps at one
 * turn = 65536; index = acc>>8); phase = initial LUT-index offset; amp = initial envelope amplitude;
 * decay = Q15 multiplicative damping per sample (<32768 ⇒ decays). */
typedef struct {
    uint16_t df;
    uint8_t  phase;
    int16_t  amp;
    uint16_t decay;
} harmo_osc;

typedef struct { harmo_osc osc[HARMO_NOSC]; } harmo_params;

/* Running state: a phase accumulator + a 32-bit envelope (Q(ENVF) extra bits) per oscillator. */
typedef struct { uint16_t acc[HARMO_NOSC]; int32_t env[HARMO_NOSC]; } harmo_state;

/* A handful of presets the renderer cycles through; the gate fixes on preset 0. Each is a classic
 * detuned-pair harmonograph: the x-pair and y-pair are near-integer frequency ratios with a small
 * detune (df+1/df+2) so the figure precesses while it decays. */
#define HARMO_NPRESETS 4u
static const harmo_params HARMO_PRESETS[HARMO_NPRESETS] = {
    /* osc = { df, phase, amp, decay } — amp ≤ 7200 keeps |x|,|y| ≤ ~64 (the canvas half-width) */
    { { { 512, 0, 7000, 32702 }, { 514, 0, 6200, 32702 },
        { 768, 64, 7000, 32702 }, { 770, 0, 6200, 32702 } } },   /* 2:3 detuned, ¼-turn y offset */
    { { { 384, 0, 7200, 32710 }, { 770, 0, 5400, 32710 },
        { 512, 32, 6800, 32710 }, { 1026, 0, 5400, 32710 } } },   /* 3:2 / 4 overtone */
    { { { 640, 0, 6800, 32695 }, { 642, 96, 6400, 32695 },
        { 640, 64, 6800, 32695 }, { 644, 0, 6400, 32695 } } },   /* near-1:1 → rotating ellipse */
    { { { 512, 0, 7200, 32715 }, { 1538, 0, 4600, 32715 },
        { 1024, 0, 6400, 32715 }, { 770, 32, 5600, 32715 } } },  /* 1:3 / 2 — busier rosette */
};

/* Load preset `idx` into params + reset the running state (envelopes to amp, accumulators to 0). */
static inline void harmo_init(harmo_state *s, harmo_params *p, uint8_t idx) {
    *p = HARMO_PRESETS[idx % HARMO_NPRESETS];
    for (uint8_t i = 0; i < HARMO_NOSC; i++) {
        s->acc[i] = 0u;
        s->env[i] = (int32_t)p->osc[i].amp << HARMO_ENVF;
    }
}

/* HOT path: advance one sample, return its (x,y) curve coordinate (signed, centred on 0). The eight
 * __mulsi3 (four sin·env amplitude products + four env·decay envelope products) + the 32-bit
 * shift/add are the declared stress. */
HARMO_FN void harmo_point(harmo_state *s, const harmo_params *p, int16_t *ox, int16_t *oy) {
    int16_t v[HARMO_NOSC];
    for (uint8_t i = 0; i < HARMO_NOSC; i++) {
        s->env[i] = (s->env[i] * (int32_t)p->osc[i].decay) >> 15;        /* exponential decay (__mulsi3) */
        s->acc[i] = (uint16_t)(s->acc[i] + p->osc[i].df);
        int16_t sn = HARMO_SIN((uint8_t)((uint8_t)(s->acc[i] >> 8) + p->osc[i].phase));
        int16_t e  = (int16_t)(s->env[i] >> HARMO_ENVF);                 /* envelope back to amp scale */
        v[i] = (int16_t)(((int32_t)sn * e) >> HARMO_SHIFT);             /* amplitude product (__mulsi3) */
    }
    *ox = (int16_t)(v[0] + v[1]);
    *oy = (int16_t)(v[2] + v[3]);
}

/* Cheap 16-bit rotate-left-xor rolling hash (the spiro.h/mandel.h idiom): folds the full 16 bits of
 * each coordinate, no per-byte inner loop. Proof channel: host hash == target hash over the stream. */
static inline uint16_t harmo_fold(uint16_t h, int16_t val) {
    uint16_t hi = (uint16_t)((h >> 15) & 1u);
    return (uint16_t)((((uint16_t)(h << 1)) | hi) ^ (uint16_t)val);
}

#define HARMO_GATE_N 256u   /* samples folded by the gate (≤ ~120 SNES frames of compute) */

/* The differential gate: thread one rolling hash over HARMO_GATE_N samples of preset 0 — a codegen
 * defect in any multiply / LUT / shift perturbs the hash on the first wrong sample. Static scratch
 * avoids a large soft-stack frame in the corpus environment. */
HARMO_FN uint16_t harmo_gate_crc(void) {
    static harmo_state s;
    static harmo_params p;
    uint16_t h = 0;
    harmo_init(&s, &p, 0u);
    for (uint16_t i = 0; i < HARMO_GATE_N; i++) {
        int16_t x, y;
        harmo_point(&s, &p, &x, &y);
        h = harmo_fold(h, x);
        h = harmo_fold(h, y);
    }
    return h;
}

#endif /* HARMONOGRAPH_H */
