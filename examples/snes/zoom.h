// Shared, PURE view-math for the interactive Mandelbrot ZOOM PYRAMID demo.
//
// SINGLE SOURCE OF TRUTH for the per-frame zoom state machine, compiled by BOTH the SNES target
// (examples/snes/mandel-zoom.c) and the host verifier (dev/jgxcheck.cpp, -DJGX_ZOOM). Like view.h
// / mandel.h it is the differential's anchor: the ROM logs the pad values it actually read + a
// rolling CRC of the per-frame zoom state (level + scale + angle) AND the Mode 7 matrix; the host
// replays THESE functions over that ground-truth log and asserts an identical CRC. So this is the
// code under test for +mos-a16 — keep every cast load-bearing (the (int32_t) on the matrix
// multiplies forces a 32-bit multiply on both host int=32 and llvm-mos int=16).
//
// THE PYRAMID MECHANIC. The host baked L Mandelbrot levels, each 2x finer zoom (pyramid_image.h).
// Mode 7 hardware-zooms the CURRENT level by scaling the affine matrix; when zoom crosses a 2x
// threshold the runtime swaps to the next (finer) level and resets the scale, so the dive runs
// into GENUINELY NEW detail with no on-console fractal math. zoom_step() is PURE: it folds the pad
// into (lvl, scale, angle) and returns whether the displayed level changed; the TARGET reacts by
// DMAing MANDEL_PYR[lvl] (that DMA is the only target-only side effect — apply lives in
// mandel-zoom.c). The host replay tracks lvl identically (zoom_step updates it), so host == target.
//
// NO hardware here (no snes.h, no MMIO). This split lets the host link zoom.h with zero SNES deps.
#ifndef ZOOM_H
#define ZOOM_H

#include <stdint.h>
#include "pyramid_image.h"   // SINCOS (8.8 sine), MANDEL_NCOL, MANDEL_PYR_L, MANDEL_PYR_W

// --- joypad bit masks (mirror platforms/snes/snes.h; identical to the SNES serial order and to
// bsnes Input::Gamepad::*). Defined here under a guard so zoom.h is self-contained on the host,
// where snes.h is not included. THESE MUST MATCH snes.h. ---
#ifndef JOY_B
#define JOY_B 0x8000u
#define JOY_Y 0x4000u
#define JOY_SELECT 0x2000u
#define JOY_START 0x1000u
#define JOY_UP 0x0800u
#define JOY_DOWN 0x0400u
#define JOY_LEFT 0x0200u
#define JOY_RIGHT 0x0100u
#define JOY_A 0x0080u
#define JOY_X 0x0040u
#define JOY_L 0x0020u
#define JOY_R 0x0010u
#endif

// The Mode 7 matrix scale is 8.8: SMALLER = more magnified (0x0100 = 1.0 = identity). The "fill"
// scale S0 maps the WxW source image to the full 256-px screen: 256 * (W/256) px stepped per
// screen px => S0 = W in 8.8 (W=64 -> 0x40, W=128 -> 0x80). Zoom IN drops scale to S0/2 (each
// screen px steps half a source px => the centre HALF of the image fills the screen = exactly the
// next finer level's window), where we swap up and reset to S0 — a clean factor-of-2 hysteresis
// band [S0/2, 2*S0] with the reset sitting at its geometric midpoint, so a held zoom can't thrash.
#define ZOOM_S0        (MANDEL_PYR_W)        // fill scale (8.8): image exactly fills the screen
#define ZOOM_STEP      (ZOOM_S0 >> 5)        // scale change/frame (~16 frames/level); >=1 below
#define ZOOM_ANGLE_STEP 2                    // rotation units/frame (256 = full circle) ~2.8 deg

// The interactive state. `prev` (last frame's pad) is part of the state so Select/Start are
// edge-triggered deterministically during replay. scale is 8.8; lvl indexes the pyramid.
typedef struct { uint8_t lvl; int16_t scale; uint8_t angle, pal; uint16_t prev; } zoom_t;

static inline void zoom_reset(zoom_t *z) {
  z->lvl = 0; z->scale = (int16_t)ZOOM_S0; z->angle = 0; z->pal = 0; z->prev = 0;
}

// Advance the zoom by one frame given the pad bitmask. R/L zoom in/out (LEVEL, while held, with
// 2x-threshold level swaps); Y/A rotate (LEVEL); Select cycles palette, Start resets (EDGE, one
// per press). Returns 1 if the DISPLAYED LEVEL changed (target re-DMAs MANDEL_PYR[lvl]), else 0.
// Pure integer ops — wraps/clamps identical on host and target.
static inline uint8_t zoom_step(zoom_t *z, uint16_t pad) {
  uint16_t edge = (uint16_t)(pad & ~z->prev);
  uint8_t old_lvl = z->lvl;
  int16_t step = (ZOOM_STEP >= 1) ? (int16_t)ZOOM_STEP : 1;

  if (pad & JOY_R) {                                   // zoom IN: scale shrinks (more magnified)
    z->scale = (int16_t)(z->scale - step);
    if (z->scale <= (int16_t)(ZOOM_S0 / 2)) {
      if (z->lvl < MANDEL_PYR_L - 1) { z->lvl++; z->scale = (int16_t)ZOOM_S0; }  // swap to finer
      else z->scale = (int16_t)(ZOOM_S0 / 2);          // deepest level: clamp (blocky magnify)
    }
  }
  if (pad & JOY_L) {                                   // zoom OUT: scale grows
    z->scale = (int16_t)(z->scale + step);
    if (z->scale >= (int16_t)(2 * ZOOM_S0)) {
      if (z->lvl > 0) { z->lvl--; z->scale = (int16_t)ZOOM_S0; }                 // swap to coarser
      else z->scale = (int16_t)(2 * ZOOM_S0);          // shallowest level: clamp (smaller image)
    }
  }
  if (pad & JOY_A) z->angle = (uint8_t)(z->angle + ZOOM_ANGLE_STEP);             // rotate cw, wraps
  if (pad & JOY_Y) z->angle = (uint8_t)(z->angle - ZOOM_ANGLE_STEP);             // rotate ccw
  if (edge & JOY_SELECT) { z->pal = (uint8_t)(z->pal + 1); if (z->pal >= MANDEL_NCOL) z->pal = 0; }
  if (edge & JOY_START)  { z->lvl = 0; z->scale = (int16_t)ZOOM_S0; z->angle = 0; z->pal = 0; }
  z->prev = pad;
  return (uint8_t)(z->lvl != old_lvl);
}

// The Mode 7 affine matrix (A,B,C,D, 8.8) for the current angle+scale. The four 16x16->32
// fixed-point multiplies are the live +mos-a16 work this demo exercises (shared shape with view.h).
static inline void zoom_matrix(const zoom_t *z, int16_t m[4]) {
  int16_t c = SINCOS[(uint8_t)(z->angle + 64)];   // cos (8.8)
  int16_t s = SINCOS[z->angle];                    // sin (8.8)
  m[0] = (int16_t)(((int32_t)c    * z->scale) >> 8); // A =  cos*scale
  m[1] = (int16_t)(((int32_t)(-s) * z->scale) >> 8); // B = -sin*scale
  m[2] = (int16_t)(((int32_t)s    * z->scale) >> 8); // C =  sin*scale
  m[3] = (int16_t)(((int32_t)c    * z->scale) >> 8); // D =  cos*scale
}

// CRC16-CCITT step (poly 0x1021), promotion-safe (the (uint16_t) casts pin the type on the
// 16-bit-int target). Same routine family as view.h / mandel.h.
static inline uint16_t zoom_crc16_byte(uint16_t crc, uint8_t b) {
  crc ^= (uint16_t)((uint16_t)b << 8);
  for (uint8_t i = 0; i < 8; i++)
    crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
  return crc;
}

// Fold one frame's zoom state + Mode 7 matrix into the rolling CRC (little-endian bytes). The
// proof channel: host replay over the logged pads must reproduce the ROM's value exactly. Folding
// lvl captures the level-swap arithmetic; folding the matrix captures the 16x16->32 multiplies.
//
// The matrix fold is UNROLLED (not `for (i<4) m[i]`) deliberately. The loop form is byte-identical
// C, but it MISCOMPILES under the DEFAULT 8-bit codegen here (the differential caught it: default
// rom 0x456E vs host==+mos-a16 0xB115 over a fixed R-held input; the unrolled form below gives
// 0xB115 on all three). The trigger is narrow — the indexed int16 load m[i] threaded through the
// outer fold loop whose body calls zoom_crc16_byte (itself an 8-iteration inner loop) twice — so a
// general indexed-array loop is fine (view.h's identical view_fold loop is unaffected in its
// context, and the corpus/csmith fuzzers are green). This is a PRE-EXISTING default-8bit backend
// defect surfaced by this demo, INDEPENDENT of the #321 +mos-a16 work; recorded as a follow-up
// (see the plan's Findings + TODO). Unrolling is a faithful equivalent and still gates all four
// 16x16->32 multiplies, so the demo stays green while the backend bug is tracked separately.
static inline uint16_t zoom_fold(uint16_t crc, const zoom_t *z, const int16_t m[4]) {
  crc = zoom_crc16_byte(crc, z->lvl);
  crc = zoom_crc16_byte(crc, (uint8_t)z->scale);
  crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)z->scale >> 8));
  crc = zoom_crc16_byte(crc, z->angle);
  crc = zoom_crc16_byte(crc, z->pal);
  crc = zoom_crc16_byte(crc, (uint8_t)m[0]);
  crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)m[0] >> 8));
  crc = zoom_crc16_byte(crc, (uint8_t)m[1]);
  crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)m[1] >> 8));
  crc = zoom_crc16_byte(crc, (uint8_t)m[2]);
  crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)m[2] >> 8));
  crc = zoom_crc16_byte(crc, (uint8_t)m[3]);
  crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)m[3] >> 8));
  return crc;
}

#endif /* ZOOM_H */
