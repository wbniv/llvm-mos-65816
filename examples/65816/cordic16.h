// examples/65816/cordic16.h — Q2.14 fixed-point CORDIC: a fresh re-implementation (Phase 2 of
// the trig compiler-test), NOT a vendored library. CORDIC is SHIFT-AND-ADD only — no multiply,
// no divide — so under +mos-a16 it lowers to pure native 16-bit ALU code (rep/sep brackets, and
// crucially NO __*si3 / __*hi3 arithmetic libcalls). That is the deliberate complement to Phase 1
// (k_trig32.c), whose Q16.16 libfixmath path is 32-bit-libcall-heavy (__mulsi3 / __divsi3).
//
// Functions: cordic16_sincos / cordic16_sin / cordic16_cos (rotation mode),
//            cordic16_atan / cordic16_atan2 (vectoring mode).
//
// FORMAT: every angle and value is Q2.14 (cordic16_tables.h): raw int16, value = raw/16384,
// representable range [-2, +2). pi (3.14) does NOT fit Q2.14, so angles are kept in-format:
//   sincos(angle) : angle in [-pi/2, pi/2]       -> (cos, sin) in [-1, 1]
//   atan(x)       : x in (-2, 2)                  -> angle in (-1.107, 1.107)
//   atan2(y, x)   : x > 0, |x|,|y| <= 1.0         -> angle in (-pi/2, pi/2)
//
// TWO design constraints make this a clean differential payload:
//  1. NO int16 OVERFLOW. Rotation mode seeds x0 = 1/An so magnitude only grows 9949->16384 (<=ONE),
//     and every transient |x|+|y>>i| <= ONE*sqrt2 ~ 23170. Vectoring mode pre-halves its inputs
//     (atan2 is scale-invariant under (y,x)->(y/2,x/2)), so the gain-amplified magnitude
//     An*sqrt(x^2+y^2) <= ~30160 stays under 32767. Because no intermediate ever leaves int16,
//     host (32-bit int) and target (16-bit int) compute bit-identical results — the differential bar.
//  2. CONSTANT SHIFTS. The N=15 iteration is fully UNROLLED, so every `>> i` is a compile-time
//     constant: no variable-shift __ashrhi3 libcall, and identical codegen on host and target.
//
// Plan: docs/plans/2026-06-26-trig-phase2-q214-cordic.md.
#ifndef CORDIC16_H
#define CORDIC16_H
#include <stdint.h>
#include "cordic16_tables.h"

// One ROTATION-mode microrotation: rotate (x, y) toward residual angle z = 0 by atan(2^-i).
// dx, dy are captured from the CURRENT x, y before either is updated.
#define CORDIC16_ROT(i)                                       \
  do {                                                        \
    int16_t dx = (int16_t)(x >> (i));                         \
    int16_t dy = (int16_t)(y >> (i));                         \
    if (z >= 0) { x = (int16_t)(x - dy); y = (int16_t)(y + dx); z = (int16_t)(z - cordic16_atan_tbl[i]); } \
    else        { x = (int16_t)(x + dy); y = (int16_t)(y - dx); z = (int16_t)(z + cordic16_atan_tbl[i]); } \
  } while (0)

// sin AND cos of a Q2.14 angle in [-pi/2, pi/2], one CORDIC sweep. Seeds x0 = 1/An, y0 = 0, z0 =
// angle; after the sweep (x, y) = (cos, sin) at unit (ONE) magnitude.
static inline void cordic16_sincos(int16_t angle, int16_t *sin_out, int16_t *cos_out) {
  int16_t x = CORDIC16_K;
  int16_t y = 0;
  int16_t z = angle;
  CORDIC16_ROT(0);  CORDIC16_ROT(1);  CORDIC16_ROT(2);  CORDIC16_ROT(3);
  CORDIC16_ROT(4);  CORDIC16_ROT(5);  CORDIC16_ROT(6);  CORDIC16_ROT(7);
  CORDIC16_ROT(8);  CORDIC16_ROT(9);  CORDIC16_ROT(10); CORDIC16_ROT(11);
  CORDIC16_ROT(12); CORDIC16_ROT(13); CORDIC16_ROT(14);
  *cos_out = x;
  *sin_out = y;
}

static inline int16_t cordic16_sin(int16_t angle) {
  int16_t s, c;
  cordic16_sincos(angle, &s, &c);
  return s;
}
static inline int16_t cordic16_cos(int16_t angle) {
  int16_t s, c;
  cordic16_sincos(angle, &s, &c);
  return c;
}

// One VECTORING-mode microrotation: drive y toward 0, accumulating the rotated-away angle into z.
#define CORDIC16_VEC(i)                                       \
  do {                                                        \
    int16_t dx = (int16_t)(x >> (i));                         \
    int16_t dy = (int16_t)(y >> (i));                         \
    if (y < 0) { x = (int16_t)(x - dy); y = (int16_t)(y + dx); z = (int16_t)(z - cordic16_atan_tbl[i]); } \
    else       { x = (int16_t)(x + dy); y = (int16_t)(y - dx); z = (int16_t)(z + cordic16_atan_tbl[i]); } \
  } while (0)

// Vectoring sweep: rotate (x, y) onto the +x axis, returning the accumulated angle (= atan2(y, x)
// for x > 0). Caller pre-scales so the gain-amplified magnitude stays inside int16.
static inline int16_t cordic16_vector_angle(int16_t x, int16_t y) {
  int16_t z = 0;
  CORDIC16_VEC(0);  CORDIC16_VEC(1);  CORDIC16_VEC(2);  CORDIC16_VEC(3);
  CORDIC16_VEC(4);  CORDIC16_VEC(5);  CORDIC16_VEC(6);  CORDIC16_VEC(7);
  CORDIC16_VEC(8);  CORDIC16_VEC(9);  CORDIC16_VEC(10); CORDIC16_VEC(11);
  CORDIC16_VEC(12); CORDIC16_VEC(13); CORDIC16_VEC(14);
  return z;
}

// atan2(y, x) in Q2.14 for the RIGHT half-plane (x > 0); result in (-pi/2, pi/2). Inputs are
// pre-halved so An*magnitude stays inside int16 (the angle is unchanged by (y,x)->(y/2,x/2)).
static inline int16_t cordic16_atan2(int16_t y, int16_t x) {
  return cordic16_vector_angle((int16_t)(x >> 1), (int16_t)(y >> 1));
}

// atan(x) in Q2.14 for x in (-2, 2): atan2(x, 1).
static inline int16_t cordic16_atan(int16_t x) {
  return cordic16_atan2(x, CORDIC16_ONE);
}

#endif // CORDIC16_H
