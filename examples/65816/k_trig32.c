// #321 realistic kernel — the full fixed-point trig set in Q16.16, computed by the
// VENDORED libfixmath reference (examples/65816/libfixmath/, MIT, upstream 9318ccd) —
// NOT re-implemented here. This is Phase 1 of the trig compiler-test: a drop-in,
// third-party fixed-point library driven headless so the 65816 backend is exercised on
// real 32-bit integer math (fix16_mul's 16x16->32 products, the restoring-division
// fix16_div, the bit-by-bit fix16_sqrt, signed shifts, the sin Taylor loop, the atan2
// branch tree). Plan: docs/plans/2026-06-25-trig-functions-as-a-c-compiler-differential-test-1.md.
//
// Functions exercised (everything libfixmath ships): sin, cos, tan, asin, acos, atan, atan2.
//
// TWO checks, kept separate:
//  1. DIFFERENTIAL (the compiler bar): host == default(8-bit) == +mos-a16, on MAME and
//     bsnes-jg, BIT-EXACT. Works because host oracle and target compile the SAME libfixmath
//     sources with the SAME flags, so the integer arithmetic is identical down to the LSB.
//  2. ACCURACY (host-only, #ifdef HOST): each fix16 result vs libm double, within the
//     precision libfixmath's algorithms actually achieve (the Taylor sin is ~1e-3 over the
//     swept domain; see dev/k_trig32.sh for the measured per-function bounds).
//
// CRITICAL build contract (enforced by dev/k_trig32.sh, applied to BOTH host and target):
//   -DFIXMATH_NO_64BIT          fix16_mul uses 16x16->32 products (no int64; same path both legs)
//   -DFIXMATH_NO_HARD_DIVISION  fix16_div uses the uint32 restoring algorithm (the 65816 has no
//                               HW divide, and the default path uses uint64 -> would diverge)
//   -DFIXMATH_NO_CACHE          removes the 48 KB mutable static sin/atan cache (deterministic)
// Overflow detection is left ON: fix16_mul/div return the fix16_overflow sentinel on overflow
// (deterministic, no signed-overflow UB). The sweep below stays inside each function's
// non-overflowing, accurate domain so the sentinel is never hit (the HOST oracle asserts this).
//
// Driven by dev/run.sh k_trig32.
#include <stdint.h>
#include "libfixmath/fix16.h"

#define NSTEP 32               // 32 samples per function; t = k-16 spans [-16,15] (both signs,
                               // all quadrants). Heavier than the single-shot corpus tests but
                               // finishes inside the MAME settle window (dev/k_trig32.sh bumps it).

// Per-function input STEP, as Q16.16 constants, chosen so the whole sweep stays in each
// function's accurate / non-overflowing domain (see notes per line). VOLATILE so the optimizer
// must actually call libfixmath each iteration instead of constant-folding the orbit (cf.
// k_hopalong's pa/pb/pc, k_fxmul). Plain integers — no float reaches target codegen.
volatile fix16_t step_ang = 9830;   // 0.1500 -> sin/cos angle in [-2.359, 2.211] (Taylor-safe; |r|<2.57)
volatile fix16_t step_tan = 5505;   // 0.0840 -> tan angle in [-1.344, 1.260] (cos>=0.22, far from PI/2)
volatile fix16_t step_val = 3801;   // 0.0580 -> asin/acos x in [-0.928, 0.870] (away from the +-1 singularity)
volatile fix16_t step_at  = 16000;  // 0.2441 -> atan x in [-3.906, 3.662]
volatile fix16_t step_aty = 13107;  // 0.2000 -> atan2 y in [-3.2, 3.0]
volatile fix16_t step_atx = 13107;  // 0.2000 -> atan2 x in [3.0, -3.2] (with y, sweeps all 4 quadrants)

// Single source of truth for each function's swept input (used by BOTH the checksum loop and
// the HOST accuracy loop, so they can never drift). t*step is a plain int32 scale of a Q16.16.
static inline fix16_t in_ang (int32_t t) { return t * step_ang; }
static inline fix16_t in_tan (int32_t t) { return t * step_tan; }
static inline fix16_t in_val (int32_t t) { return t * step_val; }
static inline fix16_t in_atan(int32_t t) { return t * step_at;  }
static inline fix16_t in_at2y(int32_t k) { return ((int32_t)k - 16) * step_aty; }
static inline fix16_t in_at2x(int32_t k) { return (15 - (int32_t)k) * step_atx; } // != 0 where y == 0

// rotate-left-1 then xor — the k_isort/k_hopalong fold, here over 32 bits. Bit-sensitive to any
// single-bit divergence in ANY function's result between builds, which is what the differential
// needs: a one-LSB codegen bug anywhere in libfixmath surfaces as a checksum mismatch.
static inline uint32_t fold(uint32_t acc, fix16_t v) {
  acc = (uint32_t)((acc << 1) | (acc >> 31));
  return acc ^ (uint32_t)v;
}

static uint32_t trig_run(void) {
  uint32_t acc = 0xACE1ACE1u;                       // checksum seed (cf. k_isort/k_hopalong)
  for (int32_t k = 0; k < NSTEP; k++) {
    int32_t t = k - (NSTEP / 2);                     // [-16, 15]
    acc = fold(acc, fix16_sin (in_ang(t)));
    acc = fold(acc, fix16_cos (in_ang(t)));
    acc = fold(acc, fix16_tan (in_tan(t)));
    acc = fold(acc, fix16_asin(in_val(t)));
    acc = fold(acc, fix16_acos(in_val(t)));
    acc = fold(acc, fix16_atan(in_atan(t)));
    acc = fold(acc, fix16_atan2(in_at2y(k), in_at2x(k)));
  }
  return acc;
}

#ifndef TRIG_NO_MAIN
#ifdef HOST
// ---- host oracle: prints the golden checksum, plus a libm accuracy report ---------------
#include <stdio.h>
#include <math.h>

// Per-function absolute-error ceilings vs libm, in world units (radians for the inverse fns).
// These bound what libfixmath's *algorithms* actually achieve over the swept domain — they are
// NOT the Q16.16 LSB (libfixmath's Taylor sin and 3rd-order atan2 polynomial are far coarser
// than the format). Calibrated ~1.3-1.5x above the measured max error (shown in comments);
// tightening past that is a real regression gate. cos > sin because cos(x)=sin(x+PI/2) pushes
// the reduced Taylor argument toward its accurate-range edge; atan/asin/acos inherit the coarse
// atan2 polynomial; tan compounds sin/cos and the ratio amplifies it.
#if defined(FIXMATH_SIN_LUT)
// Accurate direct sin LUT (the snes-hirom far-rodata build): the sin family is now ~1 fix16
// LSB across the whole range, not just near 0 — cos/tan no longer inherit the Taylor edge error.
#define EPS_SIN   5.0e-5   // measured 8.8e-6
#define EPS_COS   5.0e-5   // measured 1.7e-5  (Taylor build: 6.2e-3)
#define EPS_TAN   5.0e-4   // measured 2.0e-4  (Taylor build: 3.1e-2)
#else
// Taylor sin (Phase 1, the 32 KiB snes build): coarse at the reduced-argument edges.
#define EPS_SIN   1.0e-4   // measured 1.5e-5
#define EPS_COS   8.0e-3   // measured 6.2e-3
#define EPS_TAN   4.0e-2   // measured 3.1e-2
#endif
// atan/asin/acos are bound by libfixmath's 3rd-order atan2 polynomial regardless of the sin path:
#define EPS_ASIN  1.5e-2   // measured 1.0e-2
#define EPS_ACOS  1.5e-2   // measured 1.0e-2
#define EPS_ATAN  8.0e-3   // measured 6.5e-3
#define EPS_ATAN2 4.0e-3   // measured 2.7e-3

static int check1(const char *name, double got, double truev, double eps,
                  double *worst, int *fail) {
  double e = got - truev; if (e < 0) e = -e;
  if (e > *worst) *worst = e;
  int bad = (e > eps);
  if (bad) *fail = 1;
  return bad;
}

int main(void) {
  uint32_t golden = trig_run();

  double w_sin=0, w_cos=0, w_tan=0, w_asin=0, w_acos=0, w_atan=0, w_at2=0;
  int fail = 0, sentinel = 0;

  for (int32_t k = 0; k < NSTEP; k++) {
    int32_t t = k - (NSTEP / 2);
    fix16_t r;
    // sentinel watch: any overflow would poison both the checksum AND the accuracy report.
    #define CK(R) do { r = (R); if (r == fix16_minimum) sentinel = 1; } while (0)

    CK(fix16_sin(in_ang(t)));   check1("sin",  fix16_to_dbl(r), sin (fix16_to_dbl(in_ang(t))),  EPS_SIN,   &w_sin,  &fail);
    CK(fix16_cos(in_ang(t)));   check1("cos",  fix16_to_dbl(r), cos (fix16_to_dbl(in_ang(t))),  EPS_COS,   &w_cos,  &fail);
    CK(fix16_tan(in_tan(t)));   check1("tan",  fix16_to_dbl(r), tan (fix16_to_dbl(in_tan(t))),  EPS_TAN,   &w_tan,  &fail);
    CK(fix16_asin(in_val(t)));  check1("asin", fix16_to_dbl(r), asin(fix16_to_dbl(in_val(t))),  EPS_ASIN,  &w_asin, &fail);
    CK(fix16_acos(in_val(t)));  check1("acos", fix16_to_dbl(r), acos(fix16_to_dbl(in_val(t))),  EPS_ACOS,  &w_acos, &fail);
    CK(fix16_atan(in_atan(t))); check1("atan", fix16_to_dbl(r), atan(fix16_to_dbl(in_atan(t))), EPS_ATAN,  &w_atan, &fail);
    CK(fix16_atan2(in_at2y(k), in_at2x(k)));
    check1("atan2", fix16_to_dbl(r), atan2(fix16_to_dbl(in_at2y(k)), fix16_to_dbl(in_at2x(k))), EPS_ATAN2, &w_at2, &fail);
    #undef CK
  }

  fprintf(stderr, "host accuracy (libfixmath fix16 vs libm, %d samples/fn, max |err|):\n", NSTEP);
  fprintf(stderr, "  sin   %.2e  (eps %.2e)\n", w_sin,  (double)EPS_SIN);
  fprintf(stderr, "  cos   %.2e  (eps %.2e)\n", w_cos,  (double)EPS_COS);
  fprintf(stderr, "  tan   %.2e  (eps %.2e)\n", w_tan,  (double)EPS_TAN);
  fprintf(stderr, "  asin  %.2e  (eps %.2e)\n", w_asin, (double)EPS_ASIN);
  fprintf(stderr, "  acos  %.2e  (eps %.2e)\n", w_acos, (double)EPS_ACOS);
  fprintf(stderr, "  atan  %.2e  (eps %.2e)\n", w_atan, (double)EPS_ATAN);
  fprintf(stderr, "  atan2 %.2e  (eps %.2e)\n", w_at2,  (double)EPS_ATAN2);
  if (sentinel)
    fprintf(stderr, "ACCURACY: FAIL (fix16_overflow sentinel hit — sweep left the valid domain)\n");
  else
    fprintf(stderr, "ACCURACY: %s\n", fail ? "FAIL (a function exceeded its eps)" : "PASS");

  printf("0x%08lX\n", (unsigned long)golden);        // the golden corpus_result (stdout)
  return 0;
}
#else
// ---- target: write the checksum to WRAM and spin while the emulator settles -------------
volatile uint32_t corpus_result;
int main(void) {
  corpus_result = trig_run();
  for (;;) __asm__ volatile("wai");
}
#endif
#endif /* TRIG_NO_MAIN */
