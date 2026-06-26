// Shared, PURE interactive state-math for the Blossom demo — the SINGLE SOURCE OF TRUTH for the
// per-frame controller state machine, compiled by BOTH the SNES target (examples/snes/blossom.c) and
// the host verifier (dev/jgxcheck.cpp under -DJGX_BLOSSOM). Like examples/snes/view.h, it is the
// differential's anchor for the interaction math: the ROM logs the pad values it read + a rolling CRC
// of the per-frame state; the host replays THESE functions over that ground-truth log and asserts an
// identical CRC. So this is +mos-a16 code under test — keep every cast load-bearing.
//
// NO hardware here (no snes.h, no MMIO) — host-linkable. The grid accumulation is gated separately
// (the deterministic boot K_GATE hash); this gate covers only the pure state machine.
#ifndef BLOSSOM_VIEW_H
#define BLOSSOM_VIEW_H

#include <stdint.h>

// joypad bit masks — MUST match platforms/snes/snes_joypad.h (the serial order). Guarded so this
// header is self-contained on the host where snes.h is absent.
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

// Attractor parameter presets (Q8.8 a,b,c) — distinct BOUNDED Hopalong shapes that fit the 128x128
// grid at the fixed HOP_GAIN (verified host-side: maxabs in range, hundreds+ of cells visited).
// classic (7.17, 8.44, 2.56); v2 (2, 5, 1) — dense; v6 (-2, 7, 5) — a tighter bloom.
#define BLOSSOM_NPRESET 3
static const short BLOSSOM_PA[BLOSSOM_NPRESET] = { 0x072C, 0x0200, (short)0xFE00 };
static const short BLOSSOM_PB[BLOSSOM_NPRESET] = { 0x0871, 0x0500, 0x0700 };
static const short BLOSSOM_PC[BLOSSOM_NPRESET] = { 0x028F, 0x0100, 0x0500 };

#define BLOSSOM_NPAL  4          // colour modes (the Select-cycled palette family)

// Mode 7 view tunables (8.8 zoom: smaller = more magnified; 0x0100 = 1.0). Pan is BG scroll.
#define BL_ZOOM_INIT  0x0080     // boot: 2x magnify (the static-demo framing)
#define BL_ZOOM_MIN   0x0040     // most zoomed-IN (4x)
#define BL_ZOOM_MAX   0x0200     // most zoomed-OUT
#define BL_ZOOM_STEP  2
#define BL_PAN_MAX    256
#define BL_PAN_STEP   4

// The interactive state. `dirty` flags a frame whose params changed (the demo must clear + re-bloom
// the grid); `cyc` is the free-running palette-cycle phase; `prev` makes Select/Start/preset EDGE.
typedef struct {
  uint8_t preset, pal, cyc, dirty;
  int16_t zoom, cx, cy;
  uint16_t prev;
} blossom_t;

static inline void blossom_reset(blossom_t *v) {
  v->preset = 0; v->pal = 0; v->cyc = 0; v->dirty = 1;
  v->zoom = BL_ZOOM_INIT; v->cx = 0; v->cy = 0; v->prev = 0;
}

// Advance the state by one frame given the pad bitmask. Preset (A/Y) and palette (Select) and reset
// (Start) are EDGE; zoom (L/R) and pan (D-pad) are LEVEL. Pure integer ops — wraps/clamps identical
// on host (int=32) and target (int=16).
static inline void blossom_step(blossom_t *v, uint16_t pad) {
  uint16_t edge = (uint16_t)(pad & ~v->prev);
  v->dirty = 0;
  if (edge & JOY_A)      { uint8_t p = (uint8_t)(v->preset + 1); if (p >= BLOSSOM_NPRESET) p = 0;
                           v->preset = p; v->dirty = 1; }
  if (edge & JOY_Y)      { v->preset = (uint8_t)(v->preset ? v->preset - 1 : BLOSSOM_NPRESET - 1);
                           v->dirty = 1; }
  if (edge & JOY_SELECT) { uint8_t q = (uint8_t)(v->pal + 1); if (q >= BLOSSOM_NPAL) q = 0; v->pal = q; }
  if (edge & JOY_START)  { v->preset = 0; v->pal = 0; v->zoom = BL_ZOOM_INIT; v->cx = 0; v->cy = 0;
                           v->dirty = 1; }
  if (pad & JOY_R)       { v->zoom -= BL_ZOOM_STEP; if (v->zoom < BL_ZOOM_MIN) v->zoom = BL_ZOOM_MIN; }
  if (pad & JOY_L)       { v->zoom += BL_ZOOM_STEP; if (v->zoom > BL_ZOOM_MAX) v->zoom = BL_ZOOM_MAX; }
  if (pad & JOY_LEFT)    { v->cx -= BL_PAN_STEP; if (v->cx < -BL_PAN_MAX) v->cx = -BL_PAN_MAX; }
  if (pad & JOY_RIGHT)   { v->cx += BL_PAN_STEP; if (v->cx >  BL_PAN_MAX) v->cx =  BL_PAN_MAX; }
  if (pad & JOY_UP)      { v->cy -= BL_PAN_STEP; if (v->cy < -BL_PAN_MAX) v->cy = -BL_PAN_MAX; }
  if (pad & JOY_DOWN)    { v->cy += BL_PAN_STEP; if (v->cy >  BL_PAN_MAX) v->cy =  BL_PAN_MAX; }
  v->cyc = (uint8_t)(v->cyc + 1);   // palette phase advances every frame (the shimmer)
  v->prev = pad;
}

// CRC16-CCITT step (poly 0x1021), promotion-safe — the view.h/mandel_crc routine family.
static inline uint16_t blossom_crc16_byte(uint16_t crc, uint8_t b) {
  crc ^= (uint16_t)((uint16_t)b << 8);
  for (uint8_t i = 0; i < 8; i++)
    crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
  return crc;
}

// Fold one frame's state into the rolling CRC (little-endian). The proof channel: host replay over
// the logged pads must reproduce the ROM's value exactly.
static inline uint16_t blossom_fold(uint16_t crc, const blossom_t *v) {
  crc = blossom_crc16_byte(crc, v->preset);
  crc = blossom_crc16_byte(crc, v->pal);
  crc = blossom_crc16_byte(crc, v->cyc);
  crc = blossom_crc16_byte(crc, v->dirty);
  crc = blossom_crc16_byte(crc, (uint8_t)v->zoom);
  crc = blossom_crc16_byte(crc, (uint8_t)((uint16_t)v->zoom >> 8));
  crc = blossom_crc16_byte(crc, (uint8_t)v->cx);
  crc = blossom_crc16_byte(crc, (uint8_t)((uint16_t)v->cx >> 8));
  crc = blossom_crc16_byte(crc, (uint8_t)v->cy);
  crc = blossom_crc16_byte(crc, (uint8_t)((uint16_t)v->cy >> 8));
  return crc;
}

#endif /* BLOSSOM_VIEW_H */
