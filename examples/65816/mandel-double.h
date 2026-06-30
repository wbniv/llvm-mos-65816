// #33 SNES compiler stress-test — DOUBLE-PRECISION soft-float Mandelbrot, beside a FLOAT twin.
//
// SINGLE SOURCE OF TRUTH shared by the on-target program (examples/snes/mandel-double.c), the corpus
// slice (examples/snes/corpus/mandel-double_sim.c) and the host oracle (tools/mandel-double-sim.c).
//
// Why this demo exists: #21 (mandel-float.h) renders the set in IEEE-754 SINGLE precision, exercising
// the 32-bit soft-float library (__mulsf3/__addsf3/__subsf3/__divsf3/__gtsf2/__floatsisf). NOTHING in
// the battery touches 64-bit `double`. This one iterates z^2+c in BOTH `double` AND `float`, so on the
// 65816 — which has no FPU — the double path is the entire DOUBLE-precision soft-float library:
// __muldf3 (z*z, zr*zi), __adddf3/__subdf3 (the recurrence + escape sum), __divdf3 (window step),
// __ltdf2/__gtdf2 (the |z|^2 > 4 escape test), __floatsidf (int pixel index -> double) and __fixdfsi.
// The float TWIN additionally pulls in __truncdfsf2 (double->float, casting the shared double window to
// float coords) and __extendsfdf2 (float->double round-trip witness). That whole 64-bit library is
// otherwise UNTESTED by the battery — #22's 64-bit *integer* family (__muldi3/__udivdi3) is disjoint
// from the 64-bit *float* family here.
//
// BIT-EXACT DIFFERENTIAL — the sharp part (the double analogue of #21). IEEE-754 double +,-,*,/ and the
// comparisons are ALL CORRECTLY ROUNDED (round-to-nearest-even), so a conforming soft-float on the
// 65816 must produce results IDENTICAL to host x86 double precision, bit for bit. The one way that could
// break is fused multiply-add CONTRACTION (a*b+c fused on the host, separate libcalls on the target).
// We forbid it BY CONSTRUCTION: every arithmetic op below is its OWN statement storing to a named temp,
// so no expression ever contains an `a*b (+/-) c` pattern for the optimizer to fuse. Do NOT merge two
// ops into one expression — it is load-bearing for the gate. (Baseline `cc -O2` with no -march has no
// FMA instruction anyway; dev/mandel-double.sh additionally builds the oracle with -ffp-contract=off.)
//
// THE VISUAL — the precision cliff. The on-screen split-screen renders a DEEP zoom window (re_span ~2e-6)
// in double on the top half and float on the bottom half. At that depth the per-pixel step (span/width)
// is far below float's ~1.2e-7 epsilon near magnitude 1, so adjacent pixels round to the SAME float
// coordinate -> the float half collapses into chunky blocks while the double half stays crisp. The
// blocky-vs-smooth seam IS the proof that real 64-bit floating point is running on the console.
#ifndef MANDEL_DOUBLE_H
#define MANDEL_DOUBLE_H

#include <stdint.h>

#define MD_ESCAPE 4.0   /* |z|^2 > 4.0 escapes (a double literal) */

// Zoom path: baked windows {re0, im0, re_span, im_span} as DOUBLE literals. A decimal literal is
// converted to the nearest double by the front-end with the same round-to-nearest rule on host and
// target, so these constants are bit-identical everywhere. W0 frames the whole set; W1..W4 zoom toward
// the classic seahorse-spiral point (-0.743644, 0.131826). im_span = re_span * 56/64 (the 64x56 display
// aspect) so the on-screen image is undistorted. W4 is DEEP (re_span 2e-6) — the float-vs-double cliff.
#define MD_NWIN 5
static const double MD_WIN[MD_NWIN][4] = {
  /* re0,             im0,              re_span,    im_span    */
  { -2.2000000,      -1.4000000,        3.2000000,  2.8000000 },   /* W0: whole set                  */
  { -1.0436440,      -0.0431740,        0.6000000,  0.5250000 },   /* W1: zoom toward seahorse       */
  { -0.7536440,       0.1218260,        0.0200000,  0.0175000 },   /* W2: seahorse spiral            */
  { -0.7437440,       0.1317260,        0.0010000,  0.0008750 },   /* W3: deeper                     */
  { -0.7436450,       0.1318250,        0.0000020,  0.0000017 },   /* W4: DEEP (float pixelates here)*/
};

// Escape count for one point c = (cr, ci), z0 = 0, computed in DOUBLE. The soft-float hot loop: three
// __muldf3 (zr*zr, zi*zi, zr*zi), several __adddf3/__subdf3, one __ltdf2/__gtdf2 per iteration. ONE OP
// PER STATEMENT (no FMA-able a*b+c). noinline: the double regs (a register PAIR-of-pairs) cross the call
// boundary every pixel; inlining the whole grid piles every iteration's live ranges together.
__attribute__((noinline)) static uint8_t md_cell_double(double cr, double ci, uint8_t maxiter) {
  double zr = 0.0, zi = 0.0;
  uint8_t n;
  for (n = 0; n < maxiter; n++) {
    double zr2 = zr * zr;            /* __muldf3 */
    double zi2 = zi * zi;            /* __muldf3 */
    double mag = zr2 + zi2;          /* __adddf3 */
    if (mag > MD_ESCAPE) break;      /* __gtdf2  */
    double diff = zr2 - zi2;         /* __subdf3 */
    double zrn = diff + cr;          /* __adddf3 */
    double cross = zr * zi;          /* __muldf3 */
    double two_cross = cross + cross;/* __adddf3 (== 2*zr*zi, but no mul-by-literal to fuse) */
    double zin = two_cross + ci;     /* __adddf3 */
    zr = zrn;
    zi = zin;
  }
  return n;
}

// The FLOAT twin: identical recurrence in SINGLE precision. cr/ci arrive as float (the renderer casts
// the shared double window down with __truncdfsf2). Same shape as #21's mf_cell.
__attribute__((noinline)) static uint8_t md_cell_float(float cr, float ci, uint8_t maxiter) {
  float zr = 0.0f, zi = 0.0f;
  uint8_t n;
  for (n = 0; n < maxiter; n++) {
    float zr2 = zr * zr;             /* __mulsf3 */
    float zi2 = zi * zi;             /* __mulsf3 */
    float mag = zr2 + zi2;           /* __addsf3 */
    if (mag > (float)MD_ESCAPE) break;/* __gtsf2 */
    float diff = zr2 - zi2;          /* __subsf3 */
    float zrn = diff + cr;           /* __addsf3 */
    float cross = zr * zi;           /* __mulsf3 */
    float two_cross = cross + cross; /* __addsf3 */
    float zin = two_cross + ci;      /* __addsf3 */
    zr = zrn;
    zi = zin;
  }
  return n;
}

// Fill a w*h row-major escape buffer for window `win` in DOUBLE. The per-pixel step is DERIVED at
// runtime (dre = re_span / w via __divdf3) so host == target by construction at ANY grid size.
static inline void md_fill_double(uint8_t *fb, uint8_t w, uint8_t h, const double *win, uint8_t maxiter) {
  double re0 = win[0], im0 = win[1];
  double fw = (double)w;             /* __floatsidf */
  double fh = (double)h;
  double dre = win[2] / fw;          /* __divdf3 */
  double dim = win[3] / fh;          /* __divdf3 */
  for (uint8_t j = 0; j < h; j++) {
    double fj = (double)j;           /* __floatsidf */
    double jdim = fj * dim;          /* __muldf3 */
    double ci = im0 + jdim;          /* __adddf3 */
    for (uint8_t i = 0; i < w; i++) {
      double fi = (double)i;         /* __floatsidf */
      double idre = fi * dre;        /* __muldf3 */
      double cr = re0 + idre;        /* __adddf3 */
      uint16_t idx = (uint16_t)((uint16_t)j * w + i);
      fb[idx] = md_cell_double(cr, ci, maxiter);
    }
  }
}

// The FLOAT twin fill: the SAME double window, but coordinates derived in float. Casting win[*] (double)
// down to float is __truncdfsf2 — the conversion corner. At a deep window the float pixel step underflows
// and the image blocks; that divergence-from-double is the visual, NOT a gate failure (each precision is
// internally host==target bit-exact).
static inline void md_fill_float(uint8_t *fb, uint8_t w, uint8_t h, const double *win, uint8_t maxiter) {
  float re0 = (float)win[0];         /* __truncdfsf2 */
  float im0 = (float)win[1];         /* __truncdfsf2 */
  float fw = (float)w;               /* __floatsisf */
  float fh = (float)h;
  float dre = (float)win[2] / fw;    /* __truncdfsf2 then __divsf3 */
  float dim = (float)win[3] / fh;
  for (uint8_t j = 0; j < h; j++) {
    float fj = (float)j;             /* __floatsisf */
    float jdim = fj * dim;           /* __mulsf3 */
    float ci = im0 + jdim;           /* __addsf3 */
    for (uint8_t i = 0; i < w; i++) {
      float fi = (float)i;           /* __floatsisf */
      float idre = fi * dre;         /* __mulsf3 */
      float cr = re0 + idre;         /* __addsf3 */
      uint16_t idx = (uint16_t)((uint16_t)j * w + i);
      fb[idx] = md_cell_float(cr, ci, maxiter);
    }
  }
}

// Fiery low-to-high palette (5-bit BGR555 channels); interior (n>=maxiter) is black. Identical shape to
// mf_palette so the Mode-7 CGRAM renders both halves' bands consistently.
static inline void md_palette(uint8_t n, uint8_t maxiter, uint8_t *r5, uint8_t *g5, uint8_t *b5) {
  if (n >= maxiter) { *r5 = 0; *g5 = 0; *b5 = 0; return; }
  uint8_t t = (uint8_t)((unsigned)n * 31u / (maxiter ? maxiter : 1));   // 0..31
  *r5 = t;
  *g5 = (uint8_t)((t < 16) ? (t * 2) : 31);
  *b5 = (uint8_t)(31 - t);
}

// CRC16-CCITT (XModem) over the escape buffer — identical routine to mf_crc. A match proves the ENTIRE
// soft-float-computed buffer is byte-identical host vs target.
static inline uint16_t md_crc(const uint8_t *fb, uint16_t len) {
  uint16_t crc = 0xFFFF;
  for (uint16_t k = 0; k < len; k++) {
    crc ^= (uint16_t)((uint16_t)fb[k] << 8);
    for (uint8_t b = 0; b < 8; b++) {
      if (crc & 0x8000)
        crc = (uint16_t)((uint16_t)(crc << 1) ^ 0x1021);
      else
        crc = (uint16_t)(crc << 1);
    }
  }
  return crc;
}

// Reinterpret a double as its raw IEEE-754 64-bit pattern, returning the two 32-bit halves (well-defined
// union type-pun in C). Used by the bit-exact witness below to fold the EXACT double result.
static inline void md_bits(double d, uint32_t *hi, uint32_t *lo) {
  union { double d; uint32_t u[2]; } x;
  x.d = d;
  // Index 0/1 ordering is consistent host vs target (both little-endian); we fold BOTH halves so the
  // particular order is irrelevant to the differential — only that host and target agree, which they do.
  *lo = x.u[0];
  *hi = x.u[1];
}

// BIT-EXACT double soft-float witness: iterate the Mandelbrot recurrence at a fixed INTERIOR
// c=(-0.5, 0.0) (inside the main cardioid -> z stays bounded, no overflow to inf), folding the RAW 64-bit
// bits of |z|^2 each step into a 32-bit FNV-1a accumulator (both halves). Because every op is its own
// statement (no FMA), the folded bits are bit-for-bit identical host vs target — the sharp "double is
// fully specified" claim. The FNV mix (acc * 16777619u) is a bonus 32-bit __mulsi3.
static inline uint32_t md_orbit_bits(double cr, double ci, uint8_t iters) {
  double zr = 0.0, zi = 0.0;
  uint32_t acc = 0x811C9DC5u;        /* FNV-1a offset basis */
  for (uint8_t n = 0; n < iters; n++) {
    double zr2 = zr * zr;
    double zi2 = zi * zi;
    double mag = zr2 + zi2;
    uint32_t hi, lo;
    md_bits(mag, &hi, &lo);
    acc ^= lo;
    acc = (uint32_t)(acc * 16777619u);   /* __mulsi3 */
    acc ^= hi;
    acc = (uint32_t)(acc * 16777619u);   /* __mulsi3 */
    double diff = zr2 - zi2;
    double zrn = diff + cr;
    double cross = zr * zi;
    double two_cross = cross + cross;
    double zin = two_cross + ci;
    zr = zrn;
    zi = zin;
  }
  return acc;
}

// CONVERSION round-trip witness: for a handful of doubles, narrow to float (__truncdfsf2) and widen back
// (__extendsfdf2), folding the raw 64-bit bits of the result. Correctly-rounded narrowing then exact
// widening is fully specified, so host == target bit-exact — and it forces BOTH conversion libcalls the
// escape loops alone wouldn't cover. The inputs are exact-in-float values plus values that round, so the
// fold actually depends on the rounding.
static inline uint32_t md_convert_witness(void) {
  static const double in[6] = { 0.5, -0.5, 0.7436450, 3.1415926535897932,
                                -2.2000000, 0.0000020 };
  uint32_t acc = 0x811C9DC5u;
  for (uint8_t k = 0; k < 6; k++) {
    float f = (float)in[k];          /* __truncdfsf2 */
    double back = (double)f;         /* __extendsfdf2 */
    uint32_t hi, lo;
    md_bits(back, &hi, &lo);
    acc ^= lo; acc = (uint32_t)(acc * 16777619u);
    acc ^= hi; acc = (uint32_t)(acc * 16777619u);
  }
  return acc;
}

#define MD_GATE_W     5u    /* gate grid width  (kept small: double soft-float is ~2-3x float)    */
#define MD_GATE_H     5u    /* gate grid height                                                   */
#define MD_GATE_ITER  6u    /* gate maxiter                                                       */
#define MD_GATE_ORBIT 12u   /* bit-exact witness iterations                                       */

// Differential anchor: fold a DOUBLE escape buffer (W0 whole-set, good escaped/interior mix) and a FLOAT
// escape buffer of the SAME window into a rotate-xor of their CRC16s, then XOR in the 32-bit double
// bit-exact orbit witness and the conversion witness. Sized to finish well inside the corpus harness's
// 180-frame / 3-second budget while still issuing well over a thousand 64-bit soft-float libcalls.
// Far-pointer-free (two 25-byte low-WRAM static buffers), so the corpus slice runs the FULL 5-way
// differential (host == default == +mos-a16 == +mos-xy16).
static inline uint16_t md_gate_crc(void) {
  static uint8_t dbuf[MD_GATE_W * MD_GATE_H];
  static uint8_t fbuf[MD_GATE_W * MD_GATE_H];
  uint16_t h = 0;

  md_fill_double(dbuf, (uint8_t)MD_GATE_W, (uint8_t)MD_GATE_H, MD_WIN[0], (uint8_t)MD_GATE_ITER);
  uint16_t cd = md_crc(dbuf, (uint16_t)(MD_GATE_W * MD_GATE_H));
  h = (uint16_t)((uint16_t)(((unsigned)h << 1) | ((unsigned)h >> 15)) ^ cd);

  md_fill_float(fbuf, (uint8_t)MD_GATE_W, (uint8_t)MD_GATE_H, MD_WIN[0], (uint8_t)MD_GATE_ITER);
  uint16_t cf = md_crc(fbuf, (uint16_t)(MD_GATE_W * MD_GATE_H));
  h = (uint16_t)((uint16_t)(((unsigned)h << 1) | ((unsigned)h >> 15)) ^ cf);

  uint32_t w = md_orbit_bits(-0.5, 0.0, (uint8_t)MD_GATE_ORBIT);
  h ^= (uint16_t)(w & 0xFFFFu);
  h = (uint16_t)((uint16_t)(((unsigned)h << 1) | ((unsigned)h >> 15)) ^ (uint16_t)(w >> 16));

  uint32_t cv = md_convert_witness();
  h ^= (uint16_t)(cv & 0xFFFFu);
  h = (uint16_t)((uint16_t)(((unsigned)h << 1) | ((unsigned)h >> 15)) ^ (uint16_t)(cv >> 16));

  return h;
}

#endif /* MANDEL_DOUBLE_H */
