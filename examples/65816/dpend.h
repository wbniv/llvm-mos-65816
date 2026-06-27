// Shared double-pendulum physics — the single source of truth for the host oracle
// (tools/dpend-sim.c), corpus differential slice (examples/snes/corpus/dpend_sim.c),
// and the on-screen renderer (examples/snes/double-pendulum.c).
//
// Equations of motion (m1=m2=1, L1=L2=1):
//   Δ = θ₁ − θ₂,   D = 3 − cos(2Δ)
//   N₁ = −3g·sin θ₁ − g·sin(θ₁−2θ₂) − 2·sin Δ·(ω₂²+ω₁²·cos Δ)
//   N₂ = 2·sin Δ·(2·ω₁² + 2g·cos θ₁ + ω₂²·cos Δ)
//   α₁ = N₁/D,  α₂ = N₂/D   (semi-implicit Euler: ω += α, then θ += ω)
//
// Integer representation:
//   th1, th2  uint8_t   LUT indices (0..255 = 0..2π)
//   om1, om2  int16_t   angular velocity × DP_VSCALE;
//                       theta updates as th += (int8_t)(om >> DP_VSHIFT)
//
// SINCOS LUT: DPEND_SIN[a] = round(256 * sin(2π·a/256)) ∈ [−256,256]
//   cos(a) = DPEND_SIN[(a+64)&255]   (same table, quarter-cycle offset)
//
// Codegen under test: five LUT loads per step + two int16×int16→int32 products
// (__mulsi3) for ω² coupling + one int32÷int16 signed divide (__divsi3) for the
// common denominator D + rep/sep mode-switch brackets under +mos-a16.
//
// No hardware here — host-linkable. All widths explicit (bare int is 16-bit on target).
// See docs/plans/2026-06-27-14-snes-double-pendulum.md.
#ifndef DPEND_H
#define DPEND_H

#include <stdint.h>

// Inline 256-entry Q8.8 sine LUT (identical values to SPIRO_SIN_LUT in spiro.h).
static const int16_t DPEND_SIN[256] = {
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

#define DPEND_SIN_LUT(a) (DPEND_SIN[(uint8_t)(a)])
#define DPEND_COS_LUT(a) (DPEND_SIN[(uint8_t)((uint8_t)(a) + 64u)])

// Physics constants (tuned so gravity gives a ~200-frame period at 90° starting angle,
// coupling at max clamp is comparable in magnitude to gravity — the chaotic regime).
#define DP_G        8    // gravity constant (scaled by 1/256 via LUT)
#define DP_VSHIFT   8    // theta update: th += (int8_t)(om >> DP_VSHIFT)
#define DP_SQ_SHF   4    // om_s = om >> DP_SQ_SHF before squaring (avoids int32 overflow)
#define DP_COUP_SHF 5    // coupling numerator >> DP_COUP_SHF before dividing by D
#define DP_OM_MAX   1024 // clamp |om| to prevent runaway (int16_t safe: ≤ 32767)

// Gate parameters
#define DP_GATE_N   256  // number of integration steps for the gate CRC

typedef struct {
    uint8_t  th1, th2;   // pendulum angles (LUT indices)
    int16_t  om1, om2;   // angular velocities (fixed-point, see DP_VSHIFT)
} dp_state_t;

// One semi-implicit Euler step.  Semi-implicit: update velocities first, then positions.
// noinline: keeps live-set bounded in the renderer's a16/xy16 register budget (handoff §4).
__attribute__((noinline))
static void dpend_step(dp_state_t *s) {
    uint8_t d    = (uint8_t)((uint8_t)s->th1 - (uint8_t)s->th2);
    uint8_t th12 = (uint8_t)((uint8_t)s->th1 - (uint8_t)(2u * (uint8_t)s->th2));

    int16_t s1    = DPEND_SIN_LUT(s->th1);         // sin θ₁
    int16_t c1    = DPEND_COS_LUT(s->th1);         // cos θ₁
    int16_t sd    = DPEND_SIN_LUT(d);              // sin Δ
    int16_t cd    = DPEND_COS_LUT(d);              // cos Δ
    int16_t s12   = DPEND_SIN_LUT(th12);           // sin(θ₁−2θ₂)
    int16_t cos2d = DPEND_COS_LUT((uint8_t)(2u * d)); // cos(2Δ)

    // D × 256 ∈ [512, 1024]: D = 3 − cos(2Δ), scaled by 256 via LUT.
    int16_t D_sc  = (int16_t)(768 - cos2d);

    // ω² coupling terms — shift om down first so om_s² fits in int32_t.
    // om_s = om >> DP_SQ_SHF, om_s_max = DP_OM_MAX >> 4 = 64, om_s² ≤ 4096.
    int16_t om1s  = (int16_t)(s->om1 >> DP_SQ_SHF);
    int16_t om2s  = (int16_t)(s->om2 >> DP_SQ_SHF);
    int32_t om1sq = (int32_t)om1s * om1s;   // ≤ 4096 (stress: __mulsi3)
    int32_t om2sq = (int32_t)om2s * om2s;   // ≤ 4096 (stress: __mulsi3)

    // N₁ numerator (gravity − coupling × sin(Δ)):
    //   grav = −3g·s1 − g·s12
    //   coup = 2·sd·(ω₂²+ω₁²·cos Δ) >> DP_COUP_SHF  (scale to match gravity magnitude)
    int32_t N1 = (int32_t)(-3) * DP_G * s1 - (int32_t)DP_G * s12
               - (((int32_t)2 * sd * (om2sq + om1sq * cd / 256)) >> DP_COUP_SHF);

    // N₂ numerator (coupling × sin(Δ) + gravity-cosine):
    //   inner = 2·ω₁² + 2g·cos θ₁ + ω₂²·cos Δ
    int32_t N2 = (((int32_t)2 * sd * (2 * om1sq + (int32_t)2 * DP_G * c1 + om2sq * cd / 256))
                 >> DP_COUP_SHF);

    // Divide by D×256 → α in om-units/step (stress: __divsi3).
    int16_t a1 = (int16_t)(N1 / D_sc);
    int16_t a2 = (int16_t)(N2 / D_sc);

    // Semi-implicit: update ω, clamp, then θ.
    int16_t new_om1 = (int16_t)(s->om1 + a1);
    int16_t new_om2 = (int16_t)(s->om2 + a2);
    if (new_om1 >  DP_OM_MAX) new_om1 =  (int16_t)DP_OM_MAX;
    if (new_om1 < -DP_OM_MAX) new_om1 = -(int16_t)DP_OM_MAX;
    if (new_om2 >  DP_OM_MAX) new_om2 =  (int16_t)DP_OM_MAX;
    if (new_om2 < -DP_OM_MAX) new_om2 = -(int16_t)DP_OM_MAX;
    s->om1 = new_om1;
    s->om2 = new_om2;
    s->th1 = (uint8_t)((uint8_t)s->th1 + (int8_t)(s->om1 >> DP_VSHIFT));
    s->th2 = (uint8_t)((uint8_t)s->th2 + (int8_t)(s->om2 >> DP_VSHIFT));
}

// Gate CRC: fold DP_GATE_N steps of pendulum evolution into a 16-bit hash.
// Starting state: th1=60, th2=50, om1=om2=0 (matching the two demo pendulums' initial conditions).
// The host oracle and the SNES corpus slice both call this; bit-identical by construction because
// the same integer code runs on both (no bare int, no UB).
static uint16_t dpend_gate_crc(void) {
    dp_state_t s;
    s.th1 = 60; s.th2 = 50; s.om1 = 0; s.om2 = 0;
    uint16_t h = 0;
    uint16_t i;
    for (i = 0; i < (uint16_t)DP_GATE_N; i++) {
        dpend_step(&s);
        // Rotate-XOR fold: mixes all four state fields.
        h = (uint16_t)((h << 1) | (h >> 15));
        h = (uint16_t)(h ^ (uint16_t)s.th1 ^ (uint16_t)((uint16_t)s.th2 << 8));
        h = (uint16_t)((h << 1) | (h >> 15));
        h = (uint16_t)(h ^ (uint16_t)s.om1);
        h = (uint16_t)(h ^ (uint16_t)s.om2);
    }
    return h;
}

#endif /* DPEND_H */
