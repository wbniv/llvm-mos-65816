// tools/trig-accuracy3.c — Phase 3 cross-width accuracy harness (HOST ONLY).
//
// The "accuracy within precision" half of the Phase 3 trig compiler-test. For the DERIVED
// (tan/asin/acos) and HYPERBOLIC (sinh/cosh/tanh) functions it reports, against the libm oracle:
//   - err16 = max |Q2.14 CORDIC      - libm|   (Phase 3 16-bit re-implementation, cordic16.h)
//   - err32 = max |Q16.16 libfixmath - libm|   (the 32-bit reference)
//   - cross = max |Q2.14 CORDIC      - Q16.16 libfixmath|   (the cross-WIDTH agreement)
//
// The 32-bit reference for the DERIVED functions is libfixmath's own fix16_tan/asin/acos; for the
// HYPERBOLIC functions libfixmath ships none, so they are DERIVED HERE from the now-compiled
// fix16_exp (sinh=(e^x-e^-x)/2, cosh=(e^x+e^-x)/2, tanh=sinh/cosh) — this is what "32-bit via the
// already-vendored fix16_exp" means in the master plan; Phase 3 is the first build to compile it.
//
// PASS gate: cross <= EPS16 per function. As in Phase 2, EPS16 is bounded by the COARSER side, not
// the Q2.14 LSB — libfixmath's tan/asin/acos inherit its ~1e-2 polynomial coarseness, while its
// fix16_exp is accurate, so the hyperbolic cross-width is much tighter than the derived one.
//
// Build (see dev/k_trig16x.sh stage 6): cc -I examples/65816 -DFIXMATH_NO_64BIT
//   -DFIXMATH_NO_HARD_DIVISION -DFIXMATH_NO_CACHE -O2 -o trig_accuracy3 tools/trig-accuracy3.c
//   examples/65816/libfixmath/{fix16.c,fix16_trig.c,fix16_sqrt.c,fix16_exp.c} -lm
//
// Plan: docs/plans/2026-06-26-trig-phase3-derived-hyperbolic.md.
#include <stdio.h>
#include <math.h>
#include <stdint.h>
#include "cordic16.h"
#include "libfixmath/fix16.h"

#define Q214 16384.0
static double q(int16_t v) { return (double)v / Q214; }
static int16_t to214(double x) { return (int16_t)lround(x * Q214); }

// 32-bit hyperbolic reference, derived from libfixmath's fix16_exp (the Phase-3 activation).
static fix16_t fix16_sinh(fix16_t x) { return (fix16_exp(x) - fix16_exp(-x)) >> 1; }
static fix16_t fix16_cosh(fix16_t x) { return (fix16_exp(x) + fix16_exp(-x)) >> 1; }
static fix16_t fix16_tanh(fix16_t x) { return fix16_div(fix16_sinh(x), fix16_cosh(x)); }

// Per-function cross-width ceilings (measured cross in comments, ~1.5x margin).
#define EPS_TAN   2.0e-2   // measured ~1.3e-2 (libfixmath tan compounds sin/cos Taylor edge error)
#define EPS_ASIN  2.0e-2   // measured ~1.0e-2 (libfixmath atan2 polynomial)
#define EPS_ACOS  2.0e-2   // measured ~1.0e-2
#define EPS_SINH  2.0e-3   // measured ~6e-4  (fix16_exp is accurate; both sides tight)
#define EPS_COSH  2.0e-3   // measured ~6e-4
#define EPS_TANH  2.0e-3   // measured ~6e-4

typedef struct { double e16, e32, cross; } acc_t;
static void upd(acc_t *a, double c16, double c32, double truev) {
  double d;
  d = fabs(c16 - truev); if (d > a->e16)   a->e16 = d;
  d = fabs(c32 - truev); if (d > a->e32)   a->e32 = d;
  d = fabs(c16 - c32);   if (d > a->cross) a->cross = d;
}

int main(void) {
  acc_t a_tan = {0}, a_asin = {0}, a_acos = {0}, a_sinh = {0}, a_cosh = {0}, a_tanh = {0};

  for (int i = -100; i <= 100; i++) {           // tan over |x| <= 1.0
    double x = i / 100.0;
    upd(&a_tan, q(cordic16_tan(to214(x))), fix16_to_dbl(fix16_tan(fix16_from_dbl(x))), tan(x));
  }
  for (int i = -95; i <= 95; i++) {             // asin over |x| <= 0.95
    double x = i / 100.0;
    upd(&a_asin, q(cordic16_asin(to214(x))), fix16_to_dbl(fix16_asin(fix16_from_dbl(x))), asin(x));
  }
  for (int i = 5; i <= 100; i++) {              // acos over x in [0.05, 1.0]
    double x = i / 100.0;
    upd(&a_acos, q(cordic16_acos(to214(x))), fix16_to_dbl(fix16_acos(fix16_from_dbl(x))), acos(x));
  }
  for (int i = -100; i <= 100; i++) {           // sinh/cosh/tanh over |x| <= 1.0
    double x = i / 100.0;
    upd(&a_sinh, q(cordic16_sinh(to214(x))), fix16_to_dbl(fix16_sinh(fix16_from_dbl(x))), sinh(x));
    upd(&a_cosh, q(cordic16_cosh(to214(x))), fix16_to_dbl(fix16_cosh(fix16_from_dbl(x))), cosh(x));
    upd(&a_tanh, q(cordic16_tanh(to214(x))), fix16_to_dbl(fix16_tanh(fix16_from_dbl(x))), tanh(x));
  }

  struct { const char *name; acc_t *a; double eps; } row[] = {
    {"tan",  &a_tan,  EPS_TAN},  {"asin", &a_asin, EPS_ASIN}, {"acos", &a_acos, EPS_ACOS},
    {"sinh", &a_sinh, EPS_SINH}, {"cosh", &a_cosh, EPS_COSH}, {"tanh", &a_tanh, EPS_TANH},
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
