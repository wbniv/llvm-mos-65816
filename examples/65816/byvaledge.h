// By-Value Boundary Trio (#154) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster C — the boundary and width escalations.
//
// THE ESCALATION: #145 bigbyval took the `> 32`-bit by-value ARGUMENT path for the first time,
// at 144 bits — far past the threshold. #26 boids and #60 pass 32-bit records — at it, but with
// no indirect sibling in the same ROM. This demo compiles BOTH SIDES of the classifier test
// adjacently, in one program, over records that differ by a single byte of size.
//
// The test is in clang/lib/CodeGen/Targets/MOS.cpp, MOSABIInfo::classifyArgumentType:
//
//     if (getRecordArgABI(Ty, getCXXABI()) == CGCXXABI::RAA_DirectInMemory ||
//         getContext().getTypeSize(Ty) > 32)
//       return getNaturalAlignIndirect(Ty, /*AddrSpace=*/0, /*ByVal=*/false);
//     ...
//     return ABIArgInfo::getDirect();
//
// MEASURED CORRECTION TO THE BRIEF — "32, 33 and 40 bits" is really TWO size classes, not
// three. `getTypeSize` is in BITS, and on MOS every scalar has ABI alignment 1, so a record's
// size is always a whole number of bytes x 8. **There is no 33-bit size class.** A record
// declaring 33 bits of bitfield has `sizeof == 5` and therefore `getTypeSize == 40`:
//
//     define dso_local i16 @f32(i16 %0, i16 %1)                          ; 4 bytes -> getDirect
//     define dso_local i16 @f33(ptr ... dead_on_return %0)               ; 33 declared bits -> sizeof 5 -> indirect
//     define dso_local i16 @f40(ptr ... dead_on_return %0)               ; 5 bytes -> indirect
//
// The real boundary is between sizeof 4 and sizeof 5. The demo keeps all three record shapes
// anyway: the 33-bit-declared one is what DEMONSTRATES the collapse (and is a bitfield record
// passed by value, which nothing in the tree does), and the gate asserts the ABI form of each.
// That correction is recorded here rather than quietly dropped.
//
// WHY THE INDIRECT SIDE IS THE DANGEROUS ONE: `ByVal=false` means the callee receives a pointer
// to the CALLER's object. By-value semantics therefore rest entirely on a call-site copy. A
// missing copy does not crash, does not fail the verifier, and does not corrupt the callee's own
// return value — it silently mutates the caller's original. So every stage below MUTATES ITS OWN
// PARAMETER before deriving its result, and the driver RE-READS its original after every call.
//
// DIFFERENTIAL: integer-exact. The CRC folds every stage output, every caller re-read, and a
// bad_byval counter that must be 0.
// WIDTH DISCIPLINE: explicit uint8/16/32; every multiply goes through uint32_t.
// See docs/plans/2026-09-16-round8-cluster-c-boundary-and-width-escalations.md.

#ifndef BYVALEDGE_H
#define BYVALEDGE_H

#include <stdint.h>

#define BV_STEPS  96u

/* --- 4 bytes = 32 bits: exactly AT the threshold -> ABIArgInfo::getDirect() --- */
typedef struct { uint16_t a; uint16_t b; } BvR32;

/* --- 33 DECLARED bits of bitfield. sizeof rounds to 5 -> getTypeSize == 40 -> indirect.
       This record is the measured proof that "33 bits" is not a size class of its own. --- */
typedef struct { uint32_t lo; uint8_t hi : 1; } BvR33;

/* --- 5 bytes = 40 bits: one byte over -> getNaturalAlignIndirect(ByVal=false) --- */
typedef struct { uint16_t a; uint16_t b; uint8_t c; } BvR40;

_Static_assert(sizeof(BvR32) == 4u, "BvR32 must be 4 bytes (32 bits, the getDirect side)");
/* The remaining sizes are TARGET-CONDITIONAL, and that is the point: on the x86-64 host,
   scalar alignment pads BvR33 to 8 and BvR40 to 6, so only on MOS — where every scalar has
   ABI alignment 1 — do they land at 5 and 5. The sizes are therefore reported by the gate and
   asserted per target; they are NEVER folded into the differential CRC, which must agree
   across host and target. */
#if defined(__mos__)
/* The collapse, asserted rather than described: a 33-bit-declared record is a 40-bit record. */
_Static_assert(sizeof(BvR33) == 5u,
               "MOS: a 33-bit bitfield record is sizeof 5 — there is no 33-bit size class");
_Static_assert(sizeof(BvR40) == 5u, "MOS: BvR40 must be 5 bytes (40 bits, the indirect side)");
_Static_assert(_Alignof(uint32_t) == 1u, "MOS: every scalar has ABI alignment 1");
#endif

static uint16_t bv_out32[BV_STEPS][2];   /* each stage's derived record  */
static uint32_t bv_out33[BV_STEPS];
static uint16_t bv_out40[BV_STEPS][3];
static uint16_t bv_reread[BV_STEPS][3];  /* the caller's own originals, re-read after the call */
static uint16_t bv_bad;                  /* caller-visible by-value violations — MUST be 0 */
static uint16_t bv_n;

static uint16_t bv_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}

// --------------------------------------------------------------------------
// The stages. Each MUTATES ITS OWN PARAMETER before deriving its result, which is the only
// thing that makes a missing call-site copy observable. noinline so the copy cannot be elided
// by inlining the whole thing into the caller.
// --------------------------------------------------------------------------
__attribute__((noinline))
static BvR32 bv_stage32(BvR32 v, uint16_t k) {
    v.a = (uint16_t)(v.a ^ k);                 /* mutation #1 */
    v.b = (uint16_t)(v.b + v.a);               /* mutation #2 */
    BvR32 out;
    out.a = (uint16_t)(bv_mul(v.a, (uint16_t)25173u) + v.b);
    out.b = (uint16_t)(v.b ^ (uint16_t)(v.a << 3));
    return out;
}

__attribute__((noinline))
static BvR33 bv_stage33(BvR33 v, uint16_t k) {
    v.lo = (uint32_t)(v.lo ^ (uint32_t)k);     /* mutation #1 */
    v.hi = (uint8_t)(~v.hi & 1u);              /* mutation #2, the bitfield half */
    BvR33 out;
    out.lo = (uint32_t)((v.lo << 3) + (uint32_t)(v.hi ? 0x9E37u : 0x2C1Bu));
    out.hi = (uint8_t)((v.lo >> 7) & 1u);
    return out;
}

__attribute__((noinline))
static BvR40 bv_stage40(BvR40 v, uint16_t k) {
    v.a = (uint16_t)(v.a + k);                 /* mutation #1 */
    v.b = (uint16_t)(v.b ^ v.a);               /* mutation #2 */
    v.c = (uint8_t)(v.c + (uint8_t)(v.b & 0xFFu));  /* mutation #3, the odd trailing byte */
    BvR40 out;
    /* NO LIBCALL HERE, DELIBERATELY. This stage originally derived out.a with a 16x16 multiply
       (bv_mul -> __mulhi3). That put a CALL between a byte member and a word member of the same
       pointed-to record, which is an OPEN upstream llvm-mos register-allocation defect — the
       compiler hard-errors with "ran out of registers during register allocation", at -O1 and
       above, on pristine upstream llc at -mcpu=mos6502, with no target feature in play. Found by
       this demo; see docs/investigations/
       2026-09-16-mos-regalloc-out-of-registers-mixed-width-pointer-plus-call.md.
       The multiply is not the corner under test — the ABI FORM of the parameter is, and that is
       unchanged — so the derivation is shift/add/xor and the demo ships gated rather than
       weakened. bv_stage32 (the getDirect side) keeps its multiply; it is unaffected. */
    out.a = (uint16_t)((uint16_t)(v.a << 3) + (uint16_t)(v.b ^ (uint16_t)(v.a >> 5)));
    out.b = (uint16_t)(v.b - (uint16_t)v.c);
    out.c = (uint8_t)((v.a >> 8) ^ v.c);
    return out;
}

static void bv_reset(void) {
    bv_bad = (uint16_t)0u;
    bv_n = (uint16_t)0u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)BV_STEPS; i++) {
        bv_out32[i][0] = bv_out32[i][1] = (uint16_t)0u;
        bv_out33[i] = (uint32_t)0u;
        bv_out40[i][0] = bv_out40[i][1] = bv_out40[i][2] = (uint16_t)0u;
        bv_reread[i][0] = bv_reread[i][1] = bv_reread[i][2] = (uint16_t)0u;
    }
}

// The driver. Both sides of the boundary are called from the same loop with the same seed
// stream, so getDirect and getNaturalAlignIndirect are compiled adjacently and their call-site
// sequences sit next to each other in the same function.
__attribute__((noinline))
static void bv_run(void) {
    uint16_t s = (uint16_t)0x2F6Bu;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)BV_STEPS; i++) {
        s = (uint16_t)(bv_mul(s, (uint16_t)25173u) + (uint16_t)13849u);
        uint16_t k = (uint16_t)(s ^ (uint16_t)(i * 733u));

        BvR32 a32; a32.a = s; a32.b = (uint16_t)(s ^ 0x5A5Au);
        BvR33 a33; a33.lo = (uint32_t)(((uint32_t)s << 16) | (uint32_t)(s ^ 0x1234u));
                   a33.hi = (uint8_t)(s & 1u);
        BvR40 a40; a40.a = s; a40.b = (uint16_t)(s + 0x3C3Cu); a40.c = (uint8_t)(s >> 8);

        /* Snapshot what the caller's own objects hold BEFORE the calls. */
        uint16_t w32a = a32.a, w32b = a32.b;
        uint32_t w33lo = a33.lo; uint8_t w33hi = a33.hi;
        uint16_t w40a = a40.a, w40b = a40.b; uint8_t w40c = a40.c;

        BvR32 o32 = bv_stage32(a32, k);
        BvR33 o33 = bv_stage33(a33, k);
        BvR40 o40 = bv_stage40(a40, k);

        /* RE-READ the caller's originals. Every one of these must be untouched: the callees
           mutated their parameters, and a parameter is the caller's object only if the ABI's
           required call-site copy went missing. */
        if (a32.a != w32a || a32.b != w32b)  bv_bad = (uint16_t)(bv_bad + 1u);
        if (a33.lo != w33lo || a33.hi != w33hi) bv_bad = (uint16_t)(bv_bad + 1u);
        if (a40.a != w40a || a40.b != w40b || a40.c != w40c) bv_bad = (uint16_t)(bv_bad + 1u);

        /* Chain: feed each stage's own output straight back through it, so the indirect
           argument slot is fed from a just-returned indirect result. */
        o32 = bv_stage32(o32, (uint16_t)(k ^ 0x8001u));
        o33 = bv_stage33(o33, (uint16_t)(k ^ 0x8001u));
        o40 = bv_stage40(o40, (uint16_t)(k ^ 0x8001u));

        bv_out32[i][0] = o32.a;  bv_out32[i][1] = o32.b;
        bv_out33[i]    = (uint32_t)(o33.lo ^ (uint32_t)((uint32_t)o33.hi << 31));
        bv_out40[i][0] = o40.a;  bv_out40[i][1] = o40.b;  bv_out40[i][2] = (uint16_t)o40.c;
        bv_reread[i][0] = a32.a;
        bv_reread[i][1] = (uint16_t)(a33.lo & 0xFFFFu);
        bv_reread[i][2] = (uint16_t)(a40.a ^ (uint16_t)a40.c);
        bv_n = (uint16_t)(bv_n + 1u);
    }
}

static uint16_t bv_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(bv_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}
static uint16_t bv_mix32(uint16_t h, uint32_t v) {
    h = bv_mix(h, (uint16_t)(v & 0xFFFFu));
    return bv_mix(h, (uint16_t)((v >> 16) & 0xFFFFu));
}

// --------------------------------------------------------------------------
// Differential gate.
// --------------------------------------------------------------------------
static uint16_t byvaledge_gate_crc(void) {
    uint16_t h = (uint16_t)0x4D82u;
    bv_reset();
    bv_run();
    h = bv_mix(h, bv_n);
    h = bv_mix(h, bv_bad);
    /* sizeof is deliberately NOT folded: BvR33/BvR40 are 5/5 on MOS and 8/6 on the x86-64
       host, so folding them would make the differential fail for a reason that is not a bug. */
    for (uint16_t i = (uint16_t)0u; i < bv_n; i++) {
        h = bv_mix(h, bv_out32[i][0]);
        h = bv_mix(h, bv_out32[i][1]);
        h = bv_mix32(h, bv_out33[i]);
        h = bv_mix(h, bv_out40[i][0]);
        h = bv_mix(h, bv_out40[i][1]);
        h = bv_mix(h, bv_out40[i][2]);
        h = bv_mix(h, bv_reread[i][0]);
        h = bv_mix(h, bv_reread[i][1]);
        h = bv_mix(h, bv_reread[i][2]);
    }
    return h;
}

/* The cross-check the gate asserts: zero caller-visible by-value violations. */
static uint16_t bv_violations(void) { return bv_bad; }

#endif /* BYVALEDGE_H */
