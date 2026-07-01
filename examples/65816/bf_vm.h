// Shared, PURE Brainfuck threaded-code VM — host-linkable, no hardware.  Demo #38.
//
// The point of this file is ONE codegen corner: **computed `goto` / labels-as-values**
// (`goto *handlers[op]`) — the "threaded code" interpreter dispatch that lowers to an
// indirect jump (`jmp ($ind)`, opcode $6C on the 65816), a path distinct from #29a's dense
// `switch` jump-table.  The VM runs a fixed Brainfuck program (the canonical "Hello World!")
// whose nested `[ ]` loops exercise all eight handlers and many thousands of dispatches.
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - tape cells are uint8_t (wrap mod 256 exactly like the host)
//   - data pointer / program counter are uint16_t, wrapped explicitly
//   - the gate CRC is uint16_t
// No bare `int`.  No 32-bit arithmetic — this demo is pure control-flow, not ALU.
//
// See docs/plans/2026-06-30-38-snes-bf-vm.md.
#ifndef BF_VM_H
#define BF_VM_H

#include <stdint.h>

// ---------------------------------------------------------------------------------------------
// Configuration

#define BF_TAPE_N     64u      // tape cells (power of two → cheap pointer wrap).  Hello World
                               // uses cells 0..6; 64 leaves room for other programs.
#define BF_TAPE_MASK  (BF_TAPE_N - 1u)
#define BF_OUT_N      32u      // ring buffer of recently emitted output bytes (the marquee)
#define BF_OUT_MASK   (BF_OUT_N - 1u)
#define BF_PROG_MAX   128u     // max compiled token count

// Opcodes — the index into the threaded handler table.  Order is the dispatch order.
enum {
    BF_INCP = 0,  // '>'  dp++
    BF_DECP = 1,  // '<'  dp--
    BF_INC  = 2,  // '+'  tape[dp]++
    BF_DEC  = 3,  // '-'  tape[dp]--
    BF_OUT  = 4,  // '.'  emit tape[dp]
    BF_IN   = 5,  // ','  read input (deterministic: EOF → 0)
    BF_JZ   = 6,  // '['  jump past matching ']' if tape[dp]==0
    BF_JNZ  = 7,  // ']'  jump back after matching '[' if tape[dp]!=0
    BF_HALT = 8   // end of program sentinel
};

// The canonical "Hello World!" Brainfuck program (outputs "Hello World!\n").
// Many nested loops → heavy threaded dispatch; every operator except ',' appears.
#define BF_SOURCE \
    "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."

// ---------------------------------------------------------------------------------------------
// VM state.  All bank-0, NEAR — no far pointers → builds default + a16 + xy16 (5-way bar).

typedef struct {
    uint8_t  prog[BF_PROG_MAX];   // compiled opcode stream (one BF_* per token)
    uint16_t jump[BF_PROG_MAX];   // precomputed matching-bracket target (for JZ/JNZ)
    uint16_t prog_len;            // number of compiled tokens

    uint8_t  tape[BF_TAPE_N];     // the cells
    uint16_t dp;                  // data pointer (0..BF_TAPE_N-1)
    uint16_t pc;                  // program counter (0..prog_len)

    uint8_t  out[BF_OUT_N];       // ring of emitted bytes
    uint16_t out_head;            // total bytes emitted (monotone; index = & BF_OUT_MASK)
    uint16_t out_last;            // last byte emitted (for the gate / display)

    uint16_t steps;               // total ops executed (monotone)
    uint8_t  halted;              // 1 once pc reached prog_len
} bf_vm;

// ---------------------------------------------------------------------------------------------
// Compile a NUL-terminated BF source string into prog[] + jump[] and reset the machine.
// Non-BF characters are skipped (so the source may contain whitespace/comments).

static void bf_init(bf_vm *v, const char *src) {
    uint16_t n = 0;
    for (const char *p = src; *p && n < BF_PROG_MAX; p++) {
        uint8_t op;
        switch (*p) {
            case '>': op = BF_INCP; break;
            case '<': op = BF_DECP; break;
            case '+': op = BF_INC;  break;
            case '-': op = BF_DEC;  break;
            case '.': op = BF_OUT;  break;
            case ',': op = BF_IN;   break;
            case '[': op = BF_JZ;   break;
            case ']': op = BF_JNZ;  break;
            default:  continue;
        }
        v->prog[n++] = op;
    }
    v->prog_len = n;

    // Precompute bracket matches with an explicit stack (no recursion).
    uint16_t stack[BF_PROG_MAX];
    uint16_t sp = 0;
    for (uint16_t i = 0; i < n; i++) {
        if (v->prog[i] == BF_JZ) {
            stack[sp++] = i;
        } else if (v->prog[i] == BF_JNZ) {
            uint16_t open = sp ? stack[--sp] : i;
            v->jump[i]    = open;   // ']' targets its '['  (re-test there)
            v->jump[open] = i;      // '[' targets its ']'  (skip past)
        }
    }

    for (uint16_t i = 0; i < BF_TAPE_N; i++) v->tape[i] = 0;
    v->dp = 0; v->pc = 0;
    v->out_head = 0; v->out_last = 0;
    v->steps = 0; v->halted = 0;
    for (uint16_t i = 0; i < BF_OUT_N; i++) v->out[i] = 0;
}

// ---------------------------------------------------------------------------------------------
// Run up to `budget` instructions via THREADED DISPATCH (`goto *handlers[op]`).  Resumable:
// state (pc/dp/tape/out) persists across calls, so the display can step a few ops per frame
// and the gate can run the whole program in one call.  Returns the number of ops executed.
//
// This is the demo's reason to exist — the dispatch is a computed goto, not a switch.

static uint16_t bf_run(bf_vm *v, uint16_t budget) {
    static const void *const handlers[9] = {
        &&h_incp, &&h_decp, &&h_inc, &&h_dec,
        &&h_out,  &&h_in,   &&h_jz,  &&h_jnz, &&h_halt
    };
    uint16_t executed = 0;

    // Local fast copies (the hot registers); written back on exit.
    uint16_t pc = v->pc, dp = v->dp;

    #define BF_NEXT()                                                   \
        do {                                                            \
            if (executed >= budget || pc >= v->prog_len) goto h_done;   \
            executed++; v->steps++;                                     \
            goto *handlers[v->prog[pc++]];                              \
        } while (0)

    if (v->halted) return 0;
    BF_NEXT();

h_incp: dp = (uint16_t)((dp + 1u) & BF_TAPE_MASK);                BF_NEXT();
h_decp: dp = (uint16_t)((dp - 1u) & BF_TAPE_MASK);                BF_NEXT();
h_inc:  v->tape[dp] = (uint8_t)(v->tape[dp] + 1u);               BF_NEXT();
h_dec:  v->tape[dp] = (uint8_t)(v->tape[dp] - 1u);               BF_NEXT();
h_out:
        v->out_last = v->tape[dp];
        v->out[v->out_head & BF_OUT_MASK] = v->tape[dp];
        v->out_head++;
        BF_NEXT();
h_in:   v->tape[dp] = 0;  /* deterministic EOF */                BF_NEXT();
h_jz:
        if (v->tape[dp] == 0u) pc = (uint16_t)(v->jump[pc - 1u] + 1u);
        BF_NEXT();
h_jnz:
        if (v->tape[dp] != 0u) pc = (uint16_t)(v->jump[pc - 1u] + 1u);
        BF_NEXT();
h_halt:                                                           goto h_done;

h_done:
    v->pc = pc; v->dp = dp;
    if (pc >= v->prog_len) v->halted = 1;
    #undef BF_NEXT
    return executed;
}

// ---------------------------------------------------------------------------------------------
// CRC fold (shared rotate-xor).

static inline uint16_t bf_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

// ---------------------------------------------------------------------------------------------
// Differential gate CRC.  Runs the whole Hello-World program to completion (capped at GATE_N
// instructions), folding every emitted output byte, then the final tape + dp + step count.
// SAME computation host and 65816 — any miscompile of the threaded dispatch diverges the CRC.

#ifndef GATE_N
#define GATE_N 20000u    // instruction cap — Hello World runs ~1.7k ops, well under this
#endif

static uint16_t bf_vm_gate_crc(void) {
    static bf_vm v;
    bf_init(&v, BF_SOURCE);

    uint16_t h = 0;
    uint16_t prev_out = 0;
    // Step in chunks; fold each newly-emitted output byte (the program's observable result).
    while (!v.halted && v.steps < GATE_N) {
        bf_run(&v, 64u);
        while (prev_out < v.out_head) {
            h = bf_fold(h, v.out[prev_out & BF_OUT_MASK]);
            prev_out++;
        }
    }
    // Fold final machine state — sensitive to any divergence in pointer/cell handling.
    for (uint16_t i = 0; i < 8u; i++) h = bf_fold(h, v.tape[i]);
    h = bf_fold(h, v.dp);
    h = bf_fold(h, v.steps);
    h = bf_fold(h, v.out_head);
    return h;
}

#endif /* BF_VM_H */
