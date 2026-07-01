// Shared, PURE sparse-switch step-sequencer VM — host-linkable, no hardware.  Demo #37.
//
// The codegen corner: a **sparse switch**.  The interpreter dispatches each opcode with
//   switch (op) { case 0x10: ...; case 0x23: ...; case 0x88: ...; }
// whose case values are NON-CONTIGUOUS, widely-spaced bytes (0x00, 0x10, 0x23, 0x47, 0x88, 0xC1,
// 0xF0, ...).  With ~14 cases spread across 0x00..0xF0 the density is far too low for a jump table,
// so the compiler must lower it to a **binary-search comparison tree** (a cascade of cmp/branch) —
// a different control-flow shape than #38's computed-`goto` threaded dispatch or #29a's dense jump
// table.  A tiny register VM runs a looping bytecode "song" that stirs 8 registers; the registers
// drive an 8-bar equalizer light show.
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - registers, opcodes and operands are all uint8_t; arithmetic wraps mod 256 identically
//   - the rotate/shift masks the count with &7 so it's well-defined on both platforms
//   - no bare int; the fold is uint16_t
// See docs/plans/2026-06-30-37-snes-seqvm.md.
#ifndef SEQVM_H
#define SEQVM_H

#include <stdint.h>

#define SEQ_NREG   8u      // registers r0..r7 (also the 8 equalizer bars)
#define SEQ_LEVELS 8u      // bar height 0..8

// ---------------------------------------------------------------------------------------------
// Instruction set — NON-CONTIGUOUS opcodes so switch(op) lowers to a comparison tree, not a table.
#define OP_NOP  0x00u      // no-op
#define OP_SET  0x10u      // r[a] = b
#define OP_ADD  0x23u      // r[a] += r[b]
#define OP_SUB  0x35u      // r[a] -= r[b]
#define OP_XOR  0x47u      // r[a] ^= r[b]
#define OP_OR   0x59u      // r[a] |= r[b]
#define OP_AND  0x6Bu      // r[a] &= r[b]
#define OP_ROL  0x88u      // r[a] = rotate-left(r[a], r[b] & 7)
#define OP_SHL  0x9Au      // r[a] <<= (b & 7)
#define OP_INC  0xA5u      // r[a] += b
#define OP_DEC  0xB2u      // r[a] -= b
#define OP_MIX  0xC1u      // r[a] ^= (tick + b)   — injects time so the show never converges
#define OP_JNZ  0xD3u      // if r[a] != 0: pc = b  (loop the song)
#define OP_HALT 0xF0u      // pc = 0 (restart)

typedef struct {
    uint8_t  reg[SEQ_NREG];
    uint16_t pc;           // byte offset into SEQ_PROG (triples)
    uint16_t tick;         // global step counter (fed into OP_MIX)
} seqvm_state;

// The bytecode "song": triples (op, a, b).  A generative loop that keeps the 8 bars dancing.
static const uint8_t SEQ_PROG[] = {
    OP_MIX, 0, 0x01,       // r0 ^= tick+1
    OP_ROL, 1, 3,          // r1 = rol(r1, r3&7)
    OP_ADD, 2, 0,          // r2 += r0
    OP_XOR, 3, 2,          // r3 ^= r2
    OP_MIX, 4, 0x07,       // r4 ^= tick+7
    OP_ADD, 5, 4,          // r5 += r4
    OP_ROL, 6, 1,          // r6 = rol(r6, r1&7)
    OP_XOR, 7, 5,          // r7 ^= r5
    OP_ADD, 0, 7,          // r0 += r7
    OP_SUB, 2, 6,          // r2 -= r6
    OP_INC, 4, 0x11,       // r4 += 0x11
    OP_AND, 6, 3,          // r6 &= r3
    OP_OR,  1, 7,          // r1 |= r7
    OP_SHL, 5, 1,          // r5 <<= 1
    OP_JNZ, 3, 0,          // if r3 != 0: restart the song (loop)
    OP_HALT, 0, 0,         // otherwise restart anyway
};
#define SEQ_PROG_LEN ((uint16_t)(sizeof SEQ_PROG))

static inline uint8_t seq_rol(uint8_t v, uint8_t n) {
    n &= 7u;
    return (uint8_t)((uint8_t)(v << n) | (uint8_t)(v >> ((8u - n) & 7u)));  // n==0 -> v>>0 -> v
}

static void seqvm_init(seqvm_state *s) {
    s->reg[0] = 0x01u; s->reg[1] = 0x02u; s->reg[2] = 0x04u; s->reg[3] = 0x08u;
    s->reg[4] = 0x10u; s->reg[5] = 0x20u; s->reg[6] = 0x40u; s->reg[7] = 0x80u;
    s->pc = 0u;
    s->tick = 0u;
}

// Execute ONE instruction (the sparse switch — the codegen under test). Advances pc + tick.
static void seqvm_step(seqvm_state *s) {
    if (s->pc + 2u >= SEQ_PROG_LEN) s->pc = 0u;
    uint8_t op = SEQ_PROG[s->pc];
    uint8_t a  = (uint8_t)(SEQ_PROG[s->pc + 1u] & 7u);
    uint8_t b  = SEQ_PROG[s->pc + 2u];
    s->pc = (uint16_t)(s->pc + 3u);

    switch (op) {                                   // <-- SPARSE SWITCH: comparison-tree lowering
        case OP_NOP:  break;
        case OP_SET:  s->reg[a] = b; break;
        case OP_ADD:  s->reg[a] = (uint8_t)(s->reg[a] + s->reg[b & 7u]); break;
        case OP_SUB:  s->reg[a] = (uint8_t)(s->reg[a] - s->reg[b & 7u]); break;
        case OP_XOR:  s->reg[a] = (uint8_t)(s->reg[a] ^ s->reg[b & 7u]); break;
        case OP_OR:   s->reg[a] = (uint8_t)(s->reg[a] | s->reg[b & 7u]); break;
        case OP_AND:  s->reg[a] = (uint8_t)(s->reg[a] & s->reg[b & 7u]); break;
        case OP_ROL:  s->reg[a] = seq_rol(s->reg[a], s->reg[b & 7u]); break;
        case OP_SHL:  s->reg[a] = (uint8_t)(s->reg[a] << (b & 7u)); break;
        case OP_INC:  s->reg[a] = (uint8_t)(s->reg[a] + b); break;
        case OP_DEC:  s->reg[a] = (uint8_t)(s->reg[a] - b); break;
        case OP_MIX:  s->reg[a] = (uint8_t)(s->reg[a] ^ (uint8_t)(s->tick + b)); break;
        case OP_JNZ:  if (s->reg[a]) s->pc = b; break;
        case OP_HALT: s->pc = 0u; break;
        default:      break;
    }
    s->tick = (uint16_t)(s->tick + 1u);
}

// Bar height (0..SEQ_LEVELS) for register c — the equalizer level.
static inline uint8_t seqvm_level(const seqvm_state *s, uint8_t c) {
    return (uint8_t)(((uint16_t)s->reg[c] * (SEQ_LEVELS + 1u)) >> 8);  // 0..8
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t seq_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_STEPS
#define GATE_STEPS 400u
#endif

static uint16_t seqvm_gate_crc(void) {
    seqvm_state s;
    seqvm_init(&s);
    uint16_t h = 0;
    for (uint16_t i = 0; i < (uint16_t)GATE_STEPS; i++) {
        seqvm_step(&s);
        h = seq_fold(h, (uint16_t)(((uint16_t)s.reg[0] << 8) | s.reg[1]));
        h = seq_fold(h, (uint16_t)(((uint16_t)s.reg[4] << 8) | s.reg[7]));
    }
    for (uint8_t r = 0; r < SEQ_NREG; r++) h = seq_fold(h, s.reg[r]);
    return h;
}

#endif /* SEQVM_H */
