// examples/65816/cordic.h — #12 of the compiler stress-test demo battery: the MULTIPLY-FREE member.
//
// A rotating-hand "rotator" built ON TOP OF the existing Q2.14 CORDIC core (examples/65816/cordic16.h).
// CORDIC is shift-and-add only — no multiply, no divide — so under +mos-a16 the gate object lowers to
// pure native-16 ALU code (rep/sep brackets + COMPILE-TIME-CONSTANT shifts) with ZERO __*si3 / __*hi3
// arithmetic libcalls. That ABSENCE is this demo's differential signature: every other demo's disasm
// gate asserts the PRESENCE of __mulsi3 / __udivmodsi4; dev/cordic.sh §3 inverts it (mul==div==vsh==0,
// rep/sep + cordic16_atan_tbl present).
//
// The core cordic16_sincos converges only for angle in [-pi/2, pi/2]; cordic16_atan2 needs x > 0. A full
// circle is covered by QUADRANT FOLDING — a residual angle r in [0, pi/2) plus a 0..3 quadrant index
// applied as sign/swap (pure compare/add/negate, still multiply-free). The radius->pixel scaling that a
// renderer needs (RADIUS*cos>>14, which IS a __mulsi3) is deliberately kept OUT of this header / the gate
// and lives only in the ROM render path (examples/snes/cordic.c), so the probed corpus object stays clean.
//
// Width discipline: int16_t / uint16_t only, never bare int (host int=32 vs target int=16 would diverge).
// Shared by the host oracle (tools/cordic-sim.c), the corpus slice (examples/snes/corpus/cordic_sim.c),
// and the SNES ROM (examples/snes/cordic.c). Plan: docs/plans/2026-06-28-12-snes-cordic-clock-rotator.md.
#ifndef CORDIC_DEMO_H
#define CORDIC_DEMO_H
#include <stdint.h>
#include "cordic16.h"

#define CORDIC_QSTEPS   24                              // residual sincos steps per quadrant
#define CORDIC_DSTEP    (CORDIC16_HALFPI / CORDIC_QSTEPS) // compile-time const Q2.14 angle increment
#define CORDIC_GATE_N   96u                             // 4*QSTEPS = one full revolution (<=120 frames)

// Full-circle rotor: a residual angle r in [0, pi/2) plus a quadrant index qd in 0..3. Advancing it is
// pure add/compare; reading (sin,cos) is one CORDIC sweep over r plus a quadrant sign/swap — NO multiply.
typedef struct { int16_t r; uint8_t qd; } rotor;

static inline void rotor_init(rotor *o) { o->r = 0; o->qd = 0; }

// rotate-left-1 XOR fold (identical to pi_fold in pi_spigot.h) — rolls a uint16 stream into a CRC.
static inline uint16_t cordic_fold(uint16_t h, uint16_t v) {
  return (uint16_t)(((h << 1) | (h >> 15)) ^ v);
}

// (sin,cos) of the rotor's CURRENT full-circle angle, then advance by one DSTEP. Quadrant rotation of the
// base (cos0,sin0) in [0,pi/2): qd=0 (c,s); qd=1 +90deg (-s,c); qd=2 +180 (-c,-s); qd=3 +270 (s,-c).
static inline void rotor_sincos(rotor *o, int16_t *sin_out, int16_t *cos_out) {
  int16_t s0, c0;
  cordic16_sincos(o->r, &s0, &c0);                      // base vector, right half-plane (cos0 >= 0)
  switch (o->qd & 3u) {
    case 0:  *cos_out =          c0; *sin_out =          s0; break;
    case 1:  *cos_out = (int16_t)-s0; *sin_out =          c0; break;
    case 2:  *cos_out = (int16_t)-c0; *sin_out = (int16_t)-s0; break;
    default: *cos_out =          s0; *sin_out = (int16_t)-c0; break;
  }
  o->r = (int16_t)(o->r + CORDIC_DSTEP);                // pure add/compare — never a multiply
  if (o->r >= CORDIC16_HALFPI) { o->r = (int16_t)(o->r - CORDIC16_HALFPI); o->qd = (uint8_t)(o->qd + 1u); }
}

// The differential payload: sweep the hand once around the circle, folding BOTH the rotation path
// (cordic16_sincos via rotor_sincos) AND the vectoring path (cordic16_atan2 recovering the base angle from
// its right-half-plane base vector) into a single uint16 CRC. noinline to isolate its live set, matching
// pi_gate_crc / the other demos. Calls ONLY the Phase-2 pure-core CORDIC functions — never the Phase-3
// tan/asin/sqrt/sinh helpers in cordic16.h (those emit __mulsi3/__divsi3 and would dirty the gate object).
__attribute__((noinline))
static uint16_t cordic_gate_crc(void) {
  uint16_t h = 0;
  rotor o; rotor_init(&o);
  for (uint16_t k = 0; k < CORDIC_GATE_N; k++) {
    int16_t base_s, base_c;
    cordic16_sincos(o.r, &base_s, &base_c);             // ROTATION (base): cos0 >= 0 in [0,pi/2]
    int16_t s, c; rotor_sincos(&o, &s, &c);             // ROTATION (full-circle) + advance rotor
    h = cordic_fold(h, (uint16_t)s);
    h = cordic_fold(h, (uint16_t)c);
    h = cordic_fold(h, (uint16_t)cordic16_atan2(base_s, base_c)); // VECTORING: recover ~ o.r (x>0)
  }
  return h;
}

#endif // CORDIC_DEMO_H
