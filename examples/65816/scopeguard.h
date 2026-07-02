// Scope-Guard Ripple Tank (#90) — shared, portable logic header.
//
// Stresses: __attribute__((cleanup(fn))) — compiler-synthesized scope-exit calls (CGDecl.cpp:2254).
// A guarded local runs its cleanup fn at EVERY exit of its lexical scope: normal fall-through,
// early `return`, `break`, and nested-block close. The compiler must fan the cleanup JSR out to
// each exit edge and run guards in reverse declaration order. Distinct from every other battery
// demo — none use the cleanup attribute / synthesized scope-exit calls.
//
// WIDTH DISCIPLINE: uint16_t/int16_t everywhere. No bare int.
// DIFFERENTIAL: the cleanup fold is exact integer arithmetic; if the compiler misses an exit
// edge, runs guards in the wrong order, or double-runs one, the fold diverges immediately.
//
// See docs/plans/2026-07-01-90-snes-scopeguard.md.

#ifndef SCOPEGUARD_H
#define SCOPEGUARD_H

#include <stdint.h>

#define SG_W 24u
#define SG_H 24u
#ifndef SG_GATE_N
#define SG_GATE_N 32u
#endif

// Global fold + cleanup counter, mutated by scope-exit guards.
static uint16_t sg_fold;
static uint16_t sg_cleanups;

// Cleanup callback: folds the guarded value in reverse-declaration order at scope exit.
// noinline keeps the realistic cleanup-CALL shape (real cleanup handlers are functions, not
// inlined bodies) so the scope-exit JSR fan-out is visible — NOT to dodge any miscompile.
__attribute__((noinline))
static void sg_guard(uint16_t *g) {
    sg_fold = (uint16_t)((uint16_t)((sg_fold << 1) | (sg_fold >> 15)) ^ (uint16_t)((uint16_t)(*g) * 97u));
    sg_cleanups++;
}

// A routine with MULTIPLE guarded scopes and MULTIPLE exit paths — the cleanup fan-out.
// Returns a value; the interesting effect is the sequence of scope-exit guard calls.
static uint16_t sg_process(uint16_t a, uint16_t b) {
    uint16_t outer __attribute__((cleanup(sg_guard))) = a;   // runs last (outermost)
    if ((a & 3u) == 0u) {
        uint16_t e0 __attribute__((cleanup(sg_guard))) = (uint16_t)(a ^ 0x1234u);
        (void)e0;
        return (uint16_t)(a + 1u);                            // exit: e0 then outer
    }
    for (uint16_t i = 0u; i < 3u; i++) {
        uint16_t loopg __attribute__((cleanup(sg_guard))) = (uint16_t)(a + i);  // runs each iter
        if (((a + i) & 7u) == 5u) break;                      // early break: loopg fires
        (void)loopg;
    }
    {
        uint16_t inner __attribute__((cleanup(sg_guard))) = b;   // nested block scope
        uint16_t inner2 __attribute__((cleanup(sg_guard))) = (uint16_t)(b ^ a);
        (void)inner; (void)inner2;
    }                                                          // inner2 then inner fire here
    return (uint16_t)(a ^ b);                                 // exit: outer fires
}

// ------------------------------------------------------------------
// Gate CRC: run sg_process across GATE_N argument pairs; the answer is the
// accumulated cleanup fold + count (a witness of the scope-exit call sequence).
// ------------------------------------------------------------------
static uint16_t scopeguard_gate_crc(void) {
    sg_fold = 0u; sg_cleanups = 0u;
    uint16_t k;
    for (k = 0u; k < (uint16_t)SG_GATE_N; k++) {
        uint16_t r = sg_process((uint16_t)(k * 7u + 1u), (uint16_t)(k * 13u + 3u));
        sg_fold = (uint16_t)(sg_fold ^ (uint16_t)(r << 3));
    }
    return (uint16_t)(sg_fold ^ (uint16_t)(sg_cleanups * 31u));
}

#endif /* SCOPEGUARD_H */
