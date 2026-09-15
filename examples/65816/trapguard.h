// Unreachable Sentinel (#150) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster B. The corner: **`G_TRAP` `.custom()`**
// (MOSLegalizerInfo.cpp:448; `legalizeTrap` turns it into an `RTLIB::ABORT` libcall, so it
// reaches the ROM as `jsr abort`). `__builtin_trap` and `__builtin_unreachable` are used
// **zero** times across demos #1-#141.
//
// HONEST FRAMING, carried over from the ideas doc and not softened: this is the WEAKEST probe
// in Round 8, weaker than #142-#145. A trap terminates, so it can never be TAKEN in a gate
// run — there is no behavioural differential to be had from it. What is testable is
// **presence and inertness**: that the trap is actually formed and reaches the ROM, and that
// its presence does not perturb the surrounding dispatch's codegen or flag liveness, i.e. the
// reachable state trace is bit-identical in all three modes and matches the host. Calling
// that a behavioural test of `G_TRAP` would be dishonest; it is a presence-and-inertness
// probe, and the plan and the driver both say so.
//
// MEASURED, and worth recording: `__builtin_unreachable()` on its own emits **nothing** — it
// is a fact handed to the optimizer, not an instruction — so it cannot form `G_TRAP` at all.
// Only `__builtin_trap()` does. A demo written around `__builtin_unreachable` would have
// compiled cleanly and covered nothing.
//
// MECHANISM: a dense (state, event) transition machine. TG_NS states x TG_NE events = 24
// pairs, of which 20 are legal and enumerated as `case` labels; the other 4 (keys 6, 11, 13,
// 16) are declared impossible and the `default:` arm is `__builtin_trap()`. The generator
// consults a
// per-state legality mask, so an impossible pair genuinely never occurs — but the transition
// function is `noinline` and takes state and event as PARAMETERS, so the compiler has no way
// to prove the default is dead and the trap survives to the ROM.
//
// DIFFERENTIAL: integer-exact. The CRC folds the reachable state trace, the per-state visit
// counts and the per-pair transition counts. Nothing about the trap itself is folded — it is
// never executed, so there is nothing to fold; the structure gate is what asserts it is there.
// WIDTH DISCIPLINE: explicit uint8/16/32; every multiply goes through uint32_t.
// See docs/plans/2026-09-16-round8-cluster-b-conversion-comparison-layout.md.

#ifndef TRAPGUARD_H
#define TRAPGUARD_H

#include <stdint.h>

#define TG_NS      6u    /* states                     */
#define TG_NE      4u    /* events                     */
#define TG_TICKS 480u    /* transitions per gate run   */
#define TG_TRACE 256u    /* recorded trace length      */

/* Which events are legal in each state. Six of the 24 (state, event) pairs are absent — those
   are the arms the `default:` trap guards. Bit e set => event e is legal in that state. */
static const uint8_t tg_legal[TG_NS] = {
    (uint8_t)0x0Fu,   /* state 0: all four        */
    (uint8_t)0x0Bu,   /* state 1: 0,1,3           */
    (uint8_t)0x07u,   /* state 2: 0,1,2           */
    (uint8_t)0x0Du,   /* state 3: 0,2,3           */
    (uint8_t)0x0Eu,   /* state 4: 1,2,3           */
    (uint8_t)0x0Fu,   /* state 5: all four        */
};
/* 4 + 3 + 3 + 3 + 3 + 4 = 20 legal pairs enumerated below; 24 - 20 = 4 impossible. */

/* --- MEASURED, and a genuine platform finding ---------------------------------------
   `__builtin_trap()` legalizes to an `abort` libcall, `abort` calls `raise`, and the default
   SIGABRT handler reaches stdio — so the first `__builtin_trap()` in ANY SNES program fails
   to link:

       ld.lld: error: undefined symbol: __putchar
       >>> referenced by ld-temp.o
       >>>               build/trapguard_sim.sfc.lto.o:(raise)

   `__putchar` is the SDK's per-platform character hook (declared in common/include/stdio.h,
   never defined for `snes`, which has no console). So a program that merely CONTAINS an
   untaken trap must supply it. That is not a workaround for this demo — it is the cost of
   `G_TRAP` on this platform, and it is why nothing across demos #1-#141 could have linked one
   by accident. The stub below is deliberately side-effect-free but not removable: it stores
   through a volatile sink, so it survives -Os without doing any I/O. It is never called (the
   trap is never taken); it exists so the trap can be PRESENT, which is the whole probe. */
#if defined(__mos__)
volatile uint8_t tg_putchar_sink;
void __putchar(char c) { tg_putchar_sink = (uint8_t)c; }
#endif

static uint8_t  tg_trace[TG_TRACE];
static uint16_t tg_ntrace;
static uint16_t tg_visit[TG_NS];
static uint16_t tg_pair[TG_NS][TG_NE];
static uint16_t tg_acc;              /* a per-transition datum, so the arms differ */
static uint16_t tg_guarded;          /* impossible pairs the generator skipped     */

static uint16_t tg_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}

// The dense dispatch. Every legal (state, event) pair is its own `case` on the packed index
// state*TG_NE + event; the four impossible pairs fall to `default:`, which traps.
//
// `noinline` and parameterised is what keeps the trap alive: inside this function the
// compiler knows nothing about which pairs the caller can produce, so it cannot delete the
// default arm. That is the whole construction — a trap the optimizer would happily remove is
// a trap that never reaches the ROM and never tests anything.
__attribute__((noinline))
static uint8_t tg_step(uint8_t st, uint8_t ev, uint16_t *acc) {
    uint8_t key = (uint8_t)((uint8_t)(st * (uint8_t)TG_NE) + ev);
    uint8_t next;
    uint16_t bump;

    switch (key) {
        /* state 0 */
        case  0: next = (uint8_t)1u; bump = (uint16_t)7u;   break;
        case  1: next = (uint8_t)2u; bump = (uint16_t)11u;  break;
        case  2: next = (uint8_t)3u; bump = (uint16_t)13u;  break;
        case  3: next = (uint8_t)5u; bump = (uint16_t)17u;  break;
        /* state 1 — event 2 is impossible */
        case  4: next = (uint8_t)2u; bump = (uint16_t)19u;  break;
        case  5: next = (uint8_t)4u; bump = (uint16_t)23u;  break;
        case  7: next = (uint8_t)0u; bump = (uint16_t)29u;  break;
        /* state 2 — event 3 is impossible */
        case  8: next = (uint8_t)3u; bump = (uint16_t)31u;  break;
        case  9: next = (uint8_t)5u; bump = (uint16_t)37u;  break;
        case 10: next = (uint8_t)1u; bump = (uint16_t)41u;  break;
        /* state 3 — event 1 is impossible */
        case 12: next = (uint8_t)4u; bump = (uint16_t)43u;  break;
        case 14: next = (uint8_t)0u; bump = (uint16_t)47u;  break;
        case 15: next = (uint8_t)2u; bump = (uint16_t)53u;  break;
        /* state 4 — event 0 is impossible */
        case 17: next = (uint8_t)5u; bump = (uint16_t)59u;  break;
        case 18: next = (uint8_t)3u; bump = (uint16_t)61u;  break;
        case 19: next = (uint8_t)1u; bump = (uint16_t)67u;  break;
        /* state 5 */
        case 20: next = (uint8_t)0u; bump = (uint16_t)71u;  break;
        case 21: next = (uint8_t)1u; bump = (uint16_t)73u;  break;
        case 22: next = (uint8_t)4u; bump = (uint16_t)79u;  break;
        case 23: next = (uint8_t)2u; bump = (uint16_t)83u;  break;
        /* The guarded-impossible arm. Keys 6, 11, 13, 16 land here and nothing else can.
           On MOS this legalizes through G_TRAP -> RTLIB::ABORT -> `jsr abort`. On the host it
           is an int3 / ud2. Either way it is never executed — that is the contract. */
        default:
            __builtin_trap();
    }

    *acc = (uint16_t)(tg_mul(*acc, (uint16_t)25173u) + bump);
    return next;
}

static void tg_reset(void) {
    tg_ntrace = (uint16_t)0u;
    tg_acc = (uint16_t)0x1357u;
    tg_guarded = (uint16_t)0u;
    for (uint8_t s = (uint8_t)0u; s < (uint8_t)TG_NS; s++) {
        tg_visit[s] = (uint16_t)0u;
        for (uint8_t e = (uint8_t)0u; e < (uint8_t)TG_NE; e++) tg_pair[s][e] = (uint16_t)0u;
    }
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)TG_TRACE; i++) tg_trace[i] = (uint8_t)0u;
}

// Drive the machine. The generator proposes an event, and REJECTS it when the current state's
// legality mask says it is impossible — so the trap arm is never entered, while the compiler,
// looking only at tg_step, cannot know that.
__attribute__((noinline))
static void tg_run(void) {
    uint8_t  st = (uint8_t)0u;
    uint16_t s  = (uint16_t)0x58C7u;

    for (uint16_t t = (uint16_t)0u; t < (uint16_t)TG_TICKS; t++) {
        s = (uint16_t)(tg_mul(s, (uint16_t)25173u) + (uint16_t)13849u);
        uint8_t ev = (uint8_t)((s >> 9) & 3u);

        /* The guard. Rotate to the next legal event rather than dropping the tick, so every
           legal pair is reached and the schedule stays dense. */
        uint8_t tries = (uint8_t)0u;
        while (((tg_legal[st] >> ev) & (uint8_t)1u) == (uint8_t)0u
               && tries < (uint8_t)TG_NE) {
            tg_guarded = (uint16_t)(tg_guarded + 1u);
            ev = (uint8_t)((uint8_t)(ev + (uint8_t)1u) % (uint8_t)TG_NE);
            tries = (uint8_t)(tries + 1u);
        }

        tg_visit[st] = (uint16_t)(tg_visit[st] + 1u);
        tg_pair[st][ev] = (uint16_t)(tg_pair[st][ev] + 1u);
        st = tg_step(st, ev, &tg_acc);

        if (tg_ntrace < (uint16_t)TG_TRACE) {
            tg_trace[tg_ntrace] = (uint8_t)((uint8_t)(st << 4) | ev);
            tg_ntrace = (uint16_t)(tg_ntrace + 1u);
        }
    }
}

static uint16_t tg_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(tg_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: run the machine, fold the REACHABLE trace only.
// --------------------------------------------------------------------------
static uint16_t trapguard_gate_crc(void) {
    uint16_t h = (uint16_t)0x7E05u;
    tg_reset();
    tg_run();
    h = tg_mix(h, tg_acc);
    h = tg_mix(h, tg_ntrace);
    h = tg_mix(h, tg_guarded);
    for (uint8_t s = (uint8_t)0u; s < (uint8_t)TG_NS; s++) {
        h = tg_mix(h, tg_visit[s]);
        for (uint8_t e = (uint8_t)0u; e < (uint8_t)TG_NE; e++)
            h = tg_mix(h, tg_pair[s][e]);
    }
    for (uint16_t i = (uint16_t)0u; i < tg_ntrace; i++)
        h = tg_mix(h, (uint16_t)tg_trace[i]);
    return h;
}

/* Cross-checks the gate asserts.
   - tg_legal_unvisited(): every LEGAL pair must have fired at least once, so the dispatch
     around the trap is fully exercised rather than a couple of hot arms.
   - tg_illegal_taken(): every IMPOSSIBLE pair must have fired exactly zero times — if one
     ever did, the run would have aborted, so this is belt-and-braces against a generator
     bug that would turn the demo into a crash instead of a gate. */
static uint8_t tg_legal_unvisited(void) {
    uint8_t n = (uint8_t)0u;
    for (uint8_t s = (uint8_t)0u; s < (uint8_t)TG_NS; s++)
        for (uint8_t e = (uint8_t)0u; e < (uint8_t)TG_NE; e++)
            if (((tg_legal[s] >> e) & (uint8_t)1u) && tg_pair[s][e] == (uint16_t)0u)
                n = (uint8_t)(n + 1u);
    return n;
}

static uint8_t tg_illegal_taken(void) {
    uint8_t n = (uint8_t)0u;
    for (uint8_t s = (uint8_t)0u; s < (uint8_t)TG_NS; s++)
        for (uint8_t e = (uint8_t)0u; e < (uint8_t)TG_NE; e++)
            if (((tg_legal[s] >> e) & (uint8_t)1u) == (uint8_t)0u
                && tg_pair[s][e] != (uint16_t)0u)
                n = (uint8_t)(n + 1u);
    return n;
}

#endif /* TRAPGUARD_H */
