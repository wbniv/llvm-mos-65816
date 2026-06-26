/* Space Invaders — portable, HAL-free game simulation (host + SNES compile the SAME header).
 *
 * This is the differential proof channel: the SNES game and the host oracle (tools/invaders-sim.c)
 * run the IDENTICAL deterministic "attract" sequence (no joypad — a scripted AI driven by a
 * fixed-seed xorshift), and both fold the evolving state into a CRC16. host == default@MAME ==
 * a16@MAME == a16@bsnes-jg (and the corpus 5-way default==a16==xy16) proves the codegen across the
 * 16-bit-accumulator / index modes.
 *
 * Correctness discipline (load-bearing): `int` is 16-bit on the SNES, 32-bit on the host, so EVERY
 * narrowing / product carries an explicit width cast, and the CRC is taken over an explicit
 * serializer (a fixed byte order), never over the raw struct (host/target padding differs).
 * Uses only <stdint.h>; no <snes.h>, no HAL. */
#ifndef INVADERS_LOGIC_H
#define INVADERS_LOGIC_H

#include <stdint.h>

/* Canonical attract length — shared by the game, the host oracle, and the corpus slice so the
   golden CRC can't drift between them. */
#ifndef INV_FRAMES
#define INV_FRAMES 600
#endif

/* ---- geometry (pixels) ---- */
#define INV_COLS       11
#define INV_ROWS       5
#define INV_NALIEN     55
#define INV_NBOMB      4
#define INV_SCRW       256
#define INV_SCRH       224
#define INV_DX         18          /* alien column spacing */
#define INV_DY         15          /* alien row spacing    */
#define INV_ALIEN_W    14
#define INV_ALIEN_H    9
#define INV_MARGIN     12          /* fleet turn-around margin */
#define INV_STEP       2           /* fleet horizontal step / move */
#define INV_DROP       8           /* fleet step-down / edge hit */
#define INV_PLAYER_Y   194
#define INV_PLAYER_W   15
#define INV_PLAYER_H   8
#define INV_PBUL_DY    6           /* player shot speed (up)   */
#define INV_BOMB_DY    3           /* alien bomb speed (down)  */
#define INV_BOMB_W     2
#define INV_BOMB_H     6
#define INV_UFO_Y      18
#define INV_UFO_W      16
#define INV_FLEET_Y0   28          /* fleet top on a fresh wave */

typedef struct {
  uint16_t alive[INV_ROWS];        /* bit c set => alien (row,c) alive (low 11 bits) */
  uint8_t  alive_count;
  int16_t  fleet_x, fleet_y;       /* top-left of the (row0,col0) alien cell */
  int8_t   dir;                    /* +1 / -1 */
  uint8_t  move_timer, move_period;
  uint8_t  anim;                   /* 0/1 two-frame */
  int16_t  player_x;
  uint8_t  player_cool;
  int16_t  pbul_x, pbul_y; uint8_t pbul_live;
  int16_t  bomb_x[INV_NBOMB], bomb_y[INV_NBOMB]; uint8_t bomb_live[INV_NBOMB];
  uint8_t  bomb_timer;
  int16_t  ufo_x; uint8_t ufo_live; int8_t ufo_dir; uint16_t ufo_timer;
  uint16_t score;
  uint8_t  lives;
  uint8_t  wave;
  uint16_t frame;
  uint16_t rng;
} inv_state;

/* xorshift16(7,9,8) — fixed seed; the casts pin the width on a 16-bit int. */
static uint16_t inv_rng(inv_state *s) {
  uint16_t x = s->rng;
  x ^= (uint16_t)(x << 7);
  x ^= (uint16_t)(x >> 9);
  x ^= (uint16_t)(x << 8);
  s->rng = x;
  return x;
}

static uint8_t inv_popcount(const inv_state *s) {
  uint8_t n = 0;
  for (uint8_t r = 0; r < INV_ROWS; r++) {
    uint16_t m = s->alive[r];
    while (m) { n = (uint8_t)(n + (m & 1u)); m = (uint16_t)(m >> 1); }
  }
  return n;
}

static uint8_t inv_period(uint8_t count) {       /* fewer aliens => shorter period => speed-up */
  return (uint8_t)(2 + (count >> 1));
}

/* per-row score value: top rows worth more (squid 30, crab 20/20, octopus 10/10). */
static uint16_t inv_row_value(uint8_t row) {
  return (row == 0) ? 30u : (row <= 2 ? 20u : 10u);
}

static void inv_fleet_reset(inv_state *s, uint8_t wave) {
  for (uint8_t r = 0; r < INV_ROWS; r++) s->alive[r] = 0x07FF;   /* 11 columns */
  s->alive_count = INV_NALIEN;
  s->fleet_x = INV_MARGIN;
  s->fleet_y = (int16_t)(INV_FLEET_Y0 + (int16_t)((wave & 7) * 6));
  s->dir = 1;
  s->move_timer = 0;
  s->move_period = inv_period(INV_NALIEN);
  s->anim = 0;
}

static void inv_init(inv_state *s) {
  for (uint8_t i = 0; i < INV_NBOMB; i++) { s->bomb_live[i] = 0; s->bomb_x[i] = 0; s->bomb_y[i] = 0; }
  inv_fleet_reset(s, 0);
  s->player_x = (int16_t)((INV_SCRW - INV_PLAYER_W) / 2);
  s->player_cool = 0;
  s->pbul_live = 0; s->pbul_x = 0; s->pbul_y = 0;
  s->bomb_timer = 24;
  s->ufo_x = 0; s->ufo_live = 0; s->ufo_dir = 1; s->ufo_timer = 400;
  s->score = 0;
  s->lives = 3;
  s->wave = 0;
  s->frame = 0;
  s->rng = 0xACE1u;
}

/* alien (row,col) top-left pixel, given the fleet origin. */
static int16_t inv_alien_x(const inv_state *s, uint8_t col) { return (int16_t)(s->fleet_x + (int16_t)((uint16_t)col * INV_DX)); }
static int16_t inv_alien_y(const inv_state *s, uint8_t row) { return (int16_t)(s->fleet_y + (int16_t)((uint16_t)row * INV_DY)); }

static uint8_t inv_alive(const inv_state *s, uint8_t row, uint8_t col) {
  return (uint8_t)((s->alive[row] >> col) & 1u);
}

/* lowest alive alien in a column (returns row+1, or 0 if column empty). */
static uint8_t inv_lowest_in_col(const inv_state *s, uint8_t col) {
  for (uint8_t r = INV_ROWS; r > 0; r--)
    if (inv_alive(s, (uint8_t)(r - 1), col)) return r;
  return 0;
}

static uint8_t inv_aabb(int16_t ax, int16_t ay, uint8_t aw, uint8_t ah,
                        int16_t bx, int16_t by, uint8_t bw, uint8_t bh) {
  return (uint8_t)(ax < (int16_t)(bx + bw) && (int16_t)(ax + aw) > bx &&
                   ay < (int16_t)(by + bh) && (int16_t)(ay + ah) > by);
}

/* --- the fleet's column extents (for edge turn-around), from the alive bitmaps --- */
static void inv_fleet_cols(const inv_state *s, uint8_t *lo, uint8_t *hi) {
  uint8_t l = INV_COLS - 1, h = 0; uint8_t any = 0;
  for (uint8_t c = 0; c < INV_COLS; c++) {
    uint8_t col_alive = 0;
    for (uint8_t r = 0; r < INV_ROWS; r++) if (inv_alive(s, r, c)) { col_alive = 1; break; }
    if (col_alive) { if (!any) { l = c; any = 1; } h = c; }
  }
  *lo = any ? l : 0; *hi = any ? h : 0;
}

/* ONE simulation frame. No joypad: the player is a scripted attract AI. noinline bounds a16
   register pressure (handoff §4), exactly like mandel_cell / k_prng. */
#if defined(__clang__) || defined(__GNUC__)
__attribute__((noinline))
#endif
static void inv_step(inv_state *s) {
  s->frame = (uint16_t)(s->frame + 1);

  /* ---- fleet march ---- */
  if (s->alive_count == 0) { s->wave = (uint8_t)(s->wave + 1); inv_fleet_reset(s, s->wave); }
  if (s->move_timer) s->move_timer = (uint8_t)(s->move_timer - 1);
  else {
    s->move_timer = s->move_period;
    s->anim ^= 1u;
    uint8_t lo, hi; inv_fleet_cols(s, &lo, &hi);
    int16_t left  = inv_alien_x(s, lo);
    int16_t right = (int16_t)(inv_alien_x(s, hi) + INV_ALIEN_W);
    if (s->dir > 0 && right >= (int16_t)(INV_SCRW - INV_MARGIN)) {
      s->dir = -1; s->fleet_y = (int16_t)(s->fleet_y + INV_DROP);
    } else if (s->dir < 0 && left <= INV_MARGIN) {
      s->dir = 1;  s->fleet_y = (int16_t)(s->fleet_y + INV_DROP);
    } else {
      s->fleet_x = (int16_t)(s->fleet_x + (int16_t)(s->dir * INV_STEP));
    }
  }

  /* ---- scripted player AI (deterministic attract) ---- */
  if (s->player_cool) s->player_cool = (uint8_t)(s->player_cool - 1);
  /* focus on the UFO if present, else a (slowly wandering) alive column */
  int16_t target;
  if (s->ufo_live) target = s->ufo_x;
  else {
    uint8_t fc = (uint8_t)((s->frame >> 4) % INV_COLS);          /* sweep columns over time   */
    if ((inv_rng(s) & 0x3f) == 0) fc = (uint8_t)(inv_rng(s) % INV_COLS);  /* occasional jump   */
    uint8_t tries = 0;
    while (!inv_lowest_in_col(s, fc) && tries < INV_COLS) { fc = (uint8_t)((fc + 1) % INV_COLS); tries++; }
    target = (int16_t)(inv_alien_x(s, fc) + (INV_ALIEN_W - INV_PLAYER_W) / 2);
  }
  if (s->player_x < target) s->player_x = (int16_t)(s->player_x + 2);
  else if (s->player_x > target) s->player_x = (int16_t)(s->player_x - 2);
  if (s->player_x < 8) s->player_x = 8;
  if (s->player_x > (int16_t)(INV_SCRW - INV_PLAYER_W - 8)) s->player_x = (int16_t)(INV_SCRW - INV_PLAYER_W - 8);
  if (!s->pbul_live && !s->player_cool && (int16_t)(target - s->player_x) > -6 && (int16_t)(target - s->player_x) < 6) {
    s->pbul_live = 1; s->player_cool = 18;
    s->pbul_x = (int16_t)(s->player_x + INV_PLAYER_W / 2);
    s->pbul_y = INV_PLAYER_Y;
  }

  /* ---- player shot ---- */
  if (s->pbul_live) {
    s->pbul_y = (int16_t)(s->pbul_y - INV_PBUL_DY);
    if (s->pbul_y < 0) s->pbul_live = 0;
  }

  /* ---- alien bombs: spawn + fall ---- */
  if (s->bomb_timer) s->bomb_timer = (uint8_t)(s->bomb_timer - 1);
  else {
    s->bomb_timer = (uint8_t)(20 + (inv_rng(s) & 0x1f));
    uint8_t col = (uint8_t)(inv_rng(s) % INV_COLS);
    uint8_t low = inv_lowest_in_col(s, col);
    if (low) {
      for (uint8_t i = 0; i < INV_NBOMB; i++) if (!s->bomb_live[i]) {
        s->bomb_live[i] = 1;
        s->bomb_x[i] = (int16_t)(inv_alien_x(s, col) + INV_ALIEN_W / 2);
        s->bomb_y[i] = (int16_t)(inv_alien_y(s, (uint8_t)(low - 1)) + INV_ALIEN_H);
        break;
      }
    }
  }
  for (uint8_t i = 0; i < INV_NBOMB; i++) if (s->bomb_live[i]) {
    s->bomb_y[i] = (int16_t)(s->bomb_y[i] + INV_BOMB_DY);
    if (s->bomb_y[i] > INV_SCRH) s->bomb_live[i] = 0;
  }

  /* ---- UFO ---- */
  if (s->ufo_live) {
    s->ufo_x = (int16_t)(s->ufo_x + (int16_t)(s->ufo_dir * 1));
    if (s->ufo_x < -INV_UFO_W || s->ufo_x > INV_SCRW) s->ufo_live = 0;
  } else if (s->ufo_timer) s->ufo_timer = (uint16_t)(s->ufo_timer - 1);
  else {
    s->ufo_timer = (uint16_t)(360 + (inv_rng(s) & 0xff));
    s->ufo_live = 1;
    if (inv_rng(s) & 1) { s->ufo_dir = 1;  s->ufo_x = (int16_t)(-INV_UFO_W); }
    else                { s->ufo_dir = -1; s->ufo_x = (int16_t)INV_SCRW; }
  }

  /* ---- collisions: player shot vs fleet ---- */
  if (s->pbul_live) {
    int16_t rx = (int16_t)(s->pbul_x - s->fleet_x);
    int16_t ry = (int16_t)(s->pbul_y - s->fleet_y);
    if (rx >= 0 && ry >= 0) {
      uint8_t col = (uint8_t)((uint16_t)rx / INV_DX);
      uint8_t row = (uint8_t)((uint16_t)ry / INV_DY);
      if (col < INV_COLS && row < INV_ROWS && inv_alive(s, row, col) &&
          inv_aabb(s->pbul_x, s->pbul_y, 1, 4,
                   inv_alien_x(s, col), inv_alien_y(s, row), INV_ALIEN_W, INV_ALIEN_H)) {
        s->alive[row] = (uint16_t)(s->alive[row] & (uint16_t)~(1u << col));
        s->alive_count = (uint8_t)(s->alive_count - 1);
        s->score = (uint16_t)(s->score + inv_row_value(row));
        s->pbul_live = 0;
        s->move_period = inv_period(s->alive_count);
      }
    }
  }
  /* player shot vs UFO */
  if (s->pbul_live && s->ufo_live &&
      inv_aabb(s->pbul_x, s->pbul_y, 1, 4, s->ufo_x, INV_UFO_Y, INV_UFO_W, INV_ALIEN_H)) {
    s->score = (uint16_t)(s->score + 100u + (uint16_t)((inv_rng(s) & 3) * 50u));
    s->pbul_live = 0; s->ufo_live = 0;
  }
  /* alien bombs vs player */
  for (uint8_t i = 0; i < INV_NBOMB; i++) if (s->bomb_live[i] &&
      inv_aabb(s->bomb_x[i], s->bomb_y[i], INV_BOMB_W, INV_BOMB_H,
               s->player_x, INV_PLAYER_Y, INV_PLAYER_W, INV_PLAYER_H)) {
    s->bomb_live[i] = 0;
    if (s->lives) s->lives = (uint8_t)(s->lives - 1);
    s->player_x = (int16_t)((INV_SCRW - INV_PLAYER_W) / 2);
    if (s->lives == 0) { s->lives = 3; s->score = 0; s->wave = 0; inv_fleet_reset(s, 0); }  /* attract: loop */
  }
}

/* serialize the state into a fixed byte order (NOT a struct memcpy). */
static uint16_t inv_serialize(const inv_state *s, uint8_t *b) {
  uint16_t n = 0;
  for (uint8_t r = 0; r < INV_ROWS; r++) { b[n++] = (uint8_t)s->alive[r]; b[n++] = (uint8_t)(s->alive[r] >> 8); }
  b[n++] = s->alive_count;
  b[n++] = (uint8_t)s->fleet_x; b[n++] = (uint8_t)(s->fleet_x >> 8);
  b[n++] = (uint8_t)s->fleet_y; b[n++] = (uint8_t)(s->fleet_y >> 8);
  b[n++] = (uint8_t)s->dir; b[n++] = s->anim;
  b[n++] = (uint8_t)s->player_x; b[n++] = (uint8_t)(s->player_x >> 8);
  b[n++] = s->pbul_live; b[n++] = (uint8_t)s->pbul_x; b[n++] = (uint8_t)(s->pbul_y);
  for (uint8_t i = 0; i < INV_NBOMB; i++) { b[n++] = s->bomb_live[i]; b[n++] = (uint8_t)s->bomb_y[i]; }
  b[n++] = s->ufo_live; b[n++] = (uint8_t)s->ufo_x; b[n++] = (uint8_t)(s->ufo_x >> 8);
  b[n++] = (uint8_t)s->score; b[n++] = (uint8_t)(s->score >> 8);
  b[n++] = s->lives; b[n++] = s->wave;
  b[n++] = (uint8_t)s->rng; b[n++] = (uint8_t)(s->rng >> 8);
  return n;
}

/* CRC16-CCITT (XModem) — the mandel.h routine (promotion-safe casts). */
static uint16_t inv_crc16(const uint8_t *p, uint16_t len) {
  uint16_t crc = 0xFFFF;
  for (uint16_t k = 0; k < len; k++) {
    crc ^= (uint16_t)((uint16_t)p[k] << 8);
    for (uint8_t i = 0; i < 8; i++)
      crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
  }
  return crc;
}

static uint16_t inv_state_crc(const inv_state *s) {
  uint8_t buf[64];
  uint16_t n = inv_serialize(s, buf);
  return inv_crc16(buf, n);
}

/* Cheap, width-safe per-frame fold (rotate-left-3 of the accumulator, XOR a mix of key state).
   rng is in the mix, so any mid-run divergence cascades — sensitive without a per-frame CRC16.
   The GAME folds with this identical helper each frame so its rolling value matches inv_run_crc. */
static uint16_t inv_fold(uint16_t roll, const inv_state *s) {
  uint16_t v = s->rng;
  v ^= (uint16_t)(s->score * 131u);
  v ^= (uint16_t)((uint16_t)s->fleet_x << 3);
  v ^= (uint16_t)((uint16_t)s->fleet_y << 9);
  v ^= (uint16_t)s->player_x;
  v ^= (uint16_t)(s->alive_count * 7u);
  v ^= (uint16_t)(s->alive[0] ^ (uint16_t)(s->alive[2] << 5) ^ (uint16_t)(s->alive[4] << 10));
  v ^= (uint16_t)((uint16_t)(s->pbul_live ? s->pbul_y : (int16_t)0) << 1);
  v ^= (uint16_t)(s->ufo_live ? (uint16_t)s->ufo_x : 0u);
  return (uint16_t)((uint16_t)((uint16_t)(roll << 3) | (uint16_t)(roll >> 13)) ^ v);  /* rol3 ^ v */
}

/* Run N frames, folding each, then mix in one final full-state CRC (serializer coverage).
   The differential proof channel — cheap enough for a per-frame game loop. */
static uint16_t inv_run_crc(uint16_t frames) {
  inv_state s; inv_init(&s);
  uint16_t roll = 0xFFFF;
  for (uint16_t f = 0; f < frames; f++) {
    inv_step(&s);
    roll = inv_fold(roll, &s);
  }
  return (uint16_t)(roll ^ inv_state_crc(&s));
}

#endif /* INVADERS_LOGIC_H */
