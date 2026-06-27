// Shared, PURE spirograph (hypotrochoid) math — the single source of truth for both the host
// oracle (tools/spiro-sim.c), the corpus differential slice (examples/snes/corpus/spiro_sim.c),
// and the on-screen renderer (examples/snes/spirograph.c). Like examples/65816/mandel.h and
// examples/65816/hopalong.h, this is the code under test for the differential: the SAME body runs
// on the host oracle (int = 32) and the 65816 target (int = 16), so host == target bit-for-bit by
// construction. Keep every width cast load-bearing.
//
//   x(t) = (R-r)cos t + d cos((R-r)/r . t)    y(t) = (R-r)sin t - d sin((R-r)/r . t)   (hypotrochoid)
//
// The demo renders this curve into a NEAR tiled bitmap canvas (no far pointers), so the program
// builds default-8-bit AND +mos-a16 AND +mos-xy16 and earns the full 5-way differential bar.
//
// The codegen this stresses: a sin/cos-LUT inner loop + two 16x16->32 fixed-point multiplies +
// 32-bit add/shift per plotted point (the HOT path), plus a 32-bit divide + gcd per parameter
// change (the COLD path). All integer => host == target.
//
// NO hardware here (no snes.h, no MMIO) — host-linkable. Self-contained (LUT inline, the
// mandel.h / hopalong.h idiom). See docs/plans/2026-06-27-11-snes-spirograph-hypotrochoid.md.
#ifndef SPIRO_H
#define SPIRO_H

#include <stdint.h>

// Keep each stamped function a separate noinline callee so its live range is bounded: under
// -Os the compiler otherwise inlines spiro_point's two 32-bit products + four LUT loads + the
// accumulators into one giant main(), and the combined +mos-a16/+mos-xy16 register pressure
// overflows the imaginary-register file (a clean-IR build that nonetheless fails the register
// allocator / -verify-machineinstrs — the handoff §4 pressure trap; same reason hopalong.h's
// HOP_FN is noinline). On the host this is a harmless attribute. Override with -DSPIRO_FN=... .
#ifndef SPIRO_FN
#define SPIRO_FN __attribute__((noinline)) static
#endif

// ---------------------------------------------------------------------------------------------
// 256-entry signed Q8.8 sine LUT: SPIRO_SIN_LUT[a] = round(256 * sin(2*pi*a/256)), range +-256
// (so 1.0 == 256). cos(a) = sin(a + 64). Identical to examples/snes/sincos.h, inlined here so the
// header is self-contained and host-linkable. Regenerate:
//   python3 -c 'import math;print(",".join(str(round(256*math.sin(2*math.pi*a/256))) for a in range(256)))'
static const int16_t SPIRO_SIN_LUT[256] = {
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
#define SPIRO_SIN(a) (SPIRO_SIN_LUT[(uint8_t)(a)])
#define SPIRO_COS(a) (SPIRO_SIN_LUT[(uint8_t)((a) + 64)])

// ---------------------------------------------------------------------------------------------
// Curve families ("more variations"): same hot loop, different term/sign/rate. mode selects.
enum { SPIRO_HYPO = 0, SPIRO_EPI = 1, SPIRO_ROSE = 2, SPIRO_LISSA = 3, SPIRO_NMODES = 4 };

// Classic gear-set preset (the differential gate's fixed params). gcd(96,36)=12 -> 8 petals.
#define SPIRO_R_CLASSIC 96
#define SPIRO_r_CLASSIC 36
#define SPIRO_d_CLASSIC 20

#define SPIRO_DT          256u   // base phase step per point (Q8.8: 256 = one LUT index = 1/256 turn)
// Points folded per mode in the differential gate. Kept small so the gate (4 modes x __mulsi3 per
// point) finishes inside the corpus runner's MAME settle window (SMOKE_SETTLE=60 frames) — 32 still
// exercises every multiply / divide / LUT / rep-sep shape in all four families (a miscompiled op
// perturbs the hash on the first point). The renderer is unbounded; this only sizes the gate.
#define SPIRO_K_GATE        32u
#define SPIRO_SHIFT         9    // hypo/epi: (amp1+amp2)*256 >> 9  -> ~screen-radius px
#define SPIRO_ROSE_SHIFT   10    // rose: rho*cos product (+-65536) >> 10 -> +-64
#define SPIRO_LISSA_AMP   110    // lissajous amplitude
#define SPIRO_LISSA_SHIFT   9

// Derived per-parameter-change state (the COLD path output). amp1/amp2 = amplitudes; da/db = the
// two phase-accumulator increments (encode the gear ratio exactly via gcd-reduction or the Q8.8
// divide); delta = lissajous phase offset; mode/shift carry the family + scale.
typedef struct {
  int16_t  amp1, amp2;
  uint16_t da, db;
  uint8_t  delta;
  uint8_t  mode;
  uint8_t  shift;
} spiro_params;

// Running per-point state (the HOT path): two 16-bit phase accumulators (wrap = mod 2*pi).
typedef struct { uint16_t acc_a, acc_b; } spiro_state;

static inline uint8_t spiro_gcd(uint8_t a, uint8_t b) {
  while (b) { uint8_t t = (uint8_t)(a % b); a = b; b = t; }
  return a ? a : 1;
}

// petals = R / gcd(R,r) — the figure's rotational symmetry (shown in the HUD; gcd stress).
static inline uint8_t spiro_petals(uint8_t R, uint8_t r) {
  return (uint8_t)(R / spiro_gcd(R, r));
}

// COLD path: derive the hot-loop params from user (R,r,d,mode). One 32-bit divide (the gear ratio)
// + a gcd — off the per-point path. R,r,d are small positive integers; r==0 guarded.
SPIRO_FN void spiro_derive(uint8_t R, uint8_t r, uint8_t d, uint8_t mode, spiro_params *p) {
  p->mode  = mode;
  p->delta = 0;
  if (r == 0) r = 1;
  if (mode == SPIRO_HYPO || mode == SPIRO_EPI) {
    int16_t num = (mode == SPIRO_EPI) ? (int16_t)(R + r) : (int16_t)(R - r);
    if (num < 0) num = (int16_t)-num;                 // hypo needs R>r; guard anyway
    p->amp1 = num;
    p->amp2 = (int16_t)d;
    p->shift = SPIRO_SHIFT;
    // gear ratio (R-+r)/r as Q8.8, one __udivsi3; dphi = dtheta * ratio
    uint16_t kphi = (uint16_t)(((uint32_t)(uint16_t)num << 8) / r);
    p->da = SPIRO_DT;
    p->db = (uint16_t)(((uint32_t)SPIRO_DT * kphi) >> 8);
  } else if (mode == SPIRO_ROSE) {
    // rho = cos(k*theta); k = R/gcd(R,r) petals (the rhodonea frequency)
    uint8_t k = spiro_petals(R, r);
    p->amp1 = 0; p->amp2 = 0;
    p->shift = SPIRO_ROSE_SHIFT;
    p->da = SPIRO_DT;
    p->db = (uint16_t)(SPIRO_DT * (uint16_t)k);
  } else { /* SPIRO_LISSA */
    uint8_t g = spiro_gcd(R, r);
    uint16_t a = (uint16_t)(R / g), b = (uint16_t)(r / g);   // reduced frequency pair
    p->amp1 = SPIRO_LISSA_AMP;
    p->amp2 = SPIRO_LISSA_AMP;
    p->shift = SPIRO_LISSA_SHIFT;
    p->da = (uint16_t)(SPIRO_DT * a);
    p->db = (uint16_t)(SPIRO_DT * b);
    p->delta = (uint8_t)(d & 0xFF);                          // d -> phase offset
  }
}

// HOT path: advance one point and return its (x,y) curve coordinate (signed, centred on 0).
// The two 16x16->32 multiplies (__mulsi3) + 32-bit add/shift are the declared stress.
SPIRO_FN void spiro_point(spiro_state *s, const spiro_params *p, int16_t *ox, int16_t *oy) {
  s->acc_a = (uint16_t)(s->acc_a + p->da);
  s->acc_b = (uint16_t)(s->acc_b + p->db);
  uint8_t ia = (uint8_t)(s->acc_a >> 8);
  uint8_t ib = (uint8_t)(s->acc_b >> 8);
  int16_t x, y;
  if (p->mode == SPIRO_HYPO) {
    int16_t ca = SPIRO_COS(ia), sa = SPIRO_SIN(ia), cb = SPIRO_COS(ib), sb = SPIRO_SIN(ib);
    x = (int16_t)(((int32_t)p->amp1 * ca + (int32_t)p->amp2 * cb) >> p->shift);
    y = (int16_t)(((int32_t)p->amp1 * sa - (int32_t)p->amp2 * sb) >> p->shift);
  } else if (p->mode == SPIRO_EPI) {
    int16_t ca = SPIRO_COS(ia), sa = SPIRO_SIN(ia), cb = SPIRO_COS(ib), sb = SPIRO_SIN(ib);
    x = (int16_t)(((int32_t)p->amp1 * ca - (int32_t)p->amp2 * cb) >> p->shift);
    y = (int16_t)(((int32_t)p->amp1 * sa - (int32_t)p->amp2 * sb) >> p->shift);
  } else if (p->mode == SPIRO_ROSE) {
    int16_t rho = SPIRO_COS(ib);                             // cos(k*theta) — the radius
    int16_t ca = SPIRO_COS(ia), sa = SPIRO_SIN(ia);
    x = (int16_t)(((int32_t)rho * ca) >> p->shift);          // LUT x LUT product (distinct shape)
    y = (int16_t)(((int32_t)rho * sa) >> p->shift);
  } else { /* SPIRO_LISSA */
    int16_t sx = SPIRO_SIN((uint8_t)(ia + p->delta));
    int16_t sy = SPIRO_SIN(ib);
    x = (int16_t)(((int32_t)p->amp1 * sx) >> p->shift);
    y = (int16_t)(((int32_t)p->amp2 * sy) >> p->shift);
  }
  *ox = x; *oy = y;
}

// Cheap 16-bit rotate-left-xor rolling hash (the img_hash16 idiom from mandel.h/hopalong.h): no
// per-byte inner loop, so the gate runs in well under a second even at -Os on the SNES. Folds the
// full 16 bits of each coordinate. Proof channel: host hash == target hash over the same stream.
static inline uint16_t spiro_fold(uint16_t h, int16_t v) {
  uint16_t hi = (uint16_t)((h >> 15) & 1u);
  return (uint16_t)((((uint16_t)(h << 1)) | hi) ^ (uint16_t)v);
}

// The differential gate: thread one rolling hash over K_GATE points of EACH mode at the classic
// preset. A codegen defect in any curve family (any multiply/divide/LUT shape) perturbs the hash.
SPIRO_FN uint16_t spiro_gate_crc(void) {
  static const uint8_t modes[SPIRO_NMODES] = { SPIRO_HYPO, SPIRO_EPI, SPIRO_ROSE, SPIRO_LISSA };
  spiro_params p;
  spiro_state  s;
  uint16_t h = 0;
  for (uint8_t m = 0; m < SPIRO_NMODES; m++) {
    spiro_derive(SPIRO_R_CLASSIC, SPIRO_r_CLASSIC, SPIRO_d_CLASSIC, modes[m], &p);
    s.acc_a = 0; s.acc_b = 0;
    for (uint16_t i = 0; i < SPIRO_K_GATE; i++) {
      int16_t x, y;
      spiro_point(&s, &p, &x, &y);
      h = spiro_fold(h, x);
      h = spiro_fold(h, y);
    }
  }
  return h;
}

#endif /* SPIRO_H */
