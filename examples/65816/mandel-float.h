// #21 SNES compiler stress-test — SINGLE-PRECISION SOFT-FLOAT Mandelbrot escape-time kernel.
//
// SINGLE SOURCE OF TRUTH shared by the on-target program (examples/snes/mandel-float.c), the corpus
// slice (examples/snes/corpus/mandel-float_sim.c) and the host oracle (tools/mandel-float-sim.c).
//
// Why this demo exists: every other demo in the battery does its math in FIXED-POINT integer
// (Q-format multiply, carry chains). NONE use `float`. This one renders the Mandelbrot set in
// IEEE-754 `float`, so on the 65816 — which has no FPU — EVERY arithmetic op is a soft-float
// libcall: __mulsf3 (z*z, z*z, zr*zi), __addsf3 / __subsf3 (the recurrence + escape sum),
// __divsf3 (window step = span/width), __gtsf2 (the |z|^2 > 4 escape test), __floatsisf
// (int pixel index -> float) and __fixsfsi. That whole library is otherwise UNTESTED by the
// battery.
//
// BIT-EXACT DIFFERENTIAL — the sharp part. Single precision is fully specified: +,-,*,/ and the
// comparisons are all CORRECTLY ROUNDED (round-to-nearest-even), so a conforming soft-float on the
// 65816 must produce results IDENTICAL to host x86 single-precision, bit for bit. The one way that
// could break is fused multiply-add CONTRACTION (a*b+c fused on the host, separate libcalls on the
// target → 1-ULP divergence). We forbid it BY CONSTRUCTION: every arithmetic operation below is its
// OWN statement storing to a named `float` temp, so no expression ever contains an `a*b (+/-) c`
// pattern for the optimizer to fuse. Do NOT merge two ops into one expression — it is load-bearing
// for the gate. (Baseline `cc -O2` with no -march has no FMA instruction anyway; dev/mandel-float.sh
// additionally builds the oracle with -ffp-contract=off as belt-and-suspenders.)
#ifndef MANDEL_FLOAT_H
#define MANDEL_FLOAT_H

#include <stdint.h>

#define MF_ESCAPE 4.0f   /* |z|^2 > 4.0 escapes */

// Zoom path: baked windows {re0, im0, re_span, im_span} as float literals. A decimal float literal
// is converted to the nearest float by the front-end with the same round-to-nearest rule on host
// and target, so these constants are bit-identical everywhere. W0 frames the whole set; W1..W5 zoom
// toward the classic seahorse-spiral point (-0.743644, 0.131826). im_span = re_span * 56/64 (the
// 64x56 display aspect) so the on-screen image is undistorted.
#define MF_NWIN 6
static const float MF_WIN[MF_NWIN][4] = {
  /* re0,        im0,         re_span,  im_span */
  { -2.20000f,  -1.40000f,    3.20000f, 2.80000f  },   /* W0: whole set                       */
  { -1.343644f, -0.392174f,   1.20000f, 1.05000f  },   /* W1: zoom 1                          */
  { -0.943644f, -0.043174f,   0.40000f, 0.35000f  },   /* W2: zoom 2 (seahorse valley edge)   */
  { -0.803644f,  0.079326f,   0.12000f, 0.10500f  },   /* W3: zoom 3                          */
  { -0.763644f,  0.114326f,   0.04000f, 0.03500f  },   /* W4: zoom 4                          */
  { -0.750644f,  0.125701f,   0.01400f, 0.01225f  },   /* W5: zoom 5 (deep spiral)            */
};

// Escape count for one point c = (cr, ci), z0 = 0. The soft-float hot loop: three __mulsf3
// (zr*zr, zi*zi, zr*zi), several __addsf3/__subsf3, one __gtsf2 per iteration. ONE OP PER STATEMENT
// (no FMA-able a*b+c). noinline mirrors julia_cell: the float regs cross the call boundary every
// pixel and inlining the whole grid into one function piles every iteration's live ranges together.
__attribute__((noinline)) static uint8_t mf_cell(float cr, float ci, uint8_t maxiter) {
  float zr = 0.0f, zi = 0.0f;
  uint8_t n;
  for (n = 0; n < maxiter; n++) {
    float zr2 = zr * zr;          /* __mulsf3 */
    float zi2 = zi * zi;          /* __mulsf3 */
    float mag = zr2 + zi2;        /* __addsf3 */
    if (mag > MF_ESCAPE) break;   /* __gtsf2  */
    float diff = zr2 - zi2;       /* __subsf3 */
    float zrn = diff + cr;        /* __addsf3 */
    float cross = zr * zi;        /* __mulsf3 */
    float two_cross = cross + cross; /* __addsf3 (== 2*zr*zi, but no mul-by-literal to fuse) */
    float zin = two_cross + ci;   /* __addsf3 */
    zr = zrn;
    zi = zin;
  }
  return n;
}

// Fill a w*h row-major escape buffer for window `win` = {re0, im0, re_span, im_span}. The per-pixel
// step is DERIVED at runtime (dre = re_span / w via __divsf3) so host == target by construction at
// ANY grid size (the gate uses 6x6, the display 32x28 — both call this exact code).
static inline void mf_fill(uint8_t *fb, uint8_t w, uint8_t h, const float *win, uint8_t maxiter) {
  float re0 = win[0], im0 = win[1];
  float fw = (float)w;             /* __floatsisf */
  float fh = (float)h;
  float dre = win[2] / fw;         /* __divsf3 */
  float dim = win[3] / fh;         /* __divsf3 */
  for (uint8_t j = 0; j < h; j++) {
    float fj = (float)j;           /* __floatsisf */
    float jdim = fj * dim;         /* __mulsf3 */
    float ci = im0 + jdim;         /* __addsf3 */
    for (uint8_t i = 0; i < w; i++) {
      float fi = (float)i;         /* __floatsisf */
      float idre = fi * dre;       /* __mulsf3 */
      float cr = re0 + idre;       /* __addsf3 */
      uint16_t idx = (uint16_t)((uint16_t)j * w + i);
      fb[idx] = mf_cell(cr, ci, maxiter);
    }
  }
}

// Fiery low-to-high palette (5-bit BGR555 channels); interior (n>=maxiter) is black. Same shape as
// julia_palette so the Mode-7 CGRAM renders the bands consistently.
static inline void mf_palette(uint8_t n, uint8_t maxiter, uint8_t *r5, uint8_t *g5, uint8_t *b5) {
  if (n >= maxiter) { *r5 = 0; *g5 = 0; *b5 = 0; return; }
  uint8_t t = (uint8_t)((unsigned)n * 31u / (maxiter ? maxiter : 1));   // 0..31
  *r5 = t;
  *g5 = (uint8_t)((t < 16) ? (t * 2) : 31);
  *b5 = (uint8_t)(31 - t);
}

// CRC16-CCITT (XModem) over the escape buffer — identical routine to julia_crc. A match proves the
// ENTIRE soft-float-computed buffer is byte-identical host vs target.
static inline uint16_t mf_crc(const uint8_t *fb, uint16_t len) {
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

// Reinterpret a float as its raw IEEE-754 32-bit pattern (well-defined union type-pun in C). Used by
// the bit-exact witness below to fold the EXACT float result, not a derived integer.
static inline uint32_t mf_bits(float f) {
  union { float f; uint32_t u; } x;
  x.f = f;
  return x.u;
}

// BIT-EXACT soft-float witness: iterate the Mandelbrot recurrence at a fixed INTERIOR c=(-0.5, 0.0)
// (inside the main cardioid → z stays bounded, no overflow to inf), folding the RAW 32-bit bits of
// |z|^2 each step into an FNV-1a accumulator. Because every op is its own statement (no FMA), the
// folded bits are bit-for-bit identical host vs target — this is the sharp "single precision is
// fully specified" claim. The FNV mix (acc * 16777619u) is a bonus 32-bit __mulsi3.
static inline uint32_t mf_orbit_bits(float cr, float ci, uint8_t iters) {
  float zr = 0.0f, zi = 0.0f;
  uint32_t acc = 0x811C9DC5u;      /* FNV-1a offset basis */
  for (uint8_t n = 0; n < iters; n++) {
    float zr2 = zr * zr;
    float zi2 = zi * zi;
    float mag = zr2 + zi2;
    acc ^= mf_bits(mag);
    acc = (uint32_t)(acc * 16777619u);   /* __mulsi3 */
    float diff = zr2 - zi2;
    float zrn = diff + cr;
    float cross = zr * zi;
    float two_cross = cross + cross;
    float zin = two_cross + ci;
    zr = zrn;
    zi = zin;
  }
  return acc;
}

#define MF_GATE_W     6u    /* gate grid width                                   */
#define MF_GATE_H     6u    /* gate grid height                                  */
#define MF_GATE_ITER 12u    /* gate maxiter                                      */
#define MF_GATE_ORBIT 24u   /* bit-exact witness iterations                      */

// Differential anchor: fold the escape buffers of two windows (W0 whole-set, W2 zoom — a good mix of
// escaped/interior pixels) into a rotate-xor of their CRC16s, then XOR in the 32-bit bit-exact orbit
// witness. Sized to finish well inside the corpus harness's 180-frame / 3-second budget while still
// issuing several thousand soft-float libcalls. Far-pointer-free (36-byte low-WRAM static buffer),
// so the corpus slice runs the FULL 5-way differential (host == default == +mos-a16 == +mos-xy16).
static inline uint16_t mf_gate_crc(void) {
  static uint8_t buf[MF_GATE_W * MF_GATE_H];
  uint16_t h = 0;
  uint8_t gw[2] = { 0u, 2u };
  for (uint8_t g = 0; g < 2; g++) {
    mf_fill(buf, (uint8_t)MF_GATE_W, (uint8_t)MF_GATE_H, MF_WIN[gw[g]], (uint8_t)MF_GATE_ITER);
    uint16_t c = mf_crc(buf, (uint16_t)(MF_GATE_W * MF_GATE_H));
    h = (uint16_t)((uint16_t)(((unsigned)h << 1) | ((unsigned)h >> 15)) ^ c);
  }
  uint32_t w = mf_orbit_bits(-0.5f, 0.0f, (uint8_t)MF_GATE_ORBIT);
  h ^= (uint16_t)(w & 0xFFFFu);
  h = (uint16_t)((uint16_t)(((unsigned)h << 1) | ((unsigned)h >> 15)) ^ (uint16_t)(w >> 16));
  return h;
}

#endif /* MANDEL_FLOAT_H */
