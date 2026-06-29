/* raycaster.h — shared, PURE Wolfenstein-style grid raycaster: the single source of truth for the
 * host oracle (tools/raycaster-sim.c), the corpus differential slice
 * (examples/snes/corpus/raycaster_sim.c), and the on-screen renderer (examples/snes/raycaster.c).
 * Same body on host (int = 32) and the 65816 target (int = 16), so host == target bit-for-bit by
 * construction — every width cast is load-bearing.
 *
 * For each screen column a ray is cast through a 16×16 wall grid by integer DDA (no per-step
 * trig — only adds/compares), and the wall slice height is screen_h / perpendicular_distance — a
 * per-column DIVIDE. That reciprocal-per-column is the declared codegen stress; nothing else in the
 * battery is division-bound. The DDA's deltaDist = |1/rayDir| adds two more divides per column.
 *
 * Codegen under test: `__udivsi3` (the deltaDist reciprocals + the wall-height 1/dist) + Q8.8
 * fixed-point multiply/shift + the sin/cos LUT for the camera basis. All integer ⇒ host == target;
 * no far pointers (16×16 map in bank-0 WRAM) ⇒ the full 5-way bar. See
 * docs/plans/2026-06-28-15-snes-raycaster.md. */
#ifndef RAYCASTER_H
#define RAYCASTER_H

#include <stdint.h>

#ifndef RC_FN
#define RC_FN __attribute__((noinline)) static
#endif

/* 256-entry signed Q8.8 sine LUT (round(256·sin(2π·a/256)), ±256). cos(a)=sin(a+64). Same table as
 * spiro.h / harmonograph.h, inlined so the header is self-contained + host-linkable. */
static const int16_t RC_SIN_LUT[256] = {
     0,    6,   13,   19,   25,   31,   38,   44,   50,   56,   62,   68,   74,   80,   86,   92,
    98,  104,  109,  115,  121,  126,  132,  137,  142,  147,  152,  157,  162,  167,  172,  177,
   181,  185,  190,  194,  198,  202,  206,  209,  213,  216,  220,  223,  226,  229,  231,  234,
   237,  239,  241,  243,  245,  247,  248,  250,  251,  252,  253,  254,  255,  255,  256,  256,
   256,  256,  256,  255,  255,  254,  253,  252,  251,  250,  248,  247,  245,  243,  241,  239,
   237,  234,  231,  229,  226,  223,  220,  216,  213,  209,  206,  202,  198,  194,  190,  185,
   181,  177,  172,  167,  162,  157,  152,  147,  142,  137,  132,  126,  121,  115,  109,  104,
    98,   92,   86,   80,   74,   68,   62,   56,   50,   44,   38,   31,   25,   19,   13,    6,
     0,   -6,  -13,  -19,  -25,  -31,  -38,  -44,  -50,  -56,  -62,  -68,  -74,  -80,  -86,  -92,
   -98, -104, -109, -115, -121, -126, -132, -137, -142, -147, -152, -157, -162, -167, -172, -177,
  -181, -185, -190, -194, -198, -202, -206, -209, -213, -216, -220, -223, -226, -229, -231, -234,
  -237, -239, -241, -243, -245, -247, -248, -250, -251, -252, -253, -254, -255, -255, -256, -256,
  -256, -256, -256, -255, -255, -254, -253, -252, -251, -250, -248, -247, -245, -243, -241, -239,
  -237, -234, -231, -229, -226, -223, -220, -216, -213, -209, -206, -202, -198, -194, -190, -185,
  -181, -177, -172, -167, -162, -157, -152, -147, -142, -137, -132, -126, -121, -115, -109, -104,
   -98,  -92,  -86,  -80,  -74,  -68,  -62,  -56,  -50,  -44,  -38,  -31,  -25,  -19,  -13,   -6,
};
#define RC_COS(a) (RC_SIN_LUT[(uint8_t)((a) + 64u)])
#define RC_SIN(a) (RC_SIN_LUT[(uint8_t)(a)])

#define RC_W   16u    /* map width  in cells */
#define RC_H   16u    /* map height in cells */
#define RC_VIEWH 128  /* projection-plane height (px) — the canvas height */
#define RC_PLANE 169  /* camera-plane half-width tan(FOV/2) ≈ 0.66 in Q8.8 → ~66° FOV */
#define RC_MAXSTEP 48u
/* "infinite" deltaDist for an axis-aligned ray (rayDir component 0). Must exceed any real
 * accumulated sideDist (≤ RC_MAXSTEP·65536 ≈ 3.1M, so that axis is never stepped) BUT keep the
 * initial `frac·RC_HUGE` (frac ≤ 256) within signed int32 — 256·0x400000 = 0x40000000 < 2^31. A
 * larger value (e.g. 0x3FFFFFF) overflows that product → signed-overflow UB the host/target builds
 * optimise differently → a host≠target gate failure. */
#define RC_HUGE  ((int32_t)0x400000)

/* 16×16 wall grid: 1 = wall, 0 = empty. A border ring plus interior rooms/corridors — a small maze
 * the auto-walker wanders. Row 0 is the top (north). */
static const uint8_t RC_MAP[RC_W * RC_H] = {
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1,
  1,0,1,1,0,0,1,0,1,1,1,1,1,0,0,1,
  1,0,1,0,0,0,0,0,1,0,0,0,1,0,0,1,
  1,0,1,0,1,1,1,0,1,0,1,0,1,0,1,1,
  1,0,0,0,1,0,0,0,0,0,1,0,0,0,0,1,
  1,1,1,0,1,0,1,1,1,1,1,1,1,1,0,1,
  1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1,
  1,0,1,1,1,0,1,0,1,1,1,0,1,1,0,1,
  1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,1,
  1,1,1,0,1,1,1,1,1,0,1,1,0,1,0,1,
  1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,
  1,0,1,1,1,1,0,1,1,1,1,0,1,1,1,1,
  1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,
  1,0,0,0,1,1,1,0,1,1,1,1,1,0,0,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
};

static inline uint8_t rc_wall(int16_t cx, int16_t cy) {
  if ((uint16_t)cx >= RC_W || (uint16_t)cy >= RC_H) return 1u;   /* outside = solid */
  return RC_MAP[(uint16_t)cy * RC_W + (uint16_t)cx];
}

/* Result of one ray: perpendicular distance (Q8.8 world cells) + which wall side was hit
 * (0 = vertical / x-grid, 1 = horizontal / y-grid → used for shading). */
typedef struct { int32_t dist; uint8_t side; } rc_hit;

/* Cast one ray from (px,py) (Q8.8 world position) in direction (rdx,rdy) (Q8.8, need not be unit).
 * Integer DDA: deltaDist = |65536/rayDir| (the reciprocal divide), march cell-to-cell choosing the
 * nearer grid crossing, stop at the first wall. perpDist is taken from the crossing distance so the
 * projection is fisheye-free. The two reciprocals + the marching adds are the hot codegen. */
RC_FN void rc_cast(int16_t px, int16_t py, int16_t rdx, int16_t rdy, rc_hit *out) {
  int16_t mapx = (int16_t)(px >> 8), mapy = (int16_t)(py >> 8);
  int16_t ax = (int16_t)(rdx < 0 ? -rdx : rdx);
  int16_t ay = (int16_t)(rdy < 0 ? -rdy : rdy);
  int32_t ddx = ax ? (int32_t)65536 / ax : RC_HUGE;                /* |1/rayDirX| (Q8.8) — divide */
  int32_t ddy = ay ? (int32_t)65536 / ay : RC_HUGE;                /* |1/rayDirY| (Q8.8) — divide */
  int16_t stepx, stepy;
  int32_t sdx, sdy;
  if (rdx < 0) { stepx = -1; sdx = (int32_t)(px - (mapx << 8)) * ddx >> 8; }
  else         { stepx =  1; sdx = (int32_t)(((mapx + 1) << 8) - px) * ddx >> 8; }
  if (rdy < 0) { stepy = -1; sdy = (int32_t)(py - (mapy << 8)) * ddy >> 8; }
  else         { stepy =  1; sdy = (int32_t)(((mapy + 1) << 8) - py) * ddy >> 8; }

  uint8_t side = 0;
  for (uint8_t i = 0; i < RC_MAXSTEP; i++) {
    if (sdx < sdy) { sdx += ddx; mapx = (int16_t)(mapx + stepx); side = 0; }
    else           { sdy += ddy; mapy = (int16_t)(mapy + stepy); side = 1; }
    if (rc_wall(mapx, mapy)) break;
  }
  out->side = side;
  out->dist = (side == 0) ? (sdx - ddx) : (sdy - ddy);            /* perpendicular distance (Q8.8) */
  if (out->dist < 16) out->dist = 16;                              /* clamp (avoid /0 in projection) */
}

/* Project a ray hit to a wall-slice height in pixels: RC_VIEWH·256 / perpDist (the headline 1/dist
 * divide), clamped to the view height. */
RC_FN int16_t rc_wall_height(int32_t dist) {
  int32_t h = ((int32_t)RC_VIEWH * 256) / dist;                    /* screen_h / dist — divide (32-bit: 128*256 overflows int16) */
  if (h > RC_VIEWH) h = RC_VIEWH;
  return (int16_t)h;
}

/* Camera state: position (Q8.8) + heading angle (uint8 turn). */
typedef struct { int16_t px, py; uint8_t ang; } rc_cam;

/* Compute the ray direction for screen column x of NCOL using the camera-plane method (fisheye-free).
 * camX ∈ [−1,1) in Q8.8; rayDir = dir + plane·camX. */
static inline void rc_ray_dir(const rc_cam *c, int16_t camX, int16_t *rdx, int16_t *rdy) {
  int16_t dirx = RC_COS(c->ang), diry = RC_SIN(c->ang);
  int16_t plx = (int16_t)(-diry);                                  /* plane = (−dirY, dirX) ⟂ dir */
  int16_t ply = dirx;
  plx = (int16_t)(((int32_t)plx * RC_PLANE) >> 8);
  ply = (int16_t)(((int32_t)ply * RC_PLANE) >> 8);
  *rdx = (int16_t)(dirx + (((int32_t)plx * camX) >> 8));
  *rdy = (int16_t)(diry + (((int32_t)ply * camX) >> 8));
}

/* Cheap 16-bit rotate-left-xor rolling hash (the spiro.h idiom). */
static inline uint16_t rc_fold(uint16_t h, int16_t v) {
  uint16_t hi = (uint16_t)((h >> 15) & 1u);
  return (uint16_t)((((uint16_t)(h << 1)) | hi) ^ (uint16_t)v);
}

#define RC_GATE_NCOL 64u   /* rays folded by the gate (a 64-column fan from a fixed camera) */

/* The differential gate: cast a 64-column fan from a fixed camera and fold each ray's wall height +
 * side into a rolling hash — a codegen defect in any divide / DDA add / LUT perturbs the hash. */
RC_FN uint16_t rc_gate_crc(void) {
  rc_cam c;
  c.px = (int16_t)((4 << 8) | 0x80);   /* (4.5, 11.5) — in the long E-W corridor (map row 11) */
  c.py = (int16_t)((11 << 8) | 0x80);
  c.ang = 0u;                           /* facing east (+x) down the corridor */
  uint16_t h = 0;
  for (uint16_t x = 0; x < RC_GATE_NCOL; x++) {
    int16_t camX = (int16_t)((int32_t)(2 * (int16_t)x - (int16_t)RC_GATE_NCOL) * 256 / (int16_t)RC_GATE_NCOL);
    int16_t rdx, rdy;
    rc_ray_dir(&c, camX, &rdx, &rdy);
    rc_hit hit;
    rc_cast(c.px, c.py, rdx, rdy, &hit);
    h = rc_fold(h, rc_wall_height(hit.dist));
    h = rc_fold(h, (int16_t)hit.side);
  }
  return h;
}

#endif /* RAYCASTER_H */
