// Shared, PURE constant-divisor clock + odometer — host-linkable, no hardware.  Demo #39.
//
// The codegen corner: **constant-divisor division**.  Splitting a frame counter into h:m:s and a
// counter into base-10 digits uses divides by COMPILE-TIME CONSTANTS (/60, /3600, /10, /12).
//
// MEASURED FINDING (governing lesson #1 — measure, don't assume): the demo was built to exercise
// magic-reciprocal *strength reduction* (constant divide -> multiply-high + shift).  llvm-mos does
// NOT do this at any width — even `uint16 x/10` lowers to `__udivhi3`.  The magic reciprocal needs a
// MULHU (high half of a wide multiply) which is itself a libcall on this soft-multiply target, so the
// cost model correctly RETAINS the division libcall (it can't beat it).  So what this actually
// stresses is heavy constant-divisor division via __udivNi3, and the differential proves it bit-exact
// across default/a16/xy16 — a correct cost decision, not a bug.  (Distinct from #27's runtime modulo:
// here the divisor is a compile-time constant, yet still not reduced.)
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - the counters are uint32_t; the constant divides/mods are on uint32_t (32-bit magic multiply)
//   - digit/field results are uint8_t; no bare int
// See docs/plans/2026-06-30-39-snes-divclock.md.
#ifndef DIVCLOCK_H
#define DIVCLOCK_H

#include <stdint.h>

#define CLK_FPS   60u        // frames per simulated second
#define ODO_DIGITS 6u        // base-10 odometer width

// 256-entry signed Q8.8 sine LUT (256 == 1.0); cos(a) = sin(a+64).  For the clock hands (ROM-only).
static const int16_t DC_SIN_LUT[256] = {
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
#define DC_SIN(a) (DC_SIN_LUT[(uint8_t)(a)])
#define DC_COS(a) (DC_SIN_LUT[(uint8_t)((a) + 64)])

typedef struct {
    uint32_t tick;    // frame counter (drives the clock)
    uint32_t odo;     // odometer value (base-10 rolling counter)
} dc_state;

static void dc_init(dc_state *s) { s->tick = 0u; s->odo = 0u; }

// Split the frame tick into hours(0..11) : minutes(0..59) : seconds(0..59).
// Every divide/modulo is by a COMPILE-TIME CONSTANT → magic-reciprocal multiply, not __udivsi3.
static void dc_hms(uint32_t tick, uint8_t *h, uint8_t *m, uint8_t *sec) {
    uint32_t tsec = tick / CLK_FPS;         // /60
    *sec = (uint8_t)(tsec % 60u);           // %60
    uint32_t tmin = tsec / 60u;             // /60
    *m   = (uint8_t)(tmin % 60u);           // %60
    uint32_t thr  = tmin / 60u;             // /60
    *h   = (uint8_t)(thr % 12u);            // %12
}

// Extract the ODO_DIGITS base-10 digits of v (d[0] = least significant).  Constant /10 + %10.
static void dc_digits(uint32_t v, uint8_t *d) {
    for (uint8_t i = 0; i < ODO_DIGITS; i++) {
        d[i] = (uint8_t)(v % 10u);          // %10  (magic reciprocal)
        v /= 10u;                           // /10  (magic reciprocal)
    }
}

// Angle index (0..255, 0 = 12 o'clock) for a hand at value/maxval.  Also a constant divide.
static inline uint8_t dc_hand_angle(uint16_t value, uint16_t maxval) {
    return (uint8_t)((uint32_t)value * 256u / maxval);   // /maxval (const per call site)
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t dc_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 200u
#endif

static uint16_t divclock_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t i = 0; i < (uint16_t)GATE_N; i++) {
        // Sample a wide spread of tick/odometer values so every field range is exercised.
        uint32_t tick = (uint32_t)i * 137u + 7u;
        uint8_t hh, mm, ss;
        dc_hms(tick, &hh, &mm, &ss);
        h = dc_fold(h, (uint16_t)(((uint16_t)hh << 8) | mm));
        h = dc_fold(h, (uint16_t)ss);
        h = dc_fold(h, dc_hand_angle(ss, 60u));
        h = dc_fold(h, dc_hand_angle(mm, 60u));
        h = dc_fold(h, dc_hand_angle(hh, 12u));

        uint32_t v = (uint32_t)i * 12345u + 67u;
        uint8_t d[ODO_DIGITS];
        dc_digits(v, d);
        for (uint8_t k = 0; k < ODO_DIGITS; k++) h = dc_fold(h, d[k]);
    }
    return h;
}

#endif /* DIVCLOCK_H */
