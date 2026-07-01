// Shared, PURE 3x3 median filter via a branchless sorting network — host-linkable, no hardware.
// Demo #57.
//
// The codegen corner: **branchless min/max/abs as the hot op**.  A median-of-9 sorting network is 19
// compare-exchanges, each `lo=min(a,b); hi=max(a,b)` written as the select idiom `(a<b)?a:b` /
// `(a<b)?b:a` — the generic opcodes G_UMIN/G_UMAX (G_SMIN/G_SMAX signed), lowered by
// MOSLegalizerInfo.cpp:272 `.lower()` to icmp+select (no branch mesh, no libcall).  The noise-vs-clean
// difference uses abs -> G_ABS (`.custom()` @281).  #44 (hdr-bloom) stressed carry/V-flag saturating
// add; this is the select-lowered min/max path, a different shape.
//
// WIDTH DISCIPLINE: pixels are uint8; the abs difference promotes through int16.  All width-agnostic ->
// bit-exact host vs target.  See docs/plans/2026-06-30-57-snes-medfilt.md.
#ifndef MEDFILT_H
#define MEDFILT_H

#include <stdint.h>

// Compare-exchange on p[i],p[j]: p[i]=min, p[j]=max.  Branchless min/max (the corner).
static inline void medfilt_cmpx(uint8_t *p, uint8_t i, uint8_t j) {
    uint8_t a = p[i], b = p[j];
    p[i] = (uint8_t)((a < b) ? a : b);   // G_UMIN
    p[j] = (uint8_t)((a < b) ? b : a);   // G_UMAX
}

// Median of 9 bytes via the classic 19-comparator network (Smith / "fast median filtering").
// Destroys the input array; the median lands in p[4].
static uint8_t medfilt_median9(uint8_t *p) {
    medfilt_cmpx(p,1,2); medfilt_cmpx(p,4,5); medfilt_cmpx(p,7,8);
    medfilt_cmpx(p,0,1); medfilt_cmpx(p,3,4); medfilt_cmpx(p,6,7);
    medfilt_cmpx(p,1,2); medfilt_cmpx(p,4,5); medfilt_cmpx(p,7,8);
    medfilt_cmpx(p,0,3); medfilt_cmpx(p,5,8); medfilt_cmpx(p,4,7);
    medfilt_cmpx(p,3,6); medfilt_cmpx(p,1,4); medfilt_cmpx(p,2,5);
    medfilt_cmpx(p,4,7); medfilt_cmpx(p,4,2); medfilt_cmpx(p,6,4);
    medfilt_cmpx(p,4,2);
    return p[4];
}

// abs difference of two pixels (clamps display of "how much noise the median removed") -> G_ABS.
static inline uint8_t medfilt_absdiff(uint8_t a, uint8_t b) {
    int16_t d = (int16_t)((int16_t)a - (int16_t)b);
    int16_t m = (int16_t)((d < 0) ? -d : d);          // G_ABS
    return (uint8_t)m;
}

// xorshift16 PRNG for salt-and-pepper noise.
static inline uint16_t medfilt_rng(uint16_t *s) {
    uint16_t x = *s;
    x ^= (uint16_t)(x << 7); x ^= (uint16_t)(x >> 9); x ^= (uint16_t)(x << 8);
    *s = x; return x;
}

// A smooth source image value at (x,y): concentric-ish ramp so median denoising is visible.
static inline uint8_t medfilt_src(uint8_t x, uint8_t y) {
    uint8_t dx = (uint8_t)((x < 16u) ? (16u - x) : (x - 16u));
    uint8_t dy = (uint8_t)((y < 16u) ? (16u - y) : (y - 16u));
    return (uint8_t)((dx + dy) & 0x3Fu);
}

// Corrupt a source pixel with salt/pepper impulse noise ~1/4 of the time.
static inline uint8_t medfilt_noisy(uint8_t x, uint8_t y, uint16_t *s) {
    uint16_t r = medfilt_rng(s);
    if ((r & 3u) == 0u) return (uint8_t)((r & 0x100u) ? 63u : 0u);   // salt or pepper
    return medfilt_src(x, y);
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t medfilt_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 150u
#endif

// Fold median-of-9 over noisy 3x3 windows + abs-diffs.  A miscompile in the min/max network or in abs
// diverges.  Cross-check: the network median must equal the value at index 4 of a fully insertion-sorted
// copy (an INDEPENDENT sort), folded too.
static uint8_t medfilt_sorted_median9(const uint8_t *in) {   // reference: insertion sort, take middle
    uint8_t q[9];
    for (uint8_t i = 0; i < 9u; i++) q[i] = in[i];
    for (uint8_t i = 1; i < 9u; i++) {
        uint8_t v = q[i]; int8_t j = (int8_t)i - 1;
        while (j >= 0 && q[j] > v) { q[j + 1] = q[j]; j--; }
        q[j + 1] = v;
    }
    return q[4];
}

static uint16_t medfilt_gate_crc(void) {
    uint16_t h = 0u;
    uint16_t s = 0xACE1u;
    for (uint16_t i = 0u; i < (uint16_t)GATE_N; i++) {
        uint8_t win[9], ref[9];
        for (uint8_t k = 0u; k < 9u; k++) {
            uint8_t px = (uint8_t)((i + k) & 31u);
            uint8_t py = (uint8_t)((i * 2u + k) & 31u);
            uint8_t v = medfilt_noisy(px, py, &s);
            win[k] = v; ref[k] = v;
        }
        uint8_t med = medfilt_median9(win);            // network (destroys win)
        uint8_t rm  = medfilt_sorted_median9(ref);      // independent reference
        h = medfilt_fold(h, (uint16_t)med);
        h = medfilt_fold(h, (uint16_t)rm);              // must equal med
        h = medfilt_fold(h, (uint16_t)medfilt_absdiff(ref[4], med));
    }
    return h;
}

#endif /* MEDFILT_H */
