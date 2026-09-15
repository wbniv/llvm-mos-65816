// Retry-On-Fault Jump (#118) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster G — the RE-ENTRY guard for the 65816-native
// platforms/snes/setjmp.S fix (bug #35). corpus/setjmp_sim.c takes the jump ONCE; #116 backtrack
// varies the unwind DEPTH; #117 csrjmp pins the callee-saved RESTORE OFFSETS. This one pins
// re-entrancy: ONE setjmp site, re-armed and re-entered RJ_ATTEMPTS times, each attempt jumping
// back from a different call depth with a different soft-stack high-water mark.
//
// MECHANISM: rj_work() is noinline and recursive and carries RJ_LOCALS 16-bit locals live ACROSS
// its recursive call, so every level pushes a real soft-stack frame. An attempt either runs to
// its target depth and returns normally, or hits its simulated fault depth and longjmps straight
// back to the single setjmp. The three things longjmp must get right — the page-1 hardware S
// reconstruct, the soft stack pointer restore and the return-address rewrite — all interact on
// EVERY retry, and a defect that leaks state across re-entries (a soft SP that creeps, an S that
// only reconstructs correctly the first time) shows up as a drifting outcome sequence rather
// than a single wrong value.
//
// DIFFERENTIAL: the gate CRC folds the whole retry-outcome sequence — per attempt the fault code,
// the deepest frame reached and the work result — plus the total call count.
// WIDTH DISCIPLINE: explicit uint8/16; no bare int except setjmp's own return value.
// CLOBBER DISCIPLINE: every value that changes between a setjmp and its longjmp is file-scope,
// never a local (C99 7.13.2.1p3 leaves non-volatile locals indeterminate).
// See docs/plans/2026-09-15-116-118-setjmp-cluster-g-demos.md.

#ifndef RETRYJMP_H
#define RETRYJMP_H

#include <stdint.h>
#include "sjcompat.h"

#define RJ_ATTEMPTS  24u   /* re-entries of the single setjmp site        */
#define RJ_MINDEPTH   3u   /* shallowest target depth                     */
#define RJ_MAXDEPTH  10u   /* deepest target depth                        */
#define RJ_LOCALS     6u   /* 16-bit locals live across each recursive call */

static jmp_buf rj_jb;

static uint8_t  rj_attempt;                 /* current attempt (file-scope: changes across jumps) */
static uint8_t  rj_target;                  /* depth this attempt would reach if it never faults  */
static uint8_t  rj_faultat;                 /* depth at which it faults; RJ_NOFAULT for none      */
static uint8_t  rj_deepest;                 /* deepest frame actually entered this attempt        */
static uint16_t rj_acc;                     /* partial work carried out of a faulting frame       */
static uint16_t rj_calls;                   /* total rj_work() invocations across all attempts    */

static uint8_t  rj_code[RJ_ATTEMPTS];       /* 0 = completed, else the longjmp value              */
static uint8_t  rj_depth[RJ_ATTEMPTS];      /* deepest frame reached                              */
static uint16_t rj_result[RJ_ATTEMPTS];     /* work result (full) or partial (faulted)            */
static uint8_t  rj_wins;                    /* attempts that completed without faulting           */

#define RJ_NOFAULT 0xFFu

/* Target depth for an attempt: sweeps the whole RJ_MINDEPTH..RJ_MAXDEPTH range. */
static uint8_t rj_target_for(uint8_t a) {
    return (uint8_t)(RJ_MINDEPTH + (uint8_t)(a % (uint8_t)(RJ_MAXDEPTH - RJ_MINDEPTH + 1u)));
}

/* Fault depth for an attempt: every third attempt runs clean; the rest fault somewhere strictly
   inside the frame stack (1..target-1), so the unwind length varies attempt to attempt. */
static uint8_t rj_fault_for(uint8_t a, uint8_t target) {
    if ((uint8_t)(a % (uint8_t)3u) == (uint8_t)2u) return (uint8_t)RJ_NOFAULT;
    return (uint8_t)((uint8_t)1u + (uint8_t)((uint8_t)(a * (uint8_t)5u) % (uint8_t)(target - 1u)));
}

// The retried work. noinline + recursive with RJ_LOCALS 16-bit values live across the recursive
// call: every level is a real jsr frame with a real soft-stack frame under it. Either it reaches
// rj_target and unwinds normally, or it faults at rj_faultat and longjmps out of however many
// frames happen to be stacked at that moment.
#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpragmas"
#pragma GCC diagnostic ignored "-Winfinite-recursion"
#endif
__attribute__((noinline))
static uint16_t rj_work(uint8_t depth) {
    uint16_t l0 = (uint16_t)((uint16_t)(depth * (uint16_t)1237u) + (uint16_t)rj_attempt);
    uint16_t l1 = (uint16_t)((uint16_t)(l0 * (uint16_t)25173u) + (uint16_t)13849u);
    uint16_t l2 = (uint16_t)(l1 ^ (uint16_t)((uint16_t)depth << 8));
    uint16_t l3 = (uint16_t)((uint16_t)(l2 * (uint16_t)40503u) + (uint16_t)7u);
    uint16_t l4 = (uint16_t)(l3 + (uint16_t)(l0 ^ l1));
    uint16_t l5 = (uint16_t)((uint16_t)(l4 << 3) | (uint16_t)(l4 >> 13));

    rj_calls++;
    if (depth > rj_deepest) rj_deepest = depth;

    if (depth == rj_faultat) {
        /* Simulated fault: carry the partial work out through file scope and jump. */
        rj_acc = (uint16_t)(l0 ^ l1 ^ l2 ^ l3 ^ l4 ^ l5);
        longjmp(rj_jb, (int)((uint8_t)(depth + (uint8_t)1u)));
    }

    uint16_t child = (uint16_t)0u;
    if ((uint8_t)(depth + (uint8_t)1u) < rj_target) child = rj_work((uint8_t)(depth + (uint8_t)1u));

    /* All six locals are consumed AFTER the recursive call — they must survive it. */
    uint16_t r = (uint16_t)(child + l0);
    r = (uint16_t)(r ^ l1);
    r = (uint16_t)(r + l2);
    r = (uint16_t)(r ^ l3);
    r = (uint16_t)(r + l4);
    r = (uint16_t)(r ^ l5);
    return r;
}
#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif

static uint16_t rj_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)((uint16_t)(h * (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: RJ_ATTEMPTS re-entries of one setjmp site, folding the outcome sequence.
// --------------------------------------------------------------------------
static uint16_t retryjmp_gate_crc(void) {
    rj_calls = (uint16_t)0u;
    rj_wins = (uint8_t)0u;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)RJ_ATTEMPTS; i++) {
        rj_code[i] = (uint8_t)0u; rj_depth[i] = (uint8_t)0u; rj_result[i] = (uint16_t)0u;
    }

    for (rj_attempt = (uint8_t)0u; rj_attempt < (uint8_t)RJ_ATTEMPTS; rj_attempt++) {
        rj_target = rj_target_for(rj_attempt);
        rj_faultat = rj_fault_for(rj_attempt, rj_target);
        rj_deepest = (uint8_t)0u;
        rj_acc = (uint16_t)0u;

        /* THE single setjmp site — re-armed and re-entered on every attempt. */
        int rv = setjmp(rj_jb);
        if (rv == 0) {
            rj_result[rj_attempt] = rj_work((uint8_t)0u);
            rj_code[rj_attempt] = (uint8_t)0u;
            rj_wins++;
        } else {
            rj_result[rj_attempt] = rj_acc;
            rj_code[rj_attempt] = (uint8_t)rv;
        }
        rj_depth[rj_attempt] = rj_deepest;
    }

    uint16_t h = (uint16_t)0x3C3Cu;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)RJ_ATTEMPTS; i++) {
        h = rj_mix(h, (uint16_t)rj_code[i]);
        h = rj_mix(h, (uint16_t)rj_depth[i]);
        h = rj_mix(h, rj_result[i]);
    }
    h = rj_mix(h, rj_calls);
    h = rj_mix(h, (uint16_t)rj_wins);
    return h;
}

#endif /* RETRYJMP_H */
