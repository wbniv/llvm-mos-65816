// Shared, PURE interactive state-math for the 3-D Wireframe demo (#16) — the SINGLE SOURCE OF TRUTH for
// the per-frame controller state machine, compiled by BOTH the SNES target (examples/snes/wireframe.c)
// and the host verifier (examples/snes/corpus/wire3d_ctrl_sim.c). Like spirograph.h, it is the
// differential's anchor for the interaction math: a deterministic scripted pad sequence replays these
// functions and asserts host == +mos-a16 == +mos-xy16 on the rolling state+HUD CRC. Keep every cast
// load-bearing.
//
// NO hardware here (no snes.h, no MMIO) — host-linkable. Includes wire3d.h for the solid enum + the
// projection constants. The matrix+divide hot loop is gated separately (wire3d_gate_crc, the
// projected-vertex hash); this gate covers only the pure controller/HUD-format state machine.
#ifndef WIREFRAME_VIEW_H
#define WIREFRAME_VIEW_H

#include "../65816/wire3d.h"

// joypad bit masks — MUST match platforms/snes/snes_joypad.h. Guarded so the header is self-contained on
// the host (corpus slice) where snes.h is absent.
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

#define WIRE3_NPAL    4     // palette / colour modes (X-cycled)
#define WIRE3_SPIN_MAX 8    // |dax|/|day| clamp (degrees-ish per frame)
#define WIRE3_DIST_MIN 120  // L/R dolly bounds (DIST_MIN > model radius -> z stays > 0)
#define WIRE3_DIST_MAX 240

// 5-char solid names (for the HUD), index by solid.
static const char WIRE3_SOLID_NAME[WIRE3_NSOLID][6] = { "TETRA", "CUBE ", "OCTA ", "ICOSA" };

// The interactive state. `dirty` flags a frame whose SOLID changed (-> the demo may clear the canvas and
// refresh the HUD). ax/ay/az auto-spin by the signed dax/day/daz each frame; D-pad adjusts the spin
// rates, L/R the dolly distance, A/Y the solid, X the palette, Select toggles trail mode, Start resets.
typedef struct {
  uint8_t  solid;
  uint8_t  ax, ay, az;        // current Euler angles (auto-spin accumulates; wrap mod 256)
  int8_t   dax, day, daz;     // per-frame spin deltas (signed = direction)
  uint8_t  dist;              // projection distance (the dolly; clamped to [MIN,MAX])
  uint8_t  pal;               // palette index (display only)
  uint8_t  trail;             // 1 = phosphor-trail mode (no clear), 0 = crisp spin
  uint8_t  dirty;             // 1 = solid changed this frame
  uint16_t prev;              // edge detection
} wire3d_view;

static inline void wire3d_view_reset(wire3d_view *v) {
  v->solid = WIRE3_CUBE;
  v->ax = 0; v->ay = 0; v->az = 0;
  v->dax = 1; v->day = 2; v->daz = 1;     // a gentle default tumble
  v->dist = WIRE3_DIST;                    // == 180, the nominal projection distance
  v->pal = 0; v->trail = 0; v->dirty = 1; v->prev = 0;
}

static inline int8_t _wire3_clamp_s(int16_t x, int16_t lo, int16_t hi) {
  return (int8_t)(x < lo ? lo : x > hi ? hi : x);
}
static inline uint8_t _wire3_clamp_u(int16_t x, int16_t lo, int16_t hi) {
  return (uint8_t)(x < lo ? lo : x > hi ? hi : x);
}

// Advance the state by one frame given the pad bitmask. Solid (A/Y), palette (X), trail (Select) and
// reset (Start) are EDGE; spin-rate (D-pad) and dolly (L/R) are LEVEL. Then the figure auto-spins
// (ax += dax, &c). Pure integer ops — wraps/clamps identical on host (int=32) and target (int=16). Sets
// `dirty` only when the SOLID changed.
static inline void wire3d_view_step(wire3d_view *v, uint16_t pad) {
  uint16_t edge = (uint16_t)(pad & ~v->prev);
  v->dirty = 0;
  if (edge & JOY_A) { uint8_t s = (uint8_t)(v->solid + 1); if (s >= WIRE3_NSOLID) s = 0; v->solid = s; v->dirty = 1; }
  if (edge & JOY_Y) { v->solid = (uint8_t)(v->solid ? v->solid - 1 : WIRE3_NSOLID - 1); v->dirty = 1; }
  if (edge & JOY_X) { uint8_t q = (uint8_t)(v->pal + 1); if (q >= WIRE3_NPAL) q = 0; v->pal = q; }   /* display only */
  if (edge & JOY_SELECT) { v->trail = (uint8_t)(v->trail ^ 1u); }
  if (edge & JOY_START)  { wire3d_view_reset(v); }
  if (pad & JOY_UP)    { v->day = _wire3_clamp_s((int16_t)(v->day + 1), -WIRE3_SPIN_MAX, WIRE3_SPIN_MAX); }
  if (pad & JOY_DOWN)  { v->day = _wire3_clamp_s((int16_t)(v->day - 1), -WIRE3_SPIN_MAX, WIRE3_SPIN_MAX); }
  if (pad & JOY_RIGHT) { v->dax = _wire3_clamp_s((int16_t)(v->dax + 1), -WIRE3_SPIN_MAX, WIRE3_SPIN_MAX); }
  if (pad & JOY_LEFT)  { v->dax = _wire3_clamp_s((int16_t)(v->dax - 1), -WIRE3_SPIN_MAX, WIRE3_SPIN_MAX); }
  if (pad & JOY_R)     { v->dist = _wire3_clamp_u((int16_t)(v->dist + 2), WIRE3_DIST_MIN, WIRE3_DIST_MAX); }
  if (pad & JOY_L)     { v->dist = _wire3_clamp_u((int16_t)(v->dist - 2), WIRE3_DIST_MIN, WIRE3_DIST_MAX); }
  v->ax = (uint8_t)(v->ax + (uint8_t)v->dax);    // auto-spin (signed delta added mod 256)
  v->ay = (uint8_t)(v->ay + (uint8_t)v->day);
  v->az = (uint8_t)(v->az + (uint8_t)v->daz);
  v->prev = pad;
}

// CRC16-CCITT step (poly 0x1021), promotion-safe — the spiro_crc16_byte / blossom.h routine family.
static inline uint16_t wire3d_crc16_byte(uint16_t crc, uint8_t b) {
  crc ^= (uint16_t)((uint16_t)b << 8);
  for (uint8_t i = 0; i < 8; i++)
    crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
  return crc;
}

// Write an unsigned 0..255 as up to 3 decimal digits (no leading zeros). Returns chars written.
static inline uint8_t wire3d_fmt_u8(uint8_t val, char *buf) {
  uint8_t n = 0;
  if (val >= 100) buf[n++] = (char)('0' + val / 100u);
  if (val >= 10)  buf[n++] = (char)('0' + (val / 10u) % 10u);
  buf[n++] = (char)('0' + val % 10u);
  return n;
}

// Magnitude of a signed spin rate as a HUD byte (the sign is shown separately as a +/- glyph).
static inline uint8_t wire3d_spin_abs(int8_t d) { return (uint8_t)(d < 0 ? -d : d); }

// Fold one frame's state into the rolling controller CRC (the proof channel: host replay over the logged
// pads must reproduce the ROM's value exactly). Includes the formatted HUD field bytes (spin magnitudes,
// dist) so the Q-format -> decimal math is exercised host == target.
static inline uint16_t wire3d_view_fold(uint16_t crc, const wire3d_view *v) {
  crc = wire3d_crc16_byte(crc, v->solid);
  crc = wire3d_crc16_byte(crc, v->ax);
  crc = wire3d_crc16_byte(crc, v->ay);
  crc = wire3d_crc16_byte(crc, v->az);
  crc = wire3d_crc16_byte(crc, (uint8_t)v->dax);
  crc = wire3d_crc16_byte(crc, (uint8_t)v->day);
  crc = wire3d_crc16_byte(crc, (uint8_t)v->daz);
  crc = wire3d_crc16_byte(crc, v->dist);
  crc = wire3d_crc16_byte(crc, v->pal);
  crc = wire3d_crc16_byte(crc, v->trail);
  crc = wire3d_crc16_byte(crc, v->dirty);
  char buf[4]; uint8_t n, i;
  n = wire3d_fmt_u8(wire3d_spin_abs(v->dax), buf); for (i = 0; i < n; i++) crc = wire3d_crc16_byte(crc, (uint8_t)buf[i]);
  n = wire3d_fmt_u8(wire3d_spin_abs(v->day), buf); for (i = 0; i < n; i++) crc = wire3d_crc16_byte(crc, (uint8_t)buf[i]);
  n = wire3d_fmt_u8(v->dist, buf);                 for (i = 0; i < n; i++) crc = wire3d_crc16_byte(crc, (uint8_t)buf[i]);
  return crc;
}

#endif /* WIREFRAME_VIEW_H */
