// Affine Stage Pipeline (#145) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster A. The corner: a record **passed BY VALUE as
// an ARGUMENT** when it is larger than 32 bits. `MOSABIInfo::classifyArgumentType`
// (clang/lib/CodeGen/Targets/MOS.cpp:64) routes any aggregate with
// `getContext().getTypeSize(Ty) > 32` to `getNaturalAlignIndirect(..., ByVal=false)` at :71.
//
// A coverage audit of demos #1-#141 found NO demo that passes a >32-bit record by value. #91
// matcascade validated the RETURN half of the same helper (`classifyReturnType`, MOS.cpp:89 —
// the hidden sret pointer); #26 boids and #60 pass 32-bit records, which sit exactly AT the
// threshold and take `getDirect`. The argument half has never been compiled.
//
// `ByVal=false` is what makes this sharp. The callee is handed a POINTER to storage the caller
// owns, not a callee-private copy — so C's by-value semantics only hold because the front end
// materializes a temporary and copies into it at the call site. A missing or short copy is a
// **silent-wrong** defect of the worst kind: the callee's own return value is still correct,
// the verifier is still happy, nothing crashes, and the corruption appears in the CALLER's
// object afterwards.
//
// MECHANISM: an affine transform pipeline. A `BvMat` (nine int16_t = 144 bits) and a `BvVert`
// batch travel by value through a chain of stages. Every stage MUTATES ITS OWN PARAMETER
// before deriving its result — which the C standard says is a private copy — and the driver
// then re-reads its own original matrix after every call. That re-read is the observable a
// missing copy corrupts, and it is folded into the gate CRC.
//
// DIFFERENTIAL: integer-exact. The CRC folds every stage's output record, every transformed
// vertex, AND the caller's post-call re-read of its own un-mutated original.
// WIDTH DISCIPLINE: explicit int16/int32/uint16; every product goes through int32_t.
// See docs/plans/2026-09-16-round8-unentered-backend-paths.md.

#ifndef BIGBYVAL_H
#define BIGBYVAL_H

#include <stdint.h>

#define BV_STAGES   6u
#define BV_VERTS   16u
#define BV_Q        8    /* fixed-point fractional bits */

/* 9 x int16_t = 144 bits — well over the 32-bit classifier threshold. */
typedef struct { int16_t m[9]; } BvMat;

/* 4 x int16_t = 64 bits — also over the threshold, and a DIFFERENT size, so two distinct
   indirect-argument layouts are compiled rather than one repeated. */
typedef struct { int16_t x, y, z; uint16_t tag; } BvVert;

static BvMat   bv_out[BV_STAGES];              /* each stage's returned matrix        */
static BvMat   bv_reread[BV_STAGES];           /* the caller's own matrix, re-read    */
static BvVert  bv_vin[BV_VERTS];
static BvVert  bv_vout[BV_STAGES][BV_VERTS];
static uint16_t bv_mutations;                  /* writes the callees made to their own params */

static int16_t bv_qmul(int16_t a, int16_t b) {
    return (int16_t)(((int32_t)a * (int32_t)b) >> BV_Q);
}

static uint16_t bv_mul16(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}

// STAGE — takes the 144-bit matrix BY VALUE and MUTATES IT. `t` is the parameter the ABI
// passes indirectly with ByVal=false, so this write lands in whatever storage the caller
// pointed at. Under correct C semantics that is a call-site temporary and the caller's own
// matrix is untouched; if the copy is missing, it is the caller's matrix.
// noinline: inlining would let the optimizer prove the mutation is dead and delete the very
// thing under test.
__attribute__((noinline))
static BvMat bv_stage(BvMat t, uint16_t k) {
    /* Mutate the by-value parameter in place — a scale-and-skew over the caller's "copy". */
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)9u; i++) {
        t.m[i] = (int16_t)(t.m[i] + (int16_t)((int16_t)((k + i) & 0x7Fu) - (int16_t)64));
        bv_mutations = (uint16_t)(bv_mutations + 1u);
    }
    t.m[0] = (int16_t)(t.m[0] ^ (int16_t)(k << 1));
    t.m[8] = (int16_t)(t.m[8] - (int16_t)k);

    /* Derive the result from the MUTATED copy — a 3x3 multiply by a rotation-ish matrix. */
    BvMat r;
    const int16_t rot[9] = {
        (int16_t)248, (int16_t)-58, (int16_t)0,
        (int16_t)58,  (int16_t)248, (int16_t)0,
        (int16_t)0,   (int16_t)0,   (int16_t)256,
    };
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)3u; i++)
        for (uint8_t j = (uint8_t)0u; j < (uint8_t)3u; j++) {
            int32_t acc = (int32_t)0;
            for (uint8_t q = (uint8_t)0u; q < (uint8_t)3u; q++)
                acc += (int32_t)t.m[(uint8_t)(i * 3u + q)] * (int32_t)rot[(uint8_t)(q * 3u + j)];
            r.m[(uint8_t)(i * 3u + j)] = (int16_t)(acc >> BV_Q);
        }
    return r;
}

// A second indirect-argument shape: a 64-bit record passed by value, also mutated in place.
// Returns a scalar, so this call exercises the indirect ARGUMENT path with an ordinary
// register return — separating it from the sret return path #91 matcascade already covers.
__attribute__((noinline))
static uint16_t bv_apply(BvVert v, BvMat t, BvVert *out) {
    v.tag = (uint16_t)(v.tag ^ (uint16_t)0xBEEFu);        /* mutate the by-value vertex */
    v.x   = (int16_t)(v.x + (int16_t)1);
    BvVert o;
    o.x = (int16_t)(bv_qmul(t.m[0], v.x) + bv_qmul(t.m[1], v.y) + bv_qmul(t.m[2], v.z));
    o.y = (int16_t)(bv_qmul(t.m[3], v.x) + bv_qmul(t.m[4], v.y) + bv_qmul(t.m[5], v.z));
    o.z = (int16_t)(bv_qmul(t.m[6], v.x) + bv_qmul(t.m[7], v.y) + bv_qmul(t.m[8], v.z));
    o.tag = v.tag;
    *out = o;
    return (uint16_t)((uint16_t)o.tag ^ (uint16_t)o.x);
}

static uint16_t bv_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(bv_mul16(h, (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: push a matrix and a vertex batch through the stage chain, and after EVERY
// call re-read the driver's own originals. The re-read is the observable that a missing
// ByVal copy corrupts.
// --------------------------------------------------------------------------
static uint16_t bigbyval_gate_crc(void) {
    uint16_t h = (uint16_t)0x6BD1u;
    bv_mutations = (uint16_t)0u;

    /* The driver's own matrix. It is passed by value repeatedly and must NEVER change. */
    BvMat base;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)9u; i++)
        base.m[i] = (int16_t)((int16_t)((int16_t)i * (int16_t)37) - (int16_t)128);

    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BV_VERTS; i++) {
        bv_vin[i].x   = (int16_t)((int16_t)((int16_t)(i & 3u) * (int16_t)96) - (int16_t)144);
        bv_vin[i].y   = (int16_t)((int16_t)((int16_t)((i >> 2) & 3u) * (int16_t)96) - (int16_t)144);
        bv_vin[i].z   = (int16_t)((int16_t)((int16_t)i * (int16_t)17) - (int16_t)136);
        bv_vin[i].tag = (uint16_t)((uint16_t)i * (uint16_t)2053u + (uint16_t)7u);
    }

    for (uint8_t s = (uint8_t)0u; s < (uint8_t)BV_STAGES; s++) {
        uint16_t k = (uint16_t)((uint16_t)s * (uint16_t)211u + (uint16_t)13u);

        bv_out[s] = bv_stage(base, k);          /* base goes BY VALUE and is mutated inside */
        bv_reread[s] = base;                    /* <-- the observable: must equal the original */

        for (uint8_t i = (uint8_t)0u; i < (uint8_t)BV_VERTS; i++) {
            BvVert o;
            uint16_t tagged = bv_apply(bv_vin[i], bv_out[s], &o);
            bv_vout[s][i] = o;
            h = bv_mix(h, tagged);
        }
    }

    /* Fold every stage output, every transformed vertex, and every re-read of the original. */
    for (uint8_t s = (uint8_t)0u; s < (uint8_t)BV_STAGES; s++) {
        for (uint8_t i = (uint8_t)0u; i < (uint8_t)9u; i++) {
            h = bv_mix(h, (uint16_t)bv_out[s].m[i]);
            h = bv_mix(h, (uint16_t)bv_reread[s].m[i]);
        }
        for (uint8_t i = (uint8_t)0u; i < (uint8_t)BV_VERTS; i++) {
            h = bv_mix(h, (uint16_t)bv_vout[s][i].x);
            h = bv_mix(h, (uint16_t)bv_vout[s][i].y);
            h = bv_mix(h, (uint16_t)bv_vout[s][i].z);
            h = bv_mix(h, bv_vout[s][i].tag);
        }
    }
    /* And the input vertices, which the callees also mutated by value. */
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BV_VERTS; i++) {
        h = bv_mix(h, (uint16_t)bv_vin[i].x);
        h = bv_mix(h, bv_vin[i].tag);
    }
    h = bv_mix(h, bv_mutations);
    return h;
}

/* Direct self-check for the visual/driver: 0 means every re-read matched the original, i.e.
   the by-value copies held. Non-zero is the count of corrupted matrix cells. */
static uint16_t bv_copy_violations(void) {
    uint16_t bad = (uint16_t)0u;
    for (uint8_t s = (uint8_t)1u; s < (uint8_t)BV_STAGES; s++)
        for (uint8_t i = (uint8_t)0u; i < (uint8_t)9u; i++)
            if (bv_reread[s].m[i] != bv_reread[0].m[i]) bad = (uint16_t)(bad + 1u);
    return bad;
}

#endif /* BIGBYVAL_H */
