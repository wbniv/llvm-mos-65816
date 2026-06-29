// #26 SNES compiler stress-test — STRUCT-BY-VALUE (aggregate-return ABI) kernel: Reynolds boids.
//
// SINGLE SOURCE OF TRUTH shared by the on-target program (examples/snes/boids.c), the corpus slice
// (examples/snes/corpus/boids_sim.c) and the host oracle (tools/boids-sim.c).
//
// Why this demo exists: every Round-1 demo (and #21/#22) either never passes an aggregate by value or
// keeps its structs behind pointers (#18's heap). NONE pass or RETURN a `struct` by value. This one is
// built on a `vec2 { int16_t x, y; }` value type whose steering kernel — v2_add/v2_sub/v2_scale/
// v2_clampbox plus the three Reynolds rules (separation/alignment/cohesion) — TAKES and RETURNS `vec2`
// BY VALUE, and the composition chains those returns: v2_add(v2_add(sep, ali), coh). On the 65816 a
// 4-byte aggregate return forces the compiler to pick the aggregate-return ABI (small-struct register
// pair vs. an sret hidden pointer); the chain runs O(N^2) times per frame. That ABI path is otherwise
// UNTESTED by the battery.
//
// The vec functions are __attribute__((noinline)) ON PURPOSE: at -Os the optimiser would inline the
// whole kernel and the ABI would never be exercised. noinline keeps the real calls (and a disasm probe
// asserts they survive). Harmless on the host.
//
// BIT-EXACT DIFFERENTIAL: all math is integer fixed-point (Q12.4 world coords; int16_t components,
// products widened to int32_t -> __mulsi3, neighbour-count divides -> __divsi3). Exact integer ops are
// reproducible, so a conforming 65816 build must equal host x86 bit-for-bit; any aggregate-return /
// register-pair miscompile corrupts a component and the gate CRC diverges. Far-pointer-free (the flock
// lives in bank-0 WRAM) -> full 5-way bar.
#ifndef BOIDS_H
#define BOIDS_H

#include <stdint.h>

// ---- the value type that is the whole point -------------------------------------------------------
typedef struct { int16_t x, y; } vec2;        // Q12.4 fixed-point (16 units = 1 px)
typedef struct { vec2 pos, vel; } Boid;       // 8 bytes

// World is 256x224 px in Q12.4: x in [0,4096), y in [0,3584). Both fit int16_t (max 32767).
#define BOID_WORLD_W 4096
#define BOID_WORLD_H 3584
// Tunables (-D-overridable for host gain sweeps; the committed values are the gate's anchor).
#ifndef BOID_R2
#define BOID_R2      589824L     // (48 px = 768 units)^2 — flock (cohesion/alignment) neighbour radius
#endif
#ifndef BOID_RSEP2
#define BOID_RSEP2    65536L     // (16 px = 256 units)^2 — separation radius
#endif
#ifndef BOID_VMAX
#define BOID_VMAX        40      // speed cap (units/frame ~ 2.5 px)
#endif
#ifndef BOID_AMAX
#define BOID_AMAX        14      // accel cap (units/frame)
#endif
#ifndef BOID_COH_DEN
#define BOID_COH_DEN     40      // cohesion gain  = 1/40
#endif
#ifndef BOID_ALI_DEN
#define BOID_ALI_DEN     16      // alignment gain = 1/16
#endif
#ifndef BOID_SEP_DEN
#define BOID_SEP_DEN     40      // separation gain= 1/40
#endif
#ifndef BOID_CENTER_DEN
#define BOID_CENTER_DEN 256      // pull-to-centre = 1/256 (keeps the flock mid-screen)
#endif

#define BOID_NOINLINE static __attribute__((noinline))

// ---- by-value vec2 kernel (the aggregate-return ABI under test) -----------------------------------
BOID_NOINLINE vec2 v2_add(vec2 a, vec2 b) {
  vec2 r;
  r.x = (int16_t)((int32_t)a.x + b.x);
  r.y = (int16_t)((int32_t)a.y + b.y);
  return r;
}
BOID_NOINLINE vec2 v2_sub(vec2 a, vec2 b) {
  vec2 r;
  r.x = (int16_t)((int32_t)a.x - b.x);
  r.y = (int16_t)((int32_t)a.y - b.y);
  return r;
}
// (a * num) / den, componentwise — __mulsi3 (int32 product) + __divsi3 (signed, truncating).
BOID_NOINLINE vec2 v2_scale(vec2 a, int16_t num, int16_t den) {
  vec2 r;
  r.x = (int16_t)(((int32_t)a.x * num) / den);
  r.y = (int16_t)(((int32_t)a.y * num) / den);
  return r;
}
// clamp each component to [-m, m] (no sqrt) — a by-value pass-through.
BOID_NOINLINE vec2 v2_clampbox(vec2 a, int16_t m) {
  vec2 r = a;
  if (r.x >  m) r.x = m; else if (r.x < (int16_t)-m) r.x = (int16_t)-m;
  if (r.y >  m) r.y = m; else if (r.y < (int16_t)-m) r.y = (int16_t)-m;
  return r;
}
// squared distance — __mulsi3 (scalar; the neighbourhood test, not an ABI probe).
static inline int32_t v2_len2(vec2 a) {
  return (int32_t)a.x * a.x + (int32_t)a.y * a.y;
}

// ---- the three Reynolds rules — each RETURNS a vec2 BY VALUE ---------------------------------------
// Separation: steer away from neighbours closer than RSEP — sum of (pi - pj).
BOID_NOINLINE vec2 boid_separation(const Boid *f, uint8_t n, uint8_t i) {
  int32_t px = 0, py = 0;
  vec2 pi = f[i].pos;
  for (uint8_t j = 0; j < n; j++) {
    if (j == i) continue;
    vec2 d = v2_sub(pi, f[j].pos);             // by-value
    if (v2_len2(d) < BOID_RSEP2) { px += d.x; py += d.y; }
  }
  vec2 s; s.x = (int16_t)px; s.y = (int16_t)py;  // |sum| <= 256*(n-1) < 32767 for n<=128
  return v2_scale(s, 1, BOID_SEP_DEN);           // by-value return
}
// Alignment: steer toward the average velocity of flock-radius neighbours.
BOID_NOINLINE vec2 boid_alignment(const Boid *f, uint8_t n, uint8_t i) {
  int32_t vx = 0, vy = 0; int16_t cnt = 0;
  vec2 pi = f[i].pos;
  for (uint8_t j = 0; j < n; j++) {
    if (j == i) continue;
    vec2 d = v2_sub(f[j].pos, pi);
    if (v2_len2(d) < BOID_R2) { vx += f[j].vel.x; vy += f[j].vel.y; cnt++; }
  }
  if (cnt == 0) { vec2 z = { 0, 0 }; return z; }
  vec2 avg; avg.x = (int16_t)(vx / cnt); avg.y = (int16_t)(vy / cnt);   // __divsi3 (runtime cnt)
  vec2 steer = v2_sub(avg, f[i].vel);
  return v2_scale(steer, 1, BOID_ALI_DEN);
}
// Cohesion: steer toward the centre of mass of flock-radius neighbours.
BOID_NOINLINE vec2 boid_cohesion(const Boid *f, uint8_t n, uint8_t i) {
  int32_t sx = 0, sy = 0; int16_t cnt = 0;
  vec2 pi = f[i].pos;
  for (uint8_t j = 0; j < n; j++) {
    if (j == i) continue;
    vec2 d = v2_sub(f[j].pos, pi);
    if (v2_len2(d) < BOID_R2) { sx += f[j].pos.x; sy += f[j].pos.y; cnt++; }
  }
  if (cnt == 0) { vec2 z = { 0, 0 }; return z; }
  vec2 center; center.x = (int16_t)(sx / cnt); center.y = (int16_t)(sy / cnt);  // __divsi3
  vec2 steer = v2_sub(center, pi);
  return v2_scale(steer, 1, BOID_COH_DEN);
}

// Composition — chained aggregate returns + a gentle pull to world centre, capped to AMAX.
BOID_NOINLINE vec2 boid_acc(const Boid *f, uint8_t n, uint8_t i) {
  vec2 sep = boid_separation(f, n, i);
  vec2 ali = boid_alignment(f, n, i);
  vec2 coh = boid_cohesion(f, n, i);
  vec2 acc = v2_add(v2_add(sep, ali), coh);            // <-- the aggregate-return chain
  vec2 toc; toc.x = (int16_t)(BOID_WORLD_W / 2); toc.y = (int16_t)(BOID_WORLD_H / 2);
  acc = v2_add(acc, v2_scale(v2_sub(toc, f[i].pos), 1, BOID_CENTER_DEN));
  return v2_clampbox(acc, BOID_AMAX);
}

static inline int16_t boid_wrap(int16_t v, int16_t hi) {
  if (v < 0) v = (int16_t)(v + hi);
  else if (v >= hi) v = (int16_t)(v - hi);
  return v;
}

// One flocking step (in-place, sequential — deterministic Gauss-Seidel; identical order host & target).
static inline void boids_step(Boid *f, uint8_t n) {
  for (uint8_t i = 0; i < n; i++) {
    vec2 acc = boid_acc(f, n, i);
    vec2 nv = v2_clampbox(v2_add(f[i].vel, acc), BOID_VMAX);
    f[i].vel = nv;
    vec2 np = v2_add(f[i].pos, nv);
    np.x = boid_wrap(np.x, BOID_WORLD_W);
    np.y = boid_wrap(np.y, BOID_WORLD_H);
    f[i].pos = np;
  }
}

// xorshift16 — deterministic flock seeding (identical to the invaders_logic.h generator pattern).
static inline uint16_t boid_xs16(uint16_t s) {
  s ^= (uint16_t)(s << 7); s ^= (uint16_t)(s >> 9); s ^= (uint16_t)(s << 8); return s;
}
static inline void boids_init(Boid *f, uint8_t n, uint16_t seed) {
  uint16_t s = seed ? seed : (uint16_t)0xBEEF;
  for (uint8_t i = 0; i < n; i++) {
    s = boid_xs16(s); f[i].pos.x = (int16_t)(s % BOID_WORLD_W);
    s = boid_xs16(s); f[i].pos.y = (int16_t)(s % BOID_WORLD_H);
    s = boid_xs16(s); f[i].vel.x = (int16_t)((int16_t)(s & 63) - 32);
    s = boid_xs16(s); f[i].vel.y = (int16_t)((int16_t)(s & 63) - 32);
  }
}

// Heading octant 0..7 from a velocity — used to colour each boid (aligned birds share a hue, so the
// flock reads as coherent same-colour streams). Pure compares; shared so the visual stays portable.
static inline uint8_t boid_heading_oct(vec2 v) {
  int16_t ax = (int16_t)(v.x < 0 ? -v.x : v.x);
  int16_t ay = (int16_t)(v.y < 0 ? -v.y : v.y);
  if (v.x >= 0 && v.y >= 0) return (uint8_t)(ax >= ay ? 0 : 1);
  if (v.x <  0 && v.y >= 0) return (uint8_t)(ay >= ax ? 2 : 3);
  if (v.x <  0 && v.y <  0) return (uint8_t)(ax >= ay ? 4 : 5);
  return (uint8_t)(ay >= ax ? 6 : 7);
}

// ---- differential anchor --------------------------------------------------------------------------
#define BOID_GATE_BOIDS 8u
#define BOID_GATE_N     12u

// Run a fixed seeded flock BOID_GATE_N steps, then fold every boid's pos/vel into a rotate-XOR CRC16.
// The whole chain runs through the by-value ABI, so the CRC is a bit-exact witness of the aggregate-
// return path. Function-local static flock -> no soft-stack frame; far-pointer-free -> full 5-way bar.
static inline uint16_t boids_gate_crc(void) {
  static Boid gf[BOID_GATE_BOIDS];
  boids_init(gf, (uint8_t)BOID_GATE_BOIDS, 0x1234);
  for (uint8_t k = 0; k < (uint8_t)BOID_GATE_N; k++) boids_step(gf, (uint8_t)BOID_GATE_BOIDS);
  uint16_t h = 0;
  for (uint8_t i = 0; i < (uint8_t)BOID_GATE_BOIDS; i++) {
    uint16_t parts[4];
    parts[0] = (uint16_t)gf[i].pos.x; parts[1] = (uint16_t)gf[i].pos.y;
    parts[2] = (uint16_t)gf[i].vel.x; parts[3] = (uint16_t)gf[i].vel.y;
    for (uint8_t w = 0; w < 4; w++)
      h = (uint16_t)((uint16_t)(((unsigned)h << 1) | ((unsigned)h >> 15)) ^ parts[w]);
  }
  return h;
}

#endif /* BOIDS_H */
