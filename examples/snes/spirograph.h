// Shared, PURE interactive state-math for the Spirograph demo — the SINGLE SOURCE OF TRUTH for the
// per-frame controller state machine, compiled by BOTH the SNES target (examples/snes/spirograph.c)
// and the host verifier (dev/jgxcheck.cpp under -DJGX_SPIRO). Like examples/snes/blossom.h, it is the
// differential's anchor for the interaction math: the ROM logs the pad values it read + a rolling CRC
// of the per-frame state; the host replays THESE functions over that ground-truth log and asserts an
// identical CRC. So this is +mos-a16 code under test — keep every cast load-bearing.
//
// NO hardware here (no snes.h, no MMIO) — host-linkable. Includes spiro.h only for the curve-family
// enum + spiro_petals (gcd). The curve accumulation is gated separately (the deterministic boot
// curve-point hash, spiro_gate_crc); this gate covers only the pure controller state machine.
#ifndef SPIROGRAPH_VIEW_H
#define SPIROGRAPH_VIEW_H

#include "../65816/spiro.h"

// joypad bit masks — MUST match platforms/snes/snes_joypad.h. Guarded so the header is self-contained
// on the host (jgxcheck) where snes.h is absent.
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

// Gear-set presets (R, r, d) — classic Spirograph(TM) wheel/ring combinations, each a distinct petal
// count (R/gcd(R,r)). They fit the 128px canvas at the spiro.h shift scaling.
#define SPIRO_NPRESET 5
static const uint8_t SPIRO_PR[SPIRO_NPRESET] = { 96, 105, 80, 84, 60 };
static const uint8_t SPIRO_Pr[SPIRO_NPRESET] = { 36,  42, 45, 28, 36 };
static const uint8_t SPIRO_Pd[SPIRO_NPRESET] = { 20,  30, 24, 18, 30 };

// Adjustment bounds (kept so the figure stays on-canvas and r>0).
#define SPIRO_R_MIN 12
#define SPIRO_R_MAX 120
#define SPIRO_r_MIN  4
#define SPIRO_r_MAX  90
#define SPIRO_d_MIN  0
#define SPIRO_d_MAX 60

#define SPIRO_NPAL 4    // palette / colour modes (X-cycled)

// 5-char mode names (for the HUD), index by mode.
static const char SPIRO_MODE_NAME[SPIRO_NMODES][6] = { "HYPO ", "EPI  ", "ROSE ", "LISSA" };

// The interactive state. `dirty` flags a frame whose (R,r,d,mode) changed -> the demo clears + re-blooms
// the canvas. `cyc` is the free-running palette phase; `prev` makes the edge controls one-shot.
typedef struct {
  uint8_t R, r, d, mode, preset, pal, cyc, dirty;
  uint16_t prev;
} spiro_view;

static inline void spiro_view_load_preset(spiro_view *v, uint8_t p) {
  v->preset = p;
  v->R = SPIRO_PR[p]; v->r = SPIRO_Pr[p]; v->d = SPIRO_Pd[p];
}

static inline void spiro_view_reset(spiro_view *v) {
  v->mode = SPIRO_HYPO; v->pal = 0; v->cyc = 0; v->dirty = 1; v->prev = 0;
  spiro_view_load_preset(v, 0);
}

static inline uint8_t _spiro_clamp(int16_t x, int16_t lo, int16_t hi) {
  return (uint8_t)(x < lo ? lo : x > hi ? hi : x);
}

// Advance the state by one frame given the pad bitmask. Mode (A/Y), preset (Select), palette (X) and
// reset (Start) are EDGE; R/r/d adjust (D-pad + L/R) is LEVEL. Pure integer ops — wraps/clamps
// identical on host (int=32) and target (int=16). Sets dirty when the FIGURE changed (R,r,d,mode).
static inline void spiro_view_step(spiro_view *v, uint16_t pad) {
  uint16_t edge = (uint16_t)(pad & ~v->prev);
  v->dirty = 0;
  if (edge & JOY_A) { uint8_t m = (uint8_t)(v->mode + 1); if (m >= SPIRO_NMODES) m = 0; v->mode = m; v->dirty = 1; }
  if (edge & JOY_Y) { v->mode = (uint8_t)(v->mode ? v->mode - 1 : SPIRO_NMODES - 1); v->dirty = 1; }
  if (edge & JOY_SELECT) { uint8_t p = (uint8_t)(v->preset + 1); if (p >= SPIRO_NPRESET) p = 0;
                           spiro_view_load_preset(v, p); v->dirty = 1; }
  if (edge & JOY_X) { uint8_t q = (uint8_t)(v->pal + 1); if (q >= SPIRO_NPAL) q = 0; v->pal = q; }  /* display only */
  if (edge & JOY_START) { spiro_view_reset(v); }
  if (pad & JOY_UP)    { v->R = _spiro_clamp((int16_t)(v->R + 1), SPIRO_R_MIN, SPIRO_R_MAX); v->dirty = 1; }
  if (pad & JOY_DOWN)  { v->R = _spiro_clamp((int16_t)(v->R - 1), SPIRO_R_MIN, SPIRO_R_MAX); v->dirty = 1; }
  if (pad & JOY_RIGHT) { v->r = _spiro_clamp((int16_t)(v->r + 1), SPIRO_r_MIN, SPIRO_r_MAX); v->dirty = 1; }
  if (pad & JOY_LEFT)  { v->r = _spiro_clamp((int16_t)(v->r - 1), SPIRO_r_MIN, SPIRO_r_MAX); v->dirty = 1; }
  if (pad & JOY_R)     { v->d = _spiro_clamp((int16_t)(v->d + 1), SPIRO_d_MIN, SPIRO_d_MAX); v->dirty = 1; }
  if (pad & JOY_L)     { v->d = _spiro_clamp((int16_t)(v->d - 1), SPIRO_d_MIN, SPIRO_d_MAX); v->dirty = 1; }
  v->cyc = (uint8_t)(v->cyc + 1);
  v->prev = pad;
}

// CRC16-CCITT step (poly 0x1021), promotion-safe — the blossom.h/mandel_crc routine family.
static inline uint16_t spiro_crc16_byte(uint16_t crc, uint8_t b) {
  crc ^= (uint16_t)((uint16_t)b << 8);
  for (uint8_t i = 0; i < 8; i++)
    crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
  return crc;
}

// --- HUD field formatting (PURE; host-linkable). Drives the on-screen value bar AND is folded into the
// controller CRC by spiro_fold below, so the format math is host == +mos-a16 verified. ---

// Write an unsigned 0..255 as up to 3 decimal digits (no leading zeros). Returns chars written.
static inline uint8_t spiro_fmt_u8(uint8_t val, char *buf) {
  uint8_t n = 0;
  if (val >= 100) buf[n++] = (char)('0' + val / 100u);
  if (val >= 10)  buf[n++] = (char)('0' + (val / 10u) % 10u);
  buf[n++] = (char)('0' + val % 10u);
  return n;
}

// Fold one frame's state into the rolling controller CRC (the proof channel: host replay over the
// logged pads must reproduce the ROM's value exactly). Includes the formatted HUD field bytes (R, r,
// d, petals) so the format math is exercised host == target.
static inline uint16_t spiro_view_fold(uint16_t crc, const spiro_view *v) {
  crc = spiro_crc16_byte(crc, v->R);
  crc = spiro_crc16_byte(crc, v->r);
  crc = spiro_crc16_byte(crc, v->d);
  crc = spiro_crc16_byte(crc, v->mode);
  crc = spiro_crc16_byte(crc, v->preset);
  crc = spiro_crc16_byte(crc, v->pal);
  crc = spiro_crc16_byte(crc, v->dirty);
  char buf[4]; uint8_t n, i;
  n = spiro_fmt_u8(v->R, buf);                  for (i = 0; i < n; i++) crc = spiro_crc16_byte(crc, (uint8_t)buf[i]);
  n = spiro_fmt_u8(v->r, buf);                  for (i = 0; i < n; i++) crc = spiro_crc16_byte(crc, (uint8_t)buf[i]);
  n = spiro_fmt_u8(v->d, buf);                  for (i = 0; i < n; i++) crc = spiro_crc16_byte(crc, (uint8_t)buf[i]);
  n = spiro_fmt_u8(spiro_petals(v->R, v->r), buf); for (i = 0; i < n; i++) crc = spiro_crc16_byte(crc, (uint8_t)buf[i]);
  return crc;
}

#endif /* SPIROGRAPH_VIEW_H */
