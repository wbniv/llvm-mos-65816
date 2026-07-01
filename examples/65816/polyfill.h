// Shared, PURE polygon scanline-fill — host-linkable, no hardware.  Demo #36.
//
// The codegen corner: a **runtime-sized C99 VLA** (`int16_t xs[nv]`).  Every prior demo has a
// fixed-size stack frame; this one forces the soft-stack target to do a RUNTIME stack-pointer
// adjustment.  A tumbling star polygon whose vertex count `nv = 2*npoints` morphs at run time drives
// an even-odd scanline rasteriser: for each scanline the x-crossings of the polygon edges are
// collected into a VLA sized `nv` (the compiler cannot fold the size — it comes from `npoints`),
// sorted, and paired into filled spans.
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - vertex coords are int16_t; the r*cos placement casts to int32_t (a genuine __mulsi3)
//   - the crossing x = px + (y-yi)*(dx) / (dy) is a signed int32 divide (__divsi3), truncating
//     toward zero identically on host and target
//   - i*256/nv is an unsigned int32 divide (__udivsi3) by the runtime vertex count
//   - the folded quantity is the filled pixel AREA (uint32) — deterministic integer arithmetic
// See docs/plans/2026-06-30-36-snes-polyfill.md.
#ifndef POLYFILL_H
#define POLYFILL_H

#include <stdint.h>

// ---------------------------------------------------------------------------------------------
// Geometry configuration

#define PF_MAXP   8u                 // max star points
#define PF_MAXV  (2u * PF_MAXP)      // max vertices (16)
#define PF_CX    64                  // canvas centre x (128px canvas)
#define PF_CY    64                  // canvas centre y
#define PF_ROUT  52                  // outer radius (star tip)
#define PF_RIN   22                  // inner radius (star notch)
#define PF_YMIN  (PF_CY - PF_ROUT)   // scanline range covering the star (12..116)
#define PF_YMAX  (PF_CY + PF_ROUT)
#define PF_MORPH 24u                 // frames between +1 star point (npoints wraps 8->3)

// 256-entry signed Q8.8 sine LUT (256 == 1.0); cos(a) = sin(a+64).  Same table as wire3d.h.
static const int16_t PF_SIN_LUT[256] = {
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
#define PF_SIN(a) (PF_SIN_LUT[(uint8_t)(a)])
#define PF_COS(a) (PF_SIN_LUT[(uint8_t)((a) + 64)])

// ---------------------------------------------------------------------------------------------
// State

typedef struct {
    uint8_t  npoints;    // 3..8; nv = 2*npoints
    uint8_t  angle;      // rotation phase (0..255, wraps)
    uint16_t frame;      // frame counter (drives the morph schedule)
} pf_state;

static void pf_init(pf_state *s) {
    s->npoints = 3u;
    s->angle   = 0u;
    s->frame   = 0u;
}

// Compute the nv star vertices into px[]/py[] (both >= PF_MAXV).  Returns nv (= 2*npoints).
static uint16_t pf_verts(const pf_state *s, int16_t *px, int16_t *py) {
    uint16_t nv = (uint16_t)s->npoints * 2u;
    for (uint16_t i = 0; i < nv; i++) {
        // Even angular spacing; runtime unsigned 32-bit divide by nv (__udivsi3).
        uint8_t a = (uint8_t)((uint16_t)s->angle + (uint16_t)((uint32_t)i * 256u / nv));
        int16_t co = PF_COS(a);
        int16_t si = PF_SIN(a);
        int16_t r  = (i & 1u) ? (int16_t)PF_RIN : (int16_t)PF_ROUT;
        // (int32_t)r*co forces a genuine 32-bit multiply (__mulsi3); >>8 undoes the Q8.8 scale.
        px[i] = (int16_t)(PF_CX + (int16_t)(((int32_t)r * co) >> 8));
        py[i] = (int16_t)(PF_CY + (int16_t)(((int32_t)r * si) >> 8));
    }
    return nv;
}

// Even-odd x-crossings of scanline `y` with the polygon edges, written sorted into xs[] (the
// caller's runtime VLA, >= nv entries).  Returns the crossing count nx (even for a closed polygon).
static uint16_t pf_scan(const int16_t *px, const int16_t *py, uint16_t nv, int16_t y, int16_t *xs) {
    uint16_t nx = 0;
    uint16_t j  = nv - 1u;
    for (uint16_t i = 0; i < nv; i++) {
        int16_t yi = py[i], yj = py[j];
        // Half-open edge test: consistent at shared vertices, no double-count.
        if ((yi <= y && yj > y) || (yj <= y && yi > y)) {
            int32_t num = (int32_t)(y - yi) * (int32_t)(px[j] - px[i]);
            int16_t x   = (int16_t)((int32_t)px[i] + num / (int32_t)(yj - yi));  // __divsi3
            xs[nx++] = x;
        }
        j = i;
    }
    // Insertion-sort the crossings so even-odd span pairing is left-to-right.
    for (uint16_t a = 1u; a < nx; a++) {
        int16_t v = xs[a];
        uint16_t b = a;
        while (b > 0u && xs[b - 1u] > v) { xs[b] = xs[b - 1u]; b--; }
        xs[b] = v;
    }
    return nx;
}

// Fill the polygon by even-odd spans over [ymin,ymax], returning the total filled pixel area.
// The x-crossing table `xs` is a C99 VLA sized by the RUNTIME vertex count nv — the #36 stress:
// a soft-stack frame whose size is not known at compile time.
#ifndef PF_GATE_YSTEP
#define PF_GATE_YSTEP 4         // gate subsamples scanlines (still allocates the VLA + runs the divide
#endif                          // path every step) — keeps the startup self-check fast on real hardware.

static uint32_t pf_poly_area(const int16_t *px, const int16_t *py, uint16_t nv,
                             int16_t ymin, int16_t ymax) {
    int16_t xs[nv];                         // <-- runtime-sized VLA (alloca-style SP adjust)
    uint32_t area = 0;
    for (int16_t y = ymin; y <= ymax; y = (int16_t)(y + PF_GATE_YSTEP)) {
        uint16_t nx = pf_scan(px, py, nv, y, xs);
        for (uint16_t k = 0; k + 1u < nx; k += 2u) {
            int16_t x0 = xs[k], x1 = xs[k + 1u];
            if (x1 >= x0) area += (uint32_t)(uint16_t)(x1 - x0 + 1);
        }
    }
    return area;
}

// Advance rotation + morph the star point count.
static void pf_step(pf_state *s) {
    s->angle = (uint8_t)(s->angle + 3u);
    s->frame = (uint16_t)(s->frame + 1u);
    if (s->frame % PF_MORPH == 0u) {
        s->npoints = (uint8_t)(s->npoints + 1u);
        if (s->npoints > PF_MAXP) s->npoints = 3u;
    }
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t pf_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_FRAMES
#define GATE_FRAMES 16u    // folds the filled area of 16 morphing frames; each runs through the VLA.
#endif                     // Kept modest so the startup self-check finishes well before the assert frame.

static uint16_t polyfill_gate_crc(void) {
    pf_state s;
    pf_init(&s);
    uint16_t h = 0;
    for (uint16_t f = 0; f < (uint16_t)GATE_FRAMES; f++) {
        int16_t px[PF_MAXV], py[PF_MAXV];
        uint16_t nv = pf_verts(&s, px, py);
        uint32_t area = pf_poly_area(px, py, nv, (int16_t)PF_YMIN, (int16_t)PF_YMAX);
        h = pf_fold(h, (uint16_t)area);
        h = pf_fold(h, (uint16_t)(area >> 16));
        pf_step(&s);
    }
    return h;
}

#endif /* POLYFILL_H */
