// Run-Length Scanline Decoder (#143) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster A. The corner: **`G_DYN_STACKALLOC`**
// (MOSLegalizerInfo.cpp:456, `.custom()`) — a variable-length array whose length the compiler
// genuinely cannot fold, so the soft stack pointer (`__rc0`/`__rc1`) is adjusted at runtime by
// a computed delta and restored afterwards.
//
// A coverage audit of demos #1-#141 found **zero** programs that form `G_DYN_STACKALLOC`.
// #68 polyfill has a VLA (`int16_t xs[nv]`) but `nv` const-folds at its one call site, so it
// forms only the `G_STACKSAVE`/`G_STACKRESTORE` pair over a FIXED-size alloca. The save and
// restore are therefore covered; the dynamic ALLOCATION — the one part that actually touches
// the soft SP with a value not known until run time — is not.
//
// MECHANISM: a real RLE scanline decoder. Each row of the compressed image carries its own run
// count, read out of the stream, and the decoder allocates a per-row scratch array of exactly
// that many entries to hold the run-boundary prefix sums it needs for the expansion. The VLA
// lives in the LOOP BODY, so every row allocates and releases a differently-sized block and
// the save/alloc/restore triple runs VS_ROWS times per gate run, each time with a different
// delta. The run counts come out of a stream built by a noinline generator, so no amount of
// inlining lets the optimizer see a constant.
//
// DIFFERENTIAL: integer-exact. The gate CRC folds the decoded image, every row's run count,
// and the prefix sums computed THROUGH the dynamically allocated array — so a mis-sized or
// mis-restored allocation shows up as corrupt pixels, not just a different stack pointer.
// Deliberately NOT folded: any address or stack-pointer value, which differ legitimately
// between host and target.
// WIDTH DISCIPLINE: explicit uint8/16/32; every multiply goes through uint32_t.
// See docs/plans/2026-09-16-round8-unentered-backend-paths.md.

#ifndef VLASTACK_H
#define VLASTACK_H

#include <stdint.h>

/* Sized to the SNES near-RAM budget: vs_rle + vs_img together are ~2.4 KB, which is what the
   `ram` region leaves once the snesgfx canvas and queue are in. */
#define VS_W      64u    /* decoded row width, pixels          */
#define VS_ROWS   24u    /* rows in the image                  */
#define VS_MAXRUN 16u    /* upper bound on runs per row        */
#define VS_STREAM (VS_ROWS * (1u + 2u * VS_MAXRUN))

static uint8_t  vs_rle[VS_STREAM];         /* compressed stream: [nruns][len,val]*     */
static uint16_t vs_rowoff[VS_ROWS];        /* byte offset of each row in the stream    */
static uint8_t  vs_img[VS_ROWS][VS_W];     /* decoded image                            */
static uint8_t  vs_nruns[VS_ROWS];         /* per-row run count = the VLA length       */
static uint16_t vs_pfxsum[VS_ROWS];        /* fold of each row's prefix sums           */
static uint16_t vs_totalruns;

static uint16_t vs_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}

// Build the compressed stream. noinline and writing through a global: the run counts it
// produces are opaque to the decoder below, which is what keeps the VLA lengths dynamic.
__attribute__((noinline))
static void vs_build(void) {
    uint16_t s = (uint16_t)0x2F1Bu;
    uint16_t w = (uint16_t)0u;
    vs_totalruns = (uint16_t)0u;
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)VS_ROWS; y++) {
        vs_rowoff[y] = w;
        uint16_t hdr = w;
        w++;                                    /* reserve the run-count byte */
        uint8_t n = (uint8_t)0u;
        uint16_t x = (uint16_t)0u;
        while (x < (uint16_t)VS_W && n < (uint8_t)VS_MAXRUN) {
            s = (uint16_t)(vs_mul(s, (uint16_t)25173u) + (uint16_t)13849u);
            uint16_t len = (uint16_t)((uint16_t)((s >> 9) & 7u) + 2u);
            if (n == (uint8_t)(VS_MAXRUN - 1u) || (uint16_t)(x + len) > (uint16_t)VS_W)
                len = (uint16_t)(VS_W - x);
            uint8_t val = (uint8_t)((uint8_t)((s >> 5) & 3u) |
                                    (uint8_t)((uint8_t)((y + n) & 3u) << 2));
            vs_rle[w++] = (uint8_t)len;
            vs_rle[w++] = val;
            x = (uint16_t)(x + len);
            n++;
        }
        vs_rle[hdr] = n;
        vs_totalruns = (uint16_t)(vs_totalruns + n);
    }
}

// THE PATH UNDER TEST. `pfx[nruns]` is a VLA in the LOOP BODY whose length comes out of the
// stream, so each iteration performs a fresh runtime soft-SP adjust (G_DYN_STACKALLOC) inside
// a G_STACKSAVE/G_STACKRESTORE bracket, with a different delta every row. noinline so nothing
// upstream can specialize a constant length into it.
__attribute__((noinline))
static void vs_decode(void) {
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)VS_ROWS; y++) {
        uint16_t p = vs_rowoff[y];
        uint8_t  nruns = vs_rle[p];
        vs_nruns[y] = nruns;

        uint16_t pfx[nruns];                    /* <-- runtime-sized: the corner under test */

        /* Pass 1: run-boundary prefix sums, computed and stored through the VLA. */
        uint16_t acc = (uint16_t)0u;
        for (uint8_t i = (uint8_t)0u; i < nruns; i++) {
            acc = (uint16_t)(acc + (uint16_t)vs_rle[(uint16_t)(p + 1u + (uint16_t)(i * 2u))]);
            pfx[i] = acc;
        }

        /* Pass 2: expand, reading the boundaries BACK out of the VLA — so a mis-allocated or
           mis-restored block corrupts pixels rather than merely moving a pointer. */
        uint16_t x = (uint16_t)0u;
        for (uint8_t i = (uint8_t)0u; i < nruns; i++) {
            uint16_t end = pfx[i];
            uint8_t  val = vs_rle[(uint16_t)(p + 2u + (uint16_t)(i * 2u))];
            while (x < end && x < (uint16_t)VS_W) { vs_img[y][x] = val; x++; }
        }
        while (x < (uint16_t)VS_W) { vs_img[y][x] = (uint8_t)0u; x++; }

        /* Fold this row's prefix vector, read back out of the VLA one more time. */
        uint16_t f = (uint16_t)0x9E37u;
        for (uint8_t i = (uint8_t)0u; i < nruns; i++)
            f = (uint16_t)(vs_mul((uint16_t)(f ^ pfx[i]), (uint16_t)25173u) + (uint16_t)13849u);
        vs_pfxsum[y] = f;
    }
}

static uint16_t vs_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(vs_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: build the stream, decode it through the dynamic VLA, fold the image, the
// run counts and the prefix vectors.
// --------------------------------------------------------------------------
static uint16_t vlastack_gate_crc(void) {
    uint16_t h = (uint16_t)0x4D2Bu;
    vs_build();
    vs_decode();
    h = vs_mix(h, vs_totalruns);
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)VS_ROWS; y++) {
        h = vs_mix(h, (uint16_t)vs_nruns[y]);
        h = vs_mix(h, vs_pfxsum[y]);
        for (uint8_t x = (uint8_t)0u; x < (uint8_t)VS_W; x++)
            h = vs_mix(h, (uint16_t)vs_img[y][x]);
    }
    return h;
}

/* Widest single allocation the run — the visual's gauge, and a cross-check that the lengths
   really do vary (a constant width would mean the optimizer folded the VLA away). */
static uint8_t vs_max_runs(void) {
    uint8_t m = (uint8_t)0u;
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)VS_ROWS; y++)
        if (vs_nruns[y] > m) m = vs_nruns[y];
    return m;
}
static uint8_t vs_min_runs(void) {
    uint8_t m = (uint8_t)255u;
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)VS_ROWS; y++)
        if (vs_nruns[y] < m) m = vs_nruns[y];
    return m;
}

#endif /* VLASTACK_H */
