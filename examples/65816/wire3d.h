// Shared, PURE 3-D wireframe math — the single source of truth for the host oracle
// (tools/wire3d-sim.c), the corpus differential slice (examples/snes/corpus/wire3d_sim.c), and the
// on-screen renderer (examples/snes/wireframe.c). Like examples/65816/spiro.h / mandel.h, this is the
// code under test for the differential: the SAME body runs on the host oracle (int = 32) and the 65816
// target (int = 16), so host == target bit-for-bit by construction. Keep every width cast load-bearing.
//
// Per frame the demo: builds a 3x3 rotation matrix from a sin/cos LUT (mat3_from_euler -> 2 mat3_mul),
// transforms each model vertex through it (project: matrix.vector), PERSPECTIVE-PROJECTS each to 2-D
// with a divide, and the renderer draws the model's edges as Bresenham lines (snesgfx/bitmap_canvas.h).
//
// The codegen this stresses (demo #16 of the battery — the 3-D / linear-algebra member): a 3x3 MATRIX
// MULTIPLY (Q8.8 fixed point, __mulsi3) AND a per-vertex PERSPECTIVE DIVIDE on the HOT path
// (__divsi3 / __udivsi3 — the divide-bound corner Mandelbrot/Spirograph don't hit) AND integer line
// rasterization. All-integer NEAR (no far pointers) => the program builds default-8 / +mos-a16 /
// +mos-xy16 and earns the full 5-way differential bar. See
// docs/plans/2026-06-27-16-snes-wireframe-3d-solid.md.
//
// NO hardware here (no snes.h, no MMIO) — host-linkable. Self-contained (LUT + solid tables inline).
#ifndef WIRE3D_H
#define WIRE3D_H

#include <stdint.h>

// Each stamped kernel is a separate noinline callee so its live range is bounded: under -Os the
// compiler otherwise inlines mat3_mul's 9 32-bit products + project's 9 products + 2 divides into one
// giant main(), and the combined +mos-a16/+mos-xy16 register pressure overflows the imaginary-register
// file (the handoff §4 pressure trap — same reason spiro.h's SPIRO_FN is noinline). Harmless on host.
#ifndef WIRE3_FN
#define WIRE3_FN __attribute__((noinline)) static
#endif

// ---------------------------------------------------------------------------------------------
// 256-entry signed Q8.8 sine LUT: WIRE3_SIN[a] = round(256 * sin(2*pi*a/256)), range +-256 (1.0 == 256).
// cos(a) = sin(a + 64). Identical table to examples/snes/sincos.h / spiro.h, inlined so the header is
// self-contained and host-linkable. Regenerate:
//   python3 -c 'import math;print(",".join(str(round(256*math.sin(2*math.pi*a/256))) for a in range(256)))'
static const int16_t WIRE3_SIN_LUT[256] = {
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
#define WIRE3_SIN(a) (WIRE3_SIN_LUT[(uint8_t)(a)])
#define WIRE3_COS(a) (WIRE3_SIN_LUT[(uint8_t)((a) + 64)])

// ---------------------------------------------------------------------------------------------
// Projection constants. WIRE3_DIST (camera distance) > the largest model radius so z = rz + DIST stays
// strictly > 0 (no /0, no sign flip — Risk R3). WIRE3_FOV scales the perspective divide so the largest
// solid (icosa, radius ~49) fills ~2/3 of the 128px canvas across the dolly range.
#define WIRE3_DIST  180
#define WIRE3_FOV   150
#define WIRE3_ZMIN    8     // clamp floor on z (defensive; the tables never reach it)

// ---------------------------------------------------------------------------------------------
// The polyhedron zoo (the "richness axis", like #11's curve families): tetra / cube / octa / icosa,
// each a distinct vertex/edge table through the SAME matrix+divide kernel. Vertices are integer model
// coordinates; edges are LOCAL vertex indices within a solid. Asset-free, generated by:
//   R=24; TET=[(R,R,R),(R,-R,-R),(-R,R,-R),(-R,-R,R)]; CUBE=[(x,y,z) for x in(-R,R)...]
//   A=34; OCTA=[(+-A,0,0),(0,+-A,0),(0,0,+-A)]; a,b=26,42; ICO=cyclic perms of (0,+-a,+-b)
//   edges = all vertex pairs at the (near-)minimal distance (icosa: within 5% — b/a=1.6154 ~ phi).
enum { WIRE3_TETRA = 0, WIRE3_CUBE = 1, WIRE3_OCTA = 2, WIRE3_ICOSA = 3, WIRE3_NSOLID = 4 };

#define WIRE3_NVERT 30u    // 4 + 8 + 6 + 12
#define WIRE3_NEDGE 60u    // 6 + 12 + 12 + 30

static const int16_t WIRE3_V[WIRE3_NVERT][3] = {
  { 24, 24, 24},{ 24,-24,-24},{-24, 24,-24},{-24,-24, 24},{-24,-24,-24},{-24,-24, 24},
  {-24, 24,-24},{-24, 24, 24},{ 24,-24,-24},{ 24,-24, 24},{ 24, 24,-24},{ 24, 24, 24},
  { 34,  0,  0},{-34,  0,  0},{  0, 34,  0},{  0,-34,  0},{  0,  0, 34},{  0,  0,-34},
  {  0,-26,-42},{-42,  0,-26},{-26,-42,  0},{  0,-26, 42},{-42,  0, 26},{-26, 42,  0},
  {  0, 26,-42},{ 42,  0,-26},{ 26,-42,  0},{  0, 26, 42},{ 42,  0, 26},{ 26, 42,  0},
};
static const uint8_t WIRE3_E[WIRE3_NEDGE][2] = {
  { 0, 1},{ 0, 2},{ 0, 3},{ 1, 2},{ 1, 3},{ 2, 3},{ 0, 1},{ 0, 2},{ 0, 4},{ 1, 3},
  { 1, 5},{ 2, 3},{ 2, 6},{ 3, 7},{ 4, 5},{ 4, 6},{ 5, 7},{ 6, 7},{ 0, 2},{ 0, 3},
  { 0, 4},{ 0, 5},{ 1, 2},{ 1, 3},{ 1, 4},{ 1, 5},{ 2, 4},{ 2, 5},{ 3, 4},{ 3, 5},
  { 0, 1},{ 0, 2},{ 0, 6},{ 0, 7},{ 0, 8},{ 1, 2},{ 1, 4},{ 1, 5},{ 1, 6},{ 2, 3},
  { 2, 4},{ 2, 8},{ 3, 4},{ 3, 8},{ 3, 9},{ 3,10},{ 4, 5},{ 4, 9},{ 5, 6},{ 5, 9},
  { 5,11},{ 6, 7},{ 6,11},{ 7, 8},{ 7,10},{ 7,11},{ 8,10},{ 9,10},{ 9,11},{10,11},
};
// Per-solid slices into WIRE3_V / WIRE3_E.
static const uint8_t WIRE3_VOFF[WIRE3_NSOLID] = { 0, 4, 12, 18 };
static const uint8_t WIRE3_NV[WIRE3_NSOLID]   = { 4, 8, 6, 12 };
static const uint8_t WIRE3_EOFF[WIRE3_NSOLID] = { 0, 6, 18, 30 };
static const uint8_t WIRE3_NE[WIRE3_NSOLID]   = { 6, 12, 12, 30 };

// ---------------------------------------------------------------------------------------------
// A 3x3 rotation matrix, row-major, entries Q8.8 (1.0 == 256).
typedef struct { int16_t m[9]; } mat3;

// o = a . b  (Q8.8 . Q8.8 -> Q8.8) — the declared 3x3 MATRIX MULTIPLY stress. 9 cells x 3 products =
// 27 (int32_t)*(int32_t) -> __mulsi3 per call; composing the per-axis rotations is two of these per frame.
WIRE3_FN void mat3_mul(const mat3 *a, const mat3 *b, mat3 *o) {
  for (uint8_t r = 0; r < 3; r++)
    for (uint8_t c = 0; c < 3; c++) {
      int32_t s = 0;
      for (uint8_t k = 0; k < 3; k++)
        s += (int32_t)a->m[r * 3 + k] * b->m[k * 3 + c];   /* Q8.8 * Q8.8 = Q16.16 */
      o->m[r * 3 + c] = (int16_t)(s >> 8);                 /* back to Q8.8 */
    }
}

// Build R = Rx . Ry . Rz from three uint8_t Euler angles (LUT phase). Each axis matrix's entries are
// {0, +-256(==1.0), +-cos, +-sin}; fold via two mat3_mul.
WIRE3_FN void mat3_from_euler(uint8_t ax, uint8_t ay, uint8_t az, mat3 *o) {
  int16_t cx = WIRE3_COS(ax), sx = WIRE3_SIN(ax);
  int16_t cy = WIRE3_COS(ay), sy = WIRE3_SIN(ay);
  int16_t cz = WIRE3_COS(az), sz = WIRE3_SIN(az);
  mat3 Rx = {{ 256, 0, 0,   0, cx, (int16_t)-sx,   0, sx, cx }};
  mat3 Ry = {{ cy, 0, sy,   0, 256, 0,   (int16_t)-sy, 0, cy }};
  mat3 Rz = {{ cz, (int16_t)-sz, 0,   sz, cz, 0,   0, 0, 256 }};
  mat3 t;
  mat3_mul(&Rx, &Ry, &t);   /* t = Rx . Ry  */
  mat3_mul(&t, &Rz, o);     /* o = t  . Rz  */
}

// Transform a model vertex by R (Q8.8 . integer -> integer), then PERSPECTIVE-PROJECT with a per-vertex
// DIVIDE (the declared division stress). z = rz + dist stays > 0 (dist > model radius); clamp to a floor
// defensively. (sx,sy) are centred on 0; the renderer offsets by the canvas centre. `dist` is a runtime
// parameter so the demo's L/R dolly works; the gate passes the fixed WIRE3_DIST.
WIRE3_FN void project(const mat3 *R, const int16_t v[3], int16_t dist, int16_t *osx, int16_t *osy) {
  int16_t rx = (int16_t)(((int32_t)R->m[0] * v[0] + (int32_t)R->m[1] * v[1] + (int32_t)R->m[2] * v[2]) >> 8);
  int16_t ry = (int16_t)(((int32_t)R->m[3] * v[0] + (int32_t)R->m[4] * v[1] + (int32_t)R->m[5] * v[2]) >> 8);
  int16_t rz = (int16_t)(((int32_t)R->m[6] * v[0] + (int32_t)R->m[7] * v[1] + (int32_t)R->m[8] * v[2]) >> 8);
  int16_t z  = (int16_t)(rz + dist);
  if (z < WIRE3_ZMIN) z = WIRE3_ZMIN;
  *osx = (int16_t)(((int32_t)rx * WIRE3_FOV) / z);     /* <-- perspective divide (__divsi3) */
  *osy = (int16_t)(((int32_t)ry * WIRE3_FOV) / z);     /* <-- perspective divide */
}

// ---------------------------------------------------------------------------------------------
// Cheap 16-bit rotate-left-xor rolling hash (the spiro_fold / mandel img_hash16 idiom): folds the full
// 16 bits of each projected coordinate. Proof channel: host hash == target hash over the same stream.
static inline uint16_t wire3_fold(uint16_t h, int16_t v) {
  uint16_t hi = (uint16_t)((h >> 15) & 1u);
  return (uint16_t)((((uint16_t)(h << 1)) | hi) ^ (uint16_t)v);
}

// The differential gate. The per-vertex PERSPECTIVE DIVIDE is a slow 32-bit libcall (__divsi3) on the
// hot path — by design (this is the division-stress demo) — so the gate must stay light enough that the
// SLOWEST build (default-8-bit) sets corpus_result well inside the corpus runner's 60-frame settle
// window (SMOKE_SETTLE; the spiro-gate sizing lesson). The compromise that keeps full coverage cheaply:
// project EACH of the 30 vertices exactly ONCE, but each at a DIFFERENT non-trivial orientation
// (i & (FRAMES-1) selects the frame), so the gate exercises every solid's vertex table AND the matrix
// multiply across WIRE3_GATE_FRAMES distinct rotations with only ~30 projects (~60 divides) total. A
// codegen defect in the matrix multiply, the perspective divide, or any vertex table perturbs the hash.
// Hash the projected-vertex stream, never the canvas (display frame-timing differs across emulators).
#define WIRE3_GATE_FRAMES 4u     // power of two -> the (i & 3) vertex->frame selector is a mask
#define WIRE3_GATE_AX0    11u    // non-trivial starting Euler angles (avoid the identity matrix at f=0)
#define WIRE3_GATE_AY0    23u
#define WIRE3_GATE_AZ0     7u
#define WIRE3_GATE_DAX    37u    // large coprime-ish deltas -> 4 well-separated orientations
#define WIRE3_GATE_DAY    53u
#define WIRE3_GATE_DAZ    29u

WIRE3_FN uint16_t wire3d_gate_crc(void) {
  uint16_t h = 0;
  uint8_t ax = WIRE3_GATE_AX0, ay = WIRE3_GATE_AY0, az = WIRE3_GATE_AZ0;
  for (uint8_t f = 0; f < WIRE3_GATE_FRAMES; f++) {
    mat3 R;
    mat3_from_euler(ax, ay, az, &R);
    for (uint8_t i = 0; i < (uint8_t)WIRE3_NVERT; i++) {
      if ((uint8_t)(i & (WIRE3_GATE_FRAMES - 1u)) != f) continue;   /* this vertex belongs to frame f */
      int16_t sx, sy;
      project(&R, WIRE3_V[i], WIRE3_DIST, &sx, &sy);
      h = wire3_fold(h, sx);
      h = wire3_fold(h, sy);
    }
    ax = (uint8_t)(ax + WIRE3_GATE_DAX);
    ay = (uint8_t)(ay + WIRE3_GATE_DAY);
    az = (uint8_t)(az + WIRE3_GATE_DAZ);
  }
  return h;
}

#endif /* WIRE3D_H */
