// Shared, PURE Gouraud-triangle rasteriser — host-linkable, no hardware.  Demo #69.
//
// The codegen corner: **barycentric edge-function rasterisation** — three signed 2-D cross-product
// EDGE FUNCTIONS decide inside/outside per pixel (all three signs agree), and their values ARE the
// barycentric weights that INTERPOLATE a per-vertex attribute across the face (a per-pixel divide by
// the triangle's doubled area).  #16 (wireframe) drew Bresenham *lines* only — it never filled a face
// nor interpolated across one.  The edge function `(bx-ax)(py-ay) - (by-ay)(px-ax)` is an int32 cross
// product (`__mulsi3`); the barycentric normalise is an int32 divide (`__divsi3`) on the hot per-pixel
// path — a fill-loop shape none of the first 68 demos run.
//
// Everything is integer (positions int16, edge/area/interp int32) — no float, so bit-exact host vs
// target by construction.  See docs/plans/2026-06-30-69-snes-gouraud.md.
#ifndef GOURAUD_H
#define GOURAUD_H

#include <stdint.h>

// 256-entry signed Q8.8 sine LUT (same table as wire3d.h / spiro.h), inlined so the header is
// self-contained and host-linkable.  GS_SIN[a] = round(256*sin(2*pi*a/256)); cos(a) = sin(a+64).
static const int16_t GS_SIN_LUT[256] = {
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
#define GS_SIN(a) (GS_SIN_LUT[(uint8_t)(a)])
#define GS_COS(a) (GS_SIN_LUT[(uint8_t)((a) + 64)])

// A triangle vertex: 2-D screen position + one interpolated attribute (a brightness 0..255).
typedef struct { int16_t x, y; int16_t a; } GVert;

// The signed 2-D cross product / EDGE FUNCTION: twice the signed area of triangle (A,B,P).  > 0 when P
// is left of directed edge A->B (for our winding), < 0 right, 0 on the line.  int32 to hold the product
// of two ~9-bit differences without overflow -> __mulsi3.
static inline int32_t gs_edge(int16_t ax, int16_t ay, int16_t bx, int16_t by, int16_t px, int16_t py) {
    return (int32_t)(bx - ax) * (int32_t)(py - ay) - (int32_t)(by - ay) * (int32_t)(px - ax);
}

// Spin the three vertices of an equilateral triangle of radius r about (cx,cy) by LUT angle `rot`,
// assigning fixed per-vertex attributes 40 / 150 / 255.  120 deg = 256/3 ~= 85 LUT steps.
static void gs_make_tri(uint8_t rot, int16_t cx, int16_t cy, int16_t r, GVert v[3]) {
    static const uint8_t PH[3] = { 0u, 85u, 170u };
    static const int16_t AT[3] = { 40, 150, 255 };
    for (uint8_t k = 0u; k < 3u; k++) {
        uint8_t ang = (uint8_t)(rot + PH[k]);
        v[k].x = (int16_t)(cx + (int16_t)(((int32_t)GS_COS(ang) * r) >> 8));
        v[k].y = (int16_t)(cy + (int16_t)(((int32_t)GS_SIN(ang) * r) >> 8));
        v[k].a = AT[k];
    }
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t gs_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 2u          // number of tumble orientations rasterised into the gate (kept light so the
#endif                     // synchronous startup gate settles well before the title card fades)

// Rasterise triangle v[0..2] over its integer bounding box: at each pixel compute the three edge
// functions; inside = all three same sign as the (doubled) area; then BARYCENTRIC-INTERPOLATE the
// attribute  I = (e0*a0 + e1*a1 + e2*a2) / area  (one __divsi3) and fold I mixed with the pixel
// position (so a symmetric triangle can't cancel to 0).  Returns the updated hash.
static uint16_t gs_raster_fold(uint16_t h, const GVert v[3]) {
    int32_t area = gs_edge(v[0].x, v[0].y, v[1].x, v[1].y, v[2].x, v[2].y);
    if (area == 0) return h;                       // degenerate — skip (no /0)
    int16_t s = (int16_t)(area > 0 ? 1 : -1);      // winding sign; edge fns must match it to be inside

    int16_t minx = v[0].x, maxx = v[0].x, miny = v[0].y, maxy = v[0].y;
    for (uint8_t k = 1u; k < 3u; k++) {
        if (v[k].x < minx) minx = v[k].x;
        if (v[k].x > maxx) maxx = v[k].x;
        if (v[k].y < miny) miny = v[k].y;
        if (v[k].y > maxy) maxy = v[k].y;
    }
    for (int16_t py = miny; py <= maxy; py++) {
        for (int16_t px = minx; px <= maxx; px++) {
            int32_t e0 = gs_edge(v[1].x, v[1].y, v[2].x, v[2].y, px, py);   // opposite vertex 0
            int32_t e1 = gs_edge(v[2].x, v[2].y, v[0].x, v[0].y, px, py);   // opposite vertex 1
            int32_t e2 = gs_edge(v[0].x, v[0].y, v[1].x, v[1].y, px, py);   // opposite vertex 2
            int16_t in = (int16_t)(((s > 0) ? (e0 >= 0 && e1 >= 0 && e2 >= 0)
                                            : (e0 <= 0 && e1 <= 0 && e2 <= 0)) ? 1 : 0);
            if (!in) continue;
            int32_t num = e0 * (int32_t)v[0].a + e1 * (int32_t)v[1].a + e2 * (int32_t)v[2].a;
            int32_t I = num / area;                                        // <-- barycentric divide
            uint16_t mix = (uint16_t)(((uint16_t)(px & 0xFFu) << 8) ^ (uint16_t)(py & 0xFFu)
                                      ^ (uint16_t)(I & 0xFFFFu));
            h = gs_fold(h, mix);
        }
    }
    return h;
}

// Fold GATE_N tumble orientations of a small triangle.  A miscompile in the edge-function cross
// products, the winding/inside test, or the per-pixel barycentric divide diverges the hash.
static uint16_t gouraud_gate_crc(void) {
    uint16_t h = 0u;
    uint8_t rot = 17u;
    for (uint16_t i = 0u; i < (uint16_t)GATE_N; i++) {
        GVert v[3];
        gs_make_tri(rot, 32, 32, 10, v);
        h = gs_raster_fold(h, v);
        rot = (uint8_t)(rot + 71u);                 // coprime-ish step -> well-separated orientations
    }
    return h;
}

#endif /* GOURAUD_H */
