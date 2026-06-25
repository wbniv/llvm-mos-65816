// tools/trig-accuracy.c — Phase 2 cross-width accuracy harness (HOST ONLY).
//
// The "accuracy within precision" half of the trig compiler-test (the differential half lives in
// dev/k_trig16.sh / dev/k_trig32.sh). For the functions BOTH formats implement — sin, cos, atan,
// atan2 — it sweeps the Q2.14-representable domain and reports, against the libm double oracle:
//   - err16  = max |Q2.14 CORDIC      - libm|   (this fork's Phase-2 16-bit re-implementation)
//   - err32  = max |Q16.16 libfixmath - libm|   (Phase-1 vendored 32-bit reference)
//   - cross  = max |Q2.14 CORDIC      - Q16.16 libfixmath|   (the cross-WIDTH agreement)
//
// PASS gate: cross <= EPS16 per function. Per the plan, EPS16 is bounded by the COARSER 32-bit
// side (libfixmath's Taylor sin ~6e-3 and 3rd-order atan2 polynomial ~6e-3), NOT by the Q2.14
// LSB — the 15-iteration CORDIC is actually finer than libfixmath on atan, so the two formats can
// only be expected to agree to libfixmath's algorithmic error. This proves the 16-bit path tracks
// the established 32-bit reference across the shared domain, despite the 8x width difference.
//
// Build (see dev/k_trig16.sh stage 6):
//   cc -I examples/65816 -DFIXMATH_NO_64BIT -DFIXMATH_NO_HARD_DIVISION -DFIXMATH_NO_CACHE \
//      -O2 -o trig_accuracy tools/trig-accuracy.c \
//      examples/65816/libfixmath/{fix16.c,fix16_trig.c,fix16_sqrt.c} -lm
//
// Plan: docs/plans/2026-06-26-trig-phase2-q214-cordic.md.
#include <stdio.h>
#include <math.h>
#include <stdint.h>
#include "cordic16.h"
#include "libfixmath/fix16.h"

#define Q214 16384.0
static double q(int16_t v) { return (double)v / Q214; }
static int16_t to214(double x) { return (int16_t)lround(x * Q214); }

// Per-function cross-width ceilings: dominated by libfixmath's algorithmic coarseness (the 32-bit
// side), with ~1.5x margin over the measured cross value (shown in comments).
// cross ~ err16 + err32 (the two formats can err in opposite directions), so each ceiling bounds
// the CORDIC error plus libfixmath's algorithmic floor on that function.
#define EPS16_SIN   1.0e-2   // measured cross 4.4e-4 (libfixmath sin near-exact over [-pi/2,pi/2])
#define EPS16_COS   1.2e-2   // measured cross 7.6e-3 (libfixmath Taylor cos edge error)
#define EPS16_ATAN  1.5e-2   // measured cross 1.0e-2 (libfixmath 3rd-order atan2 polynomial)
#define EPS16_ATAN2 2.0e-2   // measured cross 1.2e-2 (atan2 polynomial + CORDIC prescale loss)

typedef struct { double e16, e32, cross; } acc_t;
static void upd(acc_t *a, double c16, double c32, double truev) {
  double d;
  d = fabs(c16 - truev);  if (d > a->e16)   a->e16 = d;
  d = fabs(c32 - truev);  if (d > a->e32)   a->e32 = d;
  d = fabs(c16 - c32);    if (d > a->cross) a->cross = d;
}

int main(void) {
  acc_t a_sin = {0}, a_cos = {0}, a_atan = {0}, a_at2 = {0};

  // sin / cos over [-pi/2, pi/2]
  for (int i = -96; i <= 96; i++) {
    double ang = i * (M_PI / 2.0) / 96.0;
    if (ang < -M_PI / 2 || ang > M_PI / 2) continue;
    upd(&a_sin, q(cordic16_sin(to214(ang))), fix16_to_dbl(fix16_sin(fix16_from_dbl(ang))), sin(ang));
    upd(&a_cos, q(cordic16_cos(to214(ang))), fix16_to_dbl(fix16_cos(fix16_from_dbl(ang))), cos(ang));
  }
  // atan over (-1.95, 1.95)
  for (int i = -195; i <= 195; i++) {
    double x = i / 100.0;
    upd(&a_atan, q(cordic16_atan(to214(x))), fix16_to_dbl(fix16_atan(fix16_from_dbl(x))), atan(x));
  }
  // atan2 over the right half-plane: x in (0,1], |y| <= 1
  for (int iy = -100; iy <= 100; iy++) {
    for (int ix = 5; ix <= 100; ix++) {
      double yy = iy / 100.0, xx = ix / 100.0;
      upd(&a_at2, q(cordic16_atan2(to214(yy), to214(xx))),
          fix16_to_dbl(fix16_atan2(fix16_from_dbl(yy), fix16_from_dbl(xx))), atan2(yy, xx));
    }
  }

  struct { const char *name; acc_t *a; double eps; } row[] = {
    {"sin",   &a_sin,  EPS16_SIN},
    {"cos",   &a_cos,  EPS16_COS},
    {"atan",  &a_atan, EPS16_ATAN},
    {"atan2", &a_at2,  EPS16_ATAN2},
  };
  int fail = 0;
  printf("cross-width accuracy (Q2.14 CORDIC vs Q16.16 libfixmath vs libm):\n");
  printf("  %-6s %10s %10s %10s %10s\n", "fn", "err16", "err32", "cross", "eps16");
  for (unsigned i = 0; i < sizeof(row) / sizeof(row[0]); i++) {
    acc_t *a = row[i].a;
    int bad = (a->cross > row[i].eps);
    if (bad) fail = 1;
    printf("  %-6s %10.2e %10.2e %10.2e %10.2e%s\n",
           row[i].name, a->e16, a->e32, a->cross, row[i].eps, bad ? "  <-- BREACH" : "");
  }
  printf("CROSS-WIDTH: %s\n", fail ? "FAIL (a function's 16-vs-32 diff exceeded eps16)" : "PASS");
  return fail ? 1 : 0;
}
