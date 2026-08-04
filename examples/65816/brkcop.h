// Software Vectors (#140) — shared deterministic model for the BRK/COP synchronous interrupts.
//
// BRK and COP are the 65816's two *software* interrupts. In native mode each has its own vector
// ($FFE6 BRK, $FFE4 COP) and each pushes PB, PC+2 and P — PC+2, because the opcode is followed by
// a one-byte SIGNATURE the CPU does not interpret. RTI therefore resumes on the instruction AFTER
// the signature byte; a one-byte error lands on the signature itself and desynchronises the
// instruction stream.
//
// The model below is width-agnostic C shared by the ROM (examples/snes/brkcop.c) and the host
// oracle (tools/brkcop-sim.c). The ROM drives the same arithmetic with REAL brk/cop traps taken
// from both a native-width (M=0/X=0) and an 8-bit (M=1/X=1) context; the host just evaluates it.
#ifndef BRKCOP_H
#define BRKCOP_H

#include <stdint.h>

// Four traps per round: BRK@16, BRK@8, COP@16, COP@8. Synchronous, so the counts are exact by
// construction — no armed/done handshake is needed (unlike the asynchronous #123/#124 demos).
#define BRKCOP_ROUNDS 16u

// Signature bytes carried by the trap instructions themselves (`.byte $00,$42` / `.byte $02,$5A`).
#define BRKCOP_BRK_SIG 0x42u
#define BRKCOP_COP_SIG 0x5Au

// Per-handler fold constants — distinct, so a BRK landing in the COP handler (or in the shared
// `irq` stub, the pre-fix wiring) changes the gate hash.
#define BRKCOP_BRK_K 0x9E37u
#define BRKCOP_COP_K 0x7C15u

// Poison-guard sentinels. Each is loaded by the immediate that sits IMMEDIATELY after the trap's
// signature byte, so the value observed by C proves where RTI resumed:
//   * 16-bit sites load a 3-byte immediate (`a9 xx xx` under M=0);
//   * 8-bit sites load a 2-byte immediate (`a9 xx` under M=1).
// Resuming one byte early executes the signature byte as an opcode ($42 = WDM, which swallows the
// following $A9; $5A = PHY, which unbalances the stack) — either way the sentinel that reaches C
// is not the constant below.
#define BRKCOP_S16_BRK 0x5AA5u
#define BRKCOP_S16_COP 0xA55Au
#define BRKCOP_S8_BRK 0x00B7u
#define BRKCOP_S8_COP 0x004Du

#define BRKCOP_BRK_SEED 0x0BADu
#define BRKCOP_COP_SEED 0xC0FEu
#define BRKCOP_SENT_SEED 0x1234u
#define BRKCOP_H_SEED 0x7A11u

// Per-trap handler state advance (runs inside the C interrupt handler on target).
static inline uint16_t brkcop_step(uint16_t v, uint16_t k) {
    return (uint16_t)((uint16_t)((v << 3) | (v >> 13)) + k);
}

// Sentinel accumulator. The ROM passes the value it READ BACK from the poison-guard store; the
// host model passes the constant that store was supposed to have written. Same function, so the
// two agree only when every RTI resumed at the right offset.
static inline uint16_t brkcop_sent_mix(uint16_t s, uint16_t observed, uint16_t r) {
    return (uint16_t)((uint16_t)((s << 1) | (s >> 15)) ^ observed ^ r);
}

static inline uint16_t brkcop_fold(uint16_t h, uint8_t v) {
    return (uint16_t)((uint16_t)((h << 5) | (h >> 11)) ^ (uint16_t)v);
}

static inline uint16_t brkcop_hash(uint16_t brk_hits, uint16_t cop_hits, uint16_t brk_mix,
                                   uint16_t cop_mix, uint16_t sent) {
    uint16_t h = (uint16_t)BRKCOP_H_SEED;
    h = brkcop_fold(h, (uint8_t)brk_hits);
    h = brkcop_fold(h, (uint8_t)(brk_hits >> 8));
    h = brkcop_fold(h, (uint8_t)cop_hits);
    h = brkcop_fold(h, (uint8_t)(cop_hits >> 8));
    h = brkcop_fold(h, (uint8_t)brk_mix);
    h = brkcop_fold(h, (uint8_t)(brk_mix >> 8));
    h = brkcop_fold(h, (uint8_t)cop_mix);
    h = brkcop_fold(h, (uint8_t)(cop_mix >> 8));
    h = brkcop_fold(h, (uint8_t)sent);
    h = brkcop_fold(h, (uint8_t)(sent >> 8));
    return h;
}

// The oracle. `examples/snes/brkcop.c` reproduces this loop exactly, but with each of the four
// state advances performed by a real trap into a real C handler.
static uint16_t brkcop_model(uint16_t *brk_out, uint16_t *cop_out, uint16_t *sent_out) {
    uint16_t brk_hits = 0u, cop_hits = 0u;
    uint16_t brk_mix = (uint16_t)BRKCOP_BRK_SEED, cop_mix = (uint16_t)BRKCOP_COP_SEED;
    uint16_t sent = (uint16_t)BRKCOP_SENT_SEED;
    for (uint16_t r = 1u; r <= (uint16_t)BRKCOP_ROUNDS; r++) {
        brk_hits = (uint16_t)(brk_hits + 1u);
        brk_mix = brkcop_step(brk_mix, (uint16_t)BRKCOP_BRK_K);
        sent = brkcop_sent_mix(sent, (uint16_t)BRKCOP_S16_BRK, r);

        brk_hits = (uint16_t)(brk_hits + 1u);
        brk_mix = brkcop_step(brk_mix, (uint16_t)BRKCOP_BRK_K);
        sent = brkcop_sent_mix(sent, (uint16_t)BRKCOP_S8_BRK, r);

        cop_hits = (uint16_t)(cop_hits + 1u);
        cop_mix = brkcop_step(cop_mix, (uint16_t)BRKCOP_COP_K);
        sent = brkcop_sent_mix(sent, (uint16_t)BRKCOP_S16_COP, r);

        cop_hits = (uint16_t)(cop_hits + 1u);
        cop_mix = brkcop_step(cop_mix, (uint16_t)BRKCOP_COP_K);
        sent = brkcop_sent_mix(sent, (uint16_t)BRKCOP_S8_COP, r);
    }
    if (brk_out) *brk_out = brk_hits;
    if (cop_out) *cop_out = cop_hits;
    if (sent_out) *sent_out = sent;
    return brkcop_hash(brk_hits, cop_hits, brk_mix, cop_mix, sent);
}

#endif
