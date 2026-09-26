#include <stdint.h>
#ifndef SNES
#include <stdio.h>
#endif

typedef float v4f __attribute__((vector_size(16)));
typedef double v2d __attribute__((vector_size(16)));

#define ARITH(NAME, TYPE, VEC, OP)                                      \
  __attribute__((noinline)) void vec_##NAME(VEC *out, const VEC *a,      \
                                            const VEC *b) {            \
    *out = *a OP *b;                                                    \
  }                                                                    \
  __attribute__((noinline)) TYPE scalar_##NAME(TYPE a, TYPE b) {         \
    return a OP b;                                                      \
  }

ARITH(addf, float, v4f, +)
ARITH(subf, float, v4f, -)
ARITH(mulf, float, v4f, *)
ARITH(divf, float, v4f, /)
ARITH(addd, double, v2d, +)
ARITH(subd, double, v2d, -)
ARITH(muld, double, v2d, *)
ARITH(divd, double, v2d, /)

/* Independent scalar calls provide lane-wise results. Bit comparison checks
   signed zero; NaNs compare by class because payload selection is unspecified. */
static int samef(float a, float b) {
  union { float f; uint32_t u; } x = {a}, y = {b};
  return x.u == y.u || ((x.u & 0x7fffffffUL) > 0x7f800000UL &&
                       (y.u & 0x7fffffffUL) > 0x7f800000UL);
}

static int samed(double a, double b) {
  union { double f; uint64_t u; } x = {a}, y = {b};
  return x.u == y.u || ((x.u & 0x7fffffffffffffffULL) > 0x7ff0000000000000ULL &&
                       (y.u & 0x7fffffffffffffffULL) > 0x7ff0000000000000ULL);
}

static const float fa[][4] = {
    {1.0f, -3.5f, 17.0f, 0.125f},
    {0.0f, -0.0f, 0x1p-149f, -0x1p-126f},
    {__builtin_inff(), -__builtin_inff(), __builtin_nanf(""), 0x1.fffffep127f}};
static const float fb[][4] = {
    {2.0f, 0.25f, -4.0f, 7.0f},
    {-0.0f, 2.0f, 2.0f, 0.5f},
    {2.0f, __builtin_inff(), 1.0f, 2.0f}};
static const double da[][2] = {
    {1.0, -3.5}, {17.0, 0.125}, {0.0, -0.0},
    {0x1p-1074, -0x1p-1022}, {__builtin_inf(), -__builtin_inf()},
    {__builtin_nan(""), 0x1.fffffffffffffp1023}};
static const double db[][2] = {
    {2.0, 0.25}, {-4.0, 7.0}, {-0.0, 2.0},
    {2.0, 0.5}, {2.0, __builtin_inf()}, {1.0, 2.0}};

#define CHECK(NAME, TYPE, VEC, A, B, N, SAME)                           \
  do {                                                                 \
    union { VEC v; TYPE lane[N]; } a, b, out;                           \
    for (unsigned row = 0; row < sizeof(A) / sizeof((A)[0]); ++row) {   \
      for (unsigned lane = 0; lane < N; ++lane) {                       \
        a.lane[lane] = (A)[row][lane];                                  \
        b.lane[lane] = (B)[row][lane];                                  \
      }                                                                \
      vec_##NAME(&out.v, &a.v, &b.v);                                   \
      for (unsigned lane = 0; lane < N; ++lane)                         \
        if (!SAME(out.lane[lane],                                      \
                  scalar_##NAME(a.lane[lane], b.lane[lane])))           \
          return 1;                                                    \
    }                                                                  \
  } while (0)

static int check(void) {
#ifndef DOUBLE_ONLY
  CHECK(addf, float, v4f, fa, fb, 4, samef);
  CHECK(subf, float, v4f, fa, fb, 4, samef);
  CHECK(mulf, float, v4f, fa, fb, 4, samef);
  CHECK(divf, float, v4f, fa, fb, 4, samef);
#endif
#ifndef FLOAT_ONLY
  CHECK(addd, double, v2d, da, db, 2, samed);
  CHECK(subd, double, v2d, da, db, 2, samed);
  CHECK(muld, double, v2d, da, db, 2, samed);
  CHECK(divd, double, v2d, da, db, 2, samed);
#endif
  return 0;
}

volatile uint16_t corpus_result;

int main(void) {
  int result = check();
  corpus_result = result ? 0xdead : 0x600d;
#ifdef SNES
  for (;;) {}
#else
  puts(result ? "FAIL: vector lane result" : "PASS: 96 float/double lane checks");
  return result;
#endif
}
