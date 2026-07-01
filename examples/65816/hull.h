// Shared, PURE convex hull (gift-wrapping) — host-linkable, no hardware.  Demo #65.
//
// The codegen corner: **signed 2-D cross-product orientation tests**.  The gift-wrap (Jarvis march)
// builds the convex hull purely from the sign of the cross product
//   cross(O,A,B) = (A.x-O.x)*(B.y-O.y) - (A.y-O.y)*(B.x-O.x)
// which is > 0 for a left turn, < 0 for a right turn, 0 for collinear.  Nothing in the first 64 demos
// runs a computational-geometry orientation predicate; #16 (wireframe) drew lines but never asked "which
// side of this segment is that point on".
//
// WIDTH DISCIPLINE: coordinates are int16.  The cross product multiplies two int16 differences (each in
// [-255,255]-ish), so it is computed in **int32** to avoid 16-bit overflow — an explicit (int32_t) cast
// on each factor makes host (int=32) and target (int=16) agree.  See docs/plans/2026-06-30-65-snes-hull.md.
#ifndef HULL_H
#define HULL_H

#include <stdint.h>

#ifndef HL_N
#define HL_N 14u                // number of scattered points
#endif

typedef struct { int16_t x, y; } HlPt;

// Signed cross product (O->A) x (O->B).  int32 to avoid int16 overflow; sign is the orientation.
static inline int32_t hl_cross(HlPt o, HlPt a, HlPt b) {
    int32_t ax = (int32_t)a.x - (int32_t)o.x, ay = (int32_t)a.y - (int32_t)o.y;
    int32_t bx = (int32_t)b.x - (int32_t)o.x, by = (int32_t)b.y - (int32_t)o.y;
    return ax * by - ay * bx;
}

// Gift-wrap (Jarvis march): fill hull[] with the indices of the convex-hull vertices (CCW), return count.
// Starts at the leftmost (then lowest) point; repeatedly picks the most clockwise candidate via cross<0.
static uint8_t hl_giftwrap(const HlPt *p, uint8_t n, uint8_t *hull) {
    uint8_t start = 0u;
    for (uint8_t i = 1u; i < n; i++)
        if (p[i].x < p[start].x || (p[i].x == p[start].x && p[i].y < p[start].y)) start = i;

    uint8_t hc = 0u;
    uint8_t cur = start;
    do {
        hull[hc++] = cur;
        uint8_t next = (uint8_t)((cur + 1u) % n);            // any point != cur to seed
        for (uint8_t i = 0u; i < n; i++) {
            if (i == cur) continue;
            int32_t c = hl_cross(p[cur], p[next], p[i]);
            // pick i if it's strictly more clockwise (to the right of cur->next), or collinear-and-farther
            if (c < 0) next = i;
            else if (c == 0) {
                int32_t dn = (int32_t)(p[next].x - p[cur].x) * (int32_t)(p[next].x - p[cur].x)
                           + (int32_t)(p[next].y - p[cur].y) * (int32_t)(p[next].y - p[cur].y);
                int32_t di = (int32_t)(p[i].x - p[cur].x) * (int32_t)(p[i].x - p[cur].x)
                           + (int32_t)(p[i].y - p[cur].y) * (int32_t)(p[i].y - p[cur].y);
                if (di > dn) next = i;
            }
        }
        cur = next;
    } while (cur != start && hc < n);
    return hc;
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t hl_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 12u           // gift-wrap + O(n^2) validity check w/ int32 cross is heavy; keep gate < ~450 frames
#endif

static uint16_t hl_rng(uint16_t *s) {
    uint16_t x = *s; x ^= (uint16_t)(x << 7); x ^= (uint16_t)(x >> 9); x ^= (uint16_t)(x << 8);
    *s = x; return x;
}

// Fold the hull (vertex count + indices) of GATE_N random point sets.  Cross-check baked in: every hull
// edge must have ALL points on its left (a valid convex hull) — fold a 1 per violation (must stay 0).
// A miscompile in the int32 cross-product orientation diverges.
static uint16_t hull_gate_crc(void) {
    uint16_t h = 0u, rng = 0x51EDu;
    for (uint16_t t = 0u; t < (uint16_t)GATE_N; t++) {
        HlPt p[HL_N]; uint8_t hull[HL_N];
        for (uint8_t i = 0u; i < HL_N; i++) {
            p[i].x = (int16_t)(hl_rng(&rng) % 100u);
            p[i].y = (int16_t)(hl_rng(&rng) % 100u);
        }
        uint8_t hc = hl_giftwrap(p, HL_N, hull);
        h = hl_fold(h, (uint16_t)hc);
        uint16_t bad = 0u;
        for (uint8_t e = 0u; e < hc; e++) {
            HlPt a = p[hull[e]], b = p[hull[(uint8_t)((e + 1u) % hc)]];
            for (uint8_t i = 0u; i < HL_N; i++)
                if (hl_cross(a, b, p[i]) < 0) bad++;         // a point to the right of a hull edge -> invalid
            h = hl_fold(h, (uint16_t)hull[e]);
        }
        h = hl_fold(h, bad);                                 // 0 for a valid hull
    }
    return h;
}

#endif /* HULL_H */
