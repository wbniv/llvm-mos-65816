// Nested VLA Pyramid (#151) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster C — the boundary and width escalations.
//
// THE ESCALATION: #143 vlastack brought `G_DYN_STACKALLOC` (MOSLegalizerInfo.cpp:456
// `.custom()`) into the tree for the first time, with ONE `G_STACKSAVE`/`G_STACKRESTORE`
// bracket around ONE runtime-sized allocation. This demo takes the axis #143 does not touch:
// **depth**. Two VLAs live in NESTED scopes with independent runtime lengths, so one
// save/restore bracket encloses another and the soft stack pointer must unwind in the right
// order.
//
// MEASURED FIRST — the nesting only survives under one specific source shape:
//
//   function-scope VLA + inner-block VLA          -> 2 G_DYN_STACKALLOC, 1 save, 1 restore
//   explicit outer block + nested block, once     -> 2 G_DYN_STACKALLOC, 1 save, 1 restore
//   BOTH blocks inside a driving loop             -> 2 G_DYN_STACKALLOC, 2 saves, 2 restores
//
// The first two collapse because the outer block's restore coincides with the function's
// return and is elided as redundant. Only re-entering both scopes per loop iteration keeps the
// outer bracket alive AS a bracket. vn_reduce() below is written to the third shape
// deliberately; the other two are recorded so the next person does not write the obvious
// version and conclude the corner is unreachable.
//
// WHAT A BROKEN UNWIND LOOKS LIKE: if the inner restore overshoots, the OUTER VLA's storage is
// released early and the next inner allocation reuses it. Nothing crashes, nothing fails the
// verifier, and the inner computation's own result stays right — the outer array just quietly
// changes underneath. So this demo keeps a shadow copy of the outer VLA and RE-READS the outer
// VLA after every inner block closes, folding both the re-read and a row checksum recomputed
// from the outer array AFTER all of that row's inner blocks have come and gone.
//
// The inner length is derived from the OUTER array's contents, so the inner allocation is not
// merely runtime-sized — its size depends on data that lives in the enclosing allocation.
//
// DIFFERENTIAL: integer-exact. The CRC folds the per-row reduction, every outer re-read, the
// inner lengths actually used and the row checksums. POINTER VALUES ARE NEVER FOLDED: the
// relative placement of two VLAs is not specified by C and host and target need not agree.
// WIDTH DISCIPLINE: explicit uint8/16/32; every multiply goes through uint32_t.
// See docs/plans/2026-09-16-round8-cluster-c-boundary-and-width-escalations.md.

#ifndef VLANEST_H
#define VLANEST_H

#include <stdint.h>

#define VN_SRC    256u   /* the byte source both lengths are read out of  */
#define VN_ROWS    24u   /* rows, i.e. level-1 brackets entered           */
#define VN_MAXN    18u   /* upper bound on an outer VLA length            */
#define VN_MAXK    14u   /* upper bound on an inner VLA length            */

static uint8_t  vn_src[VN_SRC];
static uint16_t vn_shadow[VN_MAXN];    /* what the outer VLA MUST still contain */
static uint16_t vn_rowsum[VN_ROWS];    /* per-row reduction, computed after unwind */
static uint8_t  vn_olen[VN_ROWS];      /* each row's outer VLA length  */
static uint8_t  vn_kmax[VN_ROWS];      /* the largest inner length in that row */
static uint8_t  vn_kprof[VN_ROWS][VN_MAXN];  /* every inner length, per row per element */
static uint16_t vn_inner_total;        /* sum of every inner length allocated */
static uint16_t vn_inner_n;            /* number of level-2 brackets entered  */
static uint16_t vn_reread_bad;         /* outer re-reads that disagreed — MUST be 0 */
static uint16_t vn_acc;                /* the running reduction */
static uint32_t vn_olen_seen;          /* bitmap: which outer lengths occurred */
static uint32_t vn_klen_seen;          /* bitmap: which inner lengths occurred */

static uint16_t vn_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}

static void vn_reset(void) {
    uint16_t s = (uint16_t)0x7A19u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)VN_SRC; i++) {
        s = (uint16_t)(vn_mul(s, (uint16_t)25173u) + (uint16_t)13849u);
        vn_src[i] = (uint8_t)((s >> 8) & 0xFFu);
    }
    for (uint16_t r = (uint16_t)0u; r < (uint16_t)VN_ROWS; r++) {
        vn_rowsum[r] = (uint16_t)0u;
        vn_olen[r] = (uint8_t)0u;
        vn_kmax[r] = (uint8_t)0u;
        for (uint8_t i = (uint8_t)0u; i < (uint8_t)VN_MAXN; i++)
            vn_kprof[r][i] = (uint8_t)0u;
    }
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)VN_MAXN; i++)
        vn_shadow[i] = (uint16_t)0u;
    vn_inner_total = (uint16_t)0u;
    vn_inner_n = (uint16_t)0u;
    vn_reread_bad = (uint16_t)0u;
    vn_acc = (uint16_t)0x1D0Fu;
    vn_olen_seen = (uint32_t)0u;
    vn_klen_seen = (uint32_t)0u;
}

// THE SHAPE UNDER TEST. Both VLA scopes are re-entered once per loop iteration, which is what
// keeps the OUTER save/restore alive as a bracket around the inner one (see the header note).
// noinline so the whole nest cannot be cloned, specialized or peeled apart; every length is
// read out of vn_src at run time so neither allocation can fold to a fixed alloca the way
// #68 polyfill's did.
__attribute__((noinline))
static void vn_reduce(void) {
    for (uint16_t r = (uint16_t)0u; r < (uint16_t)VN_ROWS; r++) {
        /* Outer length, 3..18, from the data. */
        uint8_t n = (uint8_t)((vn_src[(uint8_t)(r * 11u)] % (uint8_t)16u) + (uint8_t)3u);
        vn_olen[r] = n;
        vn_olen_seen = (uint32_t)(vn_olen_seen | ((uint32_t)1u << (uint8_t)(n & 31u)));

        /* ---- LEVEL 1 bracket: G_STACKSAVE, G_DYN_STACKALLOC, ... G_STACKRESTORE ---- */
        {
            uint16_t a[n];
            uint16_t rs = (uint16_t)0u;
            uint8_t  kmax = (uint8_t)0u;

            for (uint8_t i = (uint8_t)0u; i < n; i++) {
                uint16_t v = (uint16_t)(((uint16_t)vn_src[(uint8_t)(r * 7u + i * 5u)] << 8)
                                        | (uint16_t)vn_src[(uint8_t)(r * 3u + i * 13u + 1u)]);
                a[i] = (uint16_t)(v ^ (uint16_t)(i * 259u));
                vn_shadow[i] = a[i];       /* the shadow the re-read is checked against */
            }

            for (uint8_t i = (uint8_t)0u; i < n; i++) {
                /* The INNER length depends on the OUTER allocation's contents. 2..13. */
                uint8_t k = (uint8_t)((a[i] % (uint8_t)12u) + (uint8_t)2u);
                if (k > kmax) kmax = k;
                vn_kprof[r][i] = k;
                vn_klen_seen = (uint32_t)(vn_klen_seen | ((uint32_t)1u << (uint8_t)(k & 31u)));
                vn_inner_total = (uint16_t)(vn_inner_total + (uint16_t)k);
                vn_inner_n = (uint16_t)(vn_inner_n + 1u);

                /* ---- LEVEL 2 bracket, nested inside level 1 ---- */
                {
                    uint8_t b[k];
                    for (uint8_t j = (uint8_t)0u; j < k; j++)
                        b[j] = (uint8_t)((uint8_t)(a[i] >> (uint8_t)(j & 7u)) ^ (uint8_t)(j * 37u));
                    for (uint8_t j = (uint8_t)0u; j < k; j++)
                        rs = (uint16_t)(rs + (uint16_t)b[j]);
                    /* fold the inner array back into the reduction, reversed, so the whole
                       inner allocation is genuinely read before it is released */
                    for (uint8_t j = k; j > (uint8_t)0u; j--)
                        rs = (uint16_t)(rs ^ (uint16_t)((uint16_t)b[(uint8_t)(j - 1u)] << (uint8_t)(j & 3u)));
                }
                /* ---- level 2 has unwound. The OUTER array must be untouched. ---- */
                if (a[i] != vn_shadow[i]) vn_reread_bad = (uint16_t)(vn_reread_bad + 1u);
                rs = (uint16_t)(rs ^ a[i]);
            }

            /* Recompute the row checksum from the OUTER array after every inner bracket of
               this row has come and gone — the second detector for an overshooting unwind. */
            for (uint8_t i = (uint8_t)0u; i < n; i++) {
                if (a[i] != vn_shadow[i]) vn_reread_bad = (uint16_t)(vn_reread_bad + 1u);
                rs = (uint16_t)(vn_mul(rs, (uint16_t)25173u) + a[i]);
            }

            vn_rowsum[r] = rs;
            vn_kmax[r] = kmax;
        }
        /* ---- level 1 has unwound; work continues in the same iteration ---- */
        vn_acc = (uint16_t)(vn_acc + (uint16_t)(vn_rowsum[r] + (uint16_t)n));
    }
}

static uint16_t vn_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(vn_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}

static uint16_t vn_mix32(uint16_t h, uint32_t v) {
    h = vn_mix(h, (uint16_t)(v & 0xFFFFu));
    return vn_mix(h, (uint16_t)((v >> 16) & 0xFFFFu));
}

// --------------------------------------------------------------------------
// Differential gate: run the nest, fold everything observable EXCEPT addresses.
// --------------------------------------------------------------------------
static uint16_t vlanest_gate_crc(void) {
    uint16_t h = (uint16_t)0x6B3Du;
    vn_reset();
    vn_reduce();
    h = vn_mix(h, vn_acc);
    h = vn_mix(h, vn_inner_total);
    h = vn_mix(h, vn_inner_n);
    h = vn_mix(h, vn_reread_bad);
    h = vn_mix32(h, vn_olen_seen);
    h = vn_mix32(h, vn_klen_seen);
    for (uint16_t r = (uint16_t)0u; r < (uint16_t)VN_ROWS; r++) {
        h = vn_mix(h, vn_rowsum[r]);
        h = vn_mix(h, (uint16_t)vn_olen[r]);
        h = vn_mix(h, (uint16_t)vn_kmax[r]);
        for (uint8_t i = (uint8_t)0u; i < (uint8_t)VN_MAXN; i++)
            h = vn_mix(h, (uint16_t)vn_kprof[r][i]);
    }
    return h;
}

/* Cross-checks the gate asserts, so a degenerate run cannot pass as coverage: the nest must
   have used several DIFFERENT lengths at both levels (a constant length would be a fixed
   alloca in disguise), and every outer re-read must have matched. */
static uint8_t vn_popcount32(uint32_t v) {
    uint8_t n = (uint8_t)0u;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)32u; i++)
        if (v & ((uint32_t)1u << i)) n = (uint8_t)(n + 1u);
    return n;
}
static uint8_t vn_distinct_outer(void) { return vn_popcount32(vn_olen_seen); }
static uint8_t vn_distinct_inner(void) { return vn_popcount32(vn_klen_seen); }

#endif /* VLANEST_H */
