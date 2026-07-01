// Shared, PURE marching-squares iso-contour extractor — host-linkable, no hardware.  Demo #71.
//
// The codegen corner: the **16-case marching-squares edge LUT** + **edge-crossing linear interpolation**.
// A scalar field (a sum of moving parabolic "metaball" domes) is sampled on a grid; each cell's four
// corners are thresholded against the iso value into a 4-bit CASE index (tl<<3|tr<<2|br<<1|bl); a
// 16-entry const table (MS_SEG) says which cell edges the contour crosses; and each crossing point is
// placed by interpolating `t = (iso - va)/(vb - va)` along the edge (a signed int32 divide).  #45
// rendered the metaball *field*; EXTRACTING its iso-contour is a separate case-table-indexing +
// edge-interpolation loop none of the first 70 demos run.
//
// Everything is integer (`int16` coords, `int32` field/interp) — no float, bit-exact host vs target.
// See docs/plans/2026-06-30-71-snes-msquares.md.
#ifndef MSQUARES_H
#define MSQUARES_H

#include <stdint.h>

#define MS_NB   3                    // number of metaball domes
#define MS_R2   1600                 // dome radius^2 (R = 40)
#define MS_ISO  700                  // iso-contour threshold
#define MS_SUB  16                   // sub-cell interpolation precision (crossing offset 0..16)

// The 16-case edge table.  Edges: 0=top(tl,tr) 1=right(tr,br) 2=bottom(bl,br) 3=left(tl,bl).  Each case
// lists up to two segments as edge pairs; 0xFF = none.  Case bit order tl=8 tr=4 br=2 bl=1.
static const uint8_t MS_SEG[16][4] = {
  {0xFF,0xFF,0xFF,0xFF}, {3,2,0xFF,0xFF}, {1,2,0xFF,0xFF}, {3,1,0xFF,0xFF},
  {0,1,0xFF,0xFF},       {0,3,1,2},       {0,2,0xFF,0xFF}, {0,3,0xFF,0xFF},
  {0,3,0xFF,0xFF},       {0,2,0xFF,0xFF}, {0,1,3,2},       {0,1,0xFF,0xFF},
  {3,1,0xFF,0xFF},       {1,2,0xFF,0xFF}, {3,2,0xFF,0xFF}, {0xFF,0xFF,0xFF,0xFF},
};

// The moving dome centres at time t (a small deterministic orbit, no trig needed for the gate).
static void ms_centers(uint16_t t, int16_t *cx, int16_t *cy) {
    cx[0] = (int16_t)(64 + (int16_t)((t * 3u) & 63u) - 32);
    cy[0] = (int16_t)(60 + (int16_t)((t * 2u) & 47u) - 24);
    cx[1] = (int16_t)(70 - (int16_t)((t * 2u) & 55u) + 27);
    cy[1] = (int16_t)(64 + (int16_t)((t * 3u) & 39u) - 20);
    cx[2] = (int16_t)(60 + (int16_t)((t * 4u) & 47u) - 24);
    cy[2] = (int16_t)(70 - (int16_t)((t * 3u) & 63u) + 32);
}

// The scalar field: sum of parabolic domes clamp(R^2 - (dx^2+dy^2), 0).  Smooth, integer, no divide.
static int32_t ms_field(int16_t x, int16_t y, const int16_t *cx, const int16_t *cy) {
    int32_t s = 0;
    for (uint8_t i = 0u; i < MS_NB; i++) {
        int32_t dx = (int32_t)(x - cx[i]);
        int32_t dy = (int32_t)(y - cy[i]);
        int32_t d2 = dx * dx + dy * dy;
        int32_t b = (int32_t)MS_R2 - d2;
        if (b > 0) s += b;
    }
    return s;
}

// Interpolate the iso crossing along an edge: returns the offset 0..MS_SUB from corner a toward b.
// (iso - va)*SUB / (vb - va) — the signed int32 edge-crossing DIVIDE.  Guarded against vb==va.
static int16_t ms_interp(int32_t va, int32_t vb) {
    int32_t d = vb - va;
    if (d == 0) return MS_SUB / 2;
    int32_t o = ((int32_t)(MS_ISO - va) * MS_SUB) / d;
    if (o < 0) o = 0; else if (o > MS_SUB) o = MS_SUB;
    return (int16_t)o;
}

// The crossing point of edge `e` in a cell, in sub-cell units (cell origin (cxu,cyu) scaled by MS_SUB).
// vtl/vtr/vbr/vbl are the field values at the four corners.  Fills *ox,*oy.
static void ms_edge_point(uint8_t e, int16_t cxu, int16_t cyu,
                          int32_t vtl, int32_t vtr, int32_t vbr, int32_t vbl,
                          int16_t *ox, int16_t *oy) {
    int16_t x0 = (int16_t)(cxu * MS_SUB), y0 = (int16_t)(cyu * MS_SUB);
    switch (e) {
        case 0:  *ox = (int16_t)(x0 + ms_interp(vtl, vtr)); *oy = y0; break;               // top
        case 1:  *ox = (int16_t)(x0 + MS_SUB); *oy = (int16_t)(y0 + ms_interp(vtr, vbr)); break; // right
        case 2:  *ox = (int16_t)(x0 + ms_interp(vbl, vbr)); *oy = (int16_t)(y0 + MS_SUB); break;  // bottom
        default: *ox = x0; *oy = (int16_t)(y0 + ms_interp(vtl, vbl)); break;               // left
    }
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t ms_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 2u                    // animated frames marched into the gate
#endif
#define MS_GW 16u                    // gate grid (cells)
#define MS_GH 16u
#define MS_GVW (MS_GW + 1u)          // value-grid width

// March a MS_GW×MS_GH cell grid at each of GATE_N frames, folding the case index + every crossing point.
// The field is sampled ONCE per grid point into vg[] (not 4× per cell) so the __mulsi3-heavy field cost
// stays inside the gate settle window.  A miscompile in the corner sign tests, the 4-bit case indexing /
// MS_SEG lookup, or the edge-crossing divide changes the contour and diverges the hash.
static uint16_t msquares_gate_crc(void) {
    static int16_t vg[MS_GVW * (MS_GH + 1u)];
    uint16_t h = 0u;
    for (uint16_t f = 0u; f < (uint16_t)GATE_N; f++) {
        int16_t cx[MS_NB], cy[MS_NB];
        ms_centers((uint16_t)(f * 29u), cx, cy);
        for (uint8_t gy = 0u; gy <= (uint8_t)MS_GH; gy++)
            for (uint8_t gx = 0u; gx <= (uint8_t)MS_GW; gx++)
                vg[(uint16_t)gy * MS_GVW + gx] =
                    (int16_t)ms_field((int16_t)((int16_t)gx * 6 + 8), (int16_t)((int16_t)gy * 6 + 8), cx, cy);
        for (uint8_t gy = 0u; gy < (uint8_t)MS_GH; gy++)
            for (uint8_t gx = 0u; gx < (uint8_t)MS_GW; gx++) {
                int32_t vtl = vg[(uint16_t)gy * MS_GVW + gx];
                int32_t vtr = vg[(uint16_t)gy * MS_GVW + gx + 1u];
                int32_t vbr = vg[(uint16_t)(gy + 1u) * MS_GVW + gx + 1u];
                int32_t vbl = vg[(uint16_t)(gy + 1u) * MS_GVW + gx];
                uint8_t cs = (uint8_t)(((vtl >= MS_ISO) << 3) | ((vtr >= MS_ISO) << 2)
                                     | ((vbr >= MS_ISO) << 1) |  (vbl >= MS_ISO));
                h = ms_fold(h, (uint16_t)(cs ^ (uint16_t)((gx << 4) ^ gy)));
                for (uint8_t s = 0u; s < 4u; s += 2u) {
                    uint8_t ea = MS_SEG[cs][s], eb = MS_SEG[cs][s + 1u];
                    if (ea == 0xFFu) continue;
                    int16_t ax, ay, bx, by;
                    ms_edge_point(ea, gx, gy, vtl, vtr, vbr, vbl, &ax, &ay);
                    ms_edge_point(eb, gx, gy, vtl, vtr, vbr, vbl, &bx, &by);
                    h = ms_fold(h, (uint16_t)(ax ^ (ay << 8)));
                    h = ms_fold(h, (uint16_t)(bx ^ (by << 8)));
                }
            }
    }
    return h;
}

#endif /* MSQUARES_H */
