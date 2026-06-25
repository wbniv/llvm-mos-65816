// Shared, PURE view-math for the interactive Mandelbrot demo.
//
// SINGLE SOURCE OF TRUTH for the per-frame interactive state machine, compiled by BOTH the
// SNES target (examples/snes/mandel-interactive.c) and the host verifier (dev/jgxcheck.cpp).
// Like examples/65816/mandel.h, it is the differential's anchor: the ROM logs the pad values
// it actually read + a rolling CRC of the per-frame view state and Mode 7 matrix; the host
// replays THESE functions over that ground-truth log and asserts an identical CRC. So this is
// the code under test for +mos-a16 — keep every cast load-bearing (the (int32_t) on the matrix
// multiplies forces a 32-bit multiply on both host int=32 and llvm-mos int=16).
//
// NO hardware here (no snes.h, no MMIO). apply_view() — which turns view_matrix()'s output
// into Mode 7 register writes — lives in mandel-interactive.c (target-only). This split lets
// the host link view.h with zero SNES dependencies.
#ifndef VIEW_H
#define VIEW_H

#include <stdint.h>
#include "mandel_image.h"   // SINCOS (8.8 sine), MANDEL_NCOL

// --- joypad bit masks (mirror platforms/snes/snes.h; identical to the SNES serial order and
// to bsnes Input::Gamepad::*). Defined here under a guard so view.h is self-contained on the
// host, where snes.h is not included. THESE MUST MATCH snes.h. ---
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

// Tunables — shared so host == target exactly. zoom is the Mode 7 matrix scale in 8.8: SMALLER
// = more magnified (0x0100 = 1.0 = identity; 0x0080 = 0.5 = 2x). Pan is the BG scroll offset.
#define VIEW_ZOOM_INIT  0x0080   // boot: 2x magnify (matches the static mandel-mode7 demo)
#define VIEW_ZOOM_MIN   0x0020   // most zoomed-IN  (0.125 = 8x)
#define VIEW_ZOOM_MAX   0x0400   // most zoomed-OUT (4.0)
#define VIEW_ZOOM_STEP  4
#define VIEW_PAN_MAX    512
#define VIEW_PAN_STEP   3
#define VIEW_ANGLE_STEP 2        // angle units (256 = full circle) -> ~2.8 deg/frame

// The interactive state. `prev` (last frame's pad) is part of the state so Select/Start are
// edge-triggered deterministically during replay.
typedef struct { int16_t cx, cy, zoom; uint8_t angle, pal; uint16_t prev; } view_t;

static inline void view_reset(view_t *v) {
  v->cx = 0; v->cy = 0; v->zoom = VIEW_ZOOM_INIT; v->angle = 0; v->pal = 0; v->prev = 0;
}

// Advance the view by one frame given the pad bitmask. Pan/zoom/rotate are LEVEL (while held);
// palette-cycle and reset are EDGE (one per press). Pure integer ops — wraps/clamps identical
// on host and target.
static inline void view_step(view_t *v, uint16_t pad) {
  uint16_t edge = (uint16_t)(pad & ~v->prev);
  if (pad & JOY_LEFT)  { v->cx -= VIEW_PAN_STEP; if (v->cx < -VIEW_PAN_MAX) v->cx = -VIEW_PAN_MAX; }
  if (pad & JOY_RIGHT) { v->cx += VIEW_PAN_STEP; if (v->cx >  VIEW_PAN_MAX) v->cx =  VIEW_PAN_MAX; }
  if (pad & JOY_UP)    { v->cy -= VIEW_PAN_STEP; if (v->cy < -VIEW_PAN_MAX) v->cy = -VIEW_PAN_MAX; }
  if (pad & JOY_DOWN)  { v->cy += VIEW_PAN_STEP; if (v->cy >  VIEW_PAN_MAX) v->cy =  VIEW_PAN_MAX; }
  if (pad & JOY_R)     { v->zoom -= VIEW_ZOOM_STEP; if (v->zoom < VIEW_ZOOM_MIN) v->zoom = VIEW_ZOOM_MIN; }
  if (pad & JOY_L)     { v->zoom += VIEW_ZOOM_STEP; if (v->zoom > VIEW_ZOOM_MAX) v->zoom = VIEW_ZOOM_MAX; }
  if (pad & JOY_A)     { v->angle = (uint8_t)(v->angle + VIEW_ANGLE_STEP); }   // wraps mod 256
  if (pad & JOY_Y)     { v->angle = (uint8_t)(v->angle - VIEW_ANGLE_STEP); }
  if (edge & JOY_SELECT) { v->pal = (uint8_t)(v->pal + 1); if (v->pal >= MANDEL_NCOL) v->pal = 0; }
  if (edge & JOY_START)  { v->cx = 0; v->cy = 0; v->zoom = VIEW_ZOOM_INIT; v->angle = 0; v->pal = 0; }
  v->prev = pad;
}

// The Mode 7 affine matrix (A,B,C,D, 8.8) for the current angle+zoom. The four 16x16->32
// fixed-point multiplies are the live +mos-a16 work this demo exercises.
static inline void view_matrix(const view_t *v, int16_t m[4]) {
  int16_t c = SINCOS[(uint8_t)(v->angle + 64)];   // cos (8.8)
  int16_t s = SINCOS[v->angle];                    // sin (8.8)
  m[0] = (int16_t)(((int32_t)c    * v->zoom) >> 8); // A =  cos*zoom
  m[1] = (int16_t)(((int32_t)(-s) * v->zoom) >> 8); // B = -sin*zoom
  m[2] = (int16_t)(((int32_t)s    * v->zoom) >> 8); // C =  sin*zoom
  m[3] = (int16_t)(((int32_t)c    * v->zoom) >> 8); // D =  cos*zoom
}

// CRC16-CCITT step (poly 0x1021), promotion-safe (the (uint16_t) casts pin the type on the
// 16-bit-int target). Same routine family as mandel.h's mandel_crc.
static inline uint16_t view_crc16_byte(uint16_t crc, uint8_t b) {
  crc ^= (uint16_t)((uint16_t)b << 8);
  for (uint8_t i = 0; i < 8; i++)
    crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
  return crc;
}

// Fold one frame's view state + matrix into the rolling CRC (little-endian bytes). This is the
// proof channel: host replay over the logged pads must reproduce the ROM's value exactly.
static inline uint16_t view_fold(uint16_t crc, const view_t *v, const int16_t m[4]) {
  crc = view_crc16_byte(crc, (uint8_t)v->cx);
  crc = view_crc16_byte(crc, (uint8_t)((uint16_t)v->cx >> 8));
  crc = view_crc16_byte(crc, (uint8_t)v->cy);
  crc = view_crc16_byte(crc, (uint8_t)((uint16_t)v->cy >> 8));
  crc = view_crc16_byte(crc, (uint8_t)v->zoom);
  crc = view_crc16_byte(crc, (uint8_t)((uint16_t)v->zoom >> 8));
  crc = view_crc16_byte(crc, v->angle);
  crc = view_crc16_byte(crc, v->pal);
  for (int i = 0; i < 4; i++) {
    crc = view_crc16_byte(crc, (uint8_t)m[i]);
    crc = view_crc16_byte(crc, (uint8_t)((uint16_t)m[i] >> 8));
  }
  return crc;
}

#endif /* VIEW_H */
