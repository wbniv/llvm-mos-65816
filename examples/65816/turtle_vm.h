// #29a SNES compiler stress-test — BYTECODE VM: jump-table dispatch + function-pointer opcode table.
//
// SINGLE SOURCE OF TRUTH shared by the on-target program (examples/snes/turtle-vm.c), the corpus slice
// (examples/snes/corpus/turtle-vm_sim.c) and the host oracle (tools/turtle-vm-sim.c).
//
// Why this demo exists: every other demo is straight-line arithmetic with simple branches. NONE use
// computed / indirect control flow. This one is a tiny stack-machine bytecode interpreter that draws
// LOGO turtle graphics, and it leans on the two indirect-dispatch corners the battery never executes:
//
//   1. JUMP-TABLE DISPATCH — the interpreter's main switch(op) over a DENSE opcode range lowers to a
//      `JMP (abs,X)` (the JMPIdxIndir pseudo) — a computed branch through a table of code addresses.
//      This is exactly the dispatch the recent xy16 `requiredXWidth` hardening singled out, so the demo
//      is a live cross-mode exercise of that fix.
//   2. FUNCTION-POINTER OPCODE TABLE — the binary ALU ops (+ - * % min max) live in a `static const`
//      array of function pointers, invoked indirectly (`jsr __call_indir` through a .rodata table).
//
// BIT-EXACT DIFFERENTIAL: the VM is deterministic integer fixed-point (turtle position Q8.8 in int32,
// heading 0..255 indexing the shared SINCOS 8.8 LUT; segment math widened to int32 -> __mulsi3). Exact
// ops are reproducible, so a conforming build equals host x86 bit-for-bit; a jump-table or indirect-call
// miscompile dispatches a wrong opcode and the path CRC diverges. Far-pointer-free (bytecode, stacks,
// turtle all in bank-0 WRAM; NEAR function pointers) -> full 5-way bar.
#ifndef TURTLE_VM_H
#define TURTLE_VM_H

#include <stdint.h>
#include "../snes/sincos.h"     // SINCOS[256], signed 8.8 sine; cos(a)=SINCOS[(a+64)&255]

// ---- opcodes (DENSE 0..10 so the dispatch switch lowers to a JMP (abs,X) jump table) --------------
enum {
  OP_HALT = 0, OP_PUSH, OP_ALU, OP_FWD, OP_TURN, OP_PEN, OP_REP, OP_ENDREP, OP_ITER, OP_DUP, OP_DROP
};
// ALU sub-ops — indices into the function-pointer table ALU_TAB (the indirect call).
enum { ALU_ADD = 0, ALU_SUB, ALU_MUL, ALU_MOD, ALU_MIN, ALU_MAX };

#define VM_CANVAS   128         // turtle draws on a 128x128 surface
#ifndef VM_START_X
#define VM_START_X  28          // turtle start (chosen so the rosette centres in the canvas)
#endif
#ifndef VM_START_Y
#define VM_START_Y  30
#endif
#define VM_STACK     16         // data-stack depth
#define VM_LOOPS      4         // loop-stack depth
#define VM_NOINLINE static __attribute__((noinline))

typedef uint16_t (*AluFn)(uint16_t, uint16_t);

// The binary operators behind OP_ALU. noinline + stored in a const pointer table => the call site is a
// genuine indirect call (jsr __call_indir), not a devirtualised direct call.
VM_NOINLINE uint16_t alu_add(uint16_t a, uint16_t b) { return (uint16_t)(a + b); }
VM_NOINLINE uint16_t alu_sub(uint16_t a, uint16_t b) { return (uint16_t)(a - b); }
VM_NOINLINE uint16_t alu_mul(uint16_t a, uint16_t b) { return (uint16_t)((uint32_t)a * b); }  // __mulsi3
VM_NOINLINE uint16_t alu_mod(uint16_t a, uint16_t b) { return (uint16_t)(b ? a % b : a); }
VM_NOINLINE uint16_t alu_min(uint16_t a, uint16_t b) { return a < b ? a : b; }
VM_NOINLINE uint16_t alu_max(uint16_t a, uint16_t b) { return a > b ? a : b; }

static const AluFn ALU_TAB[6] = { alu_add, alu_sub, alu_mul, alu_mod, alu_min, alu_max };

// A drawn line segment (canvas coords, pen colour 1..3). Compact: 5 bytes.
typedef struct { uint8_t x0, y0, x1, y1, col; } Seg;

typedef struct { uint8_t count, total; uint16_t start; } LoopFrame;

// Clamp a Q8.8 position to a canvas pixel [0,127] — deterministic on host & target (the figure is
// designed to stay in-bounds; this only guards the rare edge sample so the CRC never depends on UB).
static inline uint8_t vm_px(int32_t q88) {
  int32_t p = q88 >> 8;
  if (p < 0) p = 0; else if (p > VM_CANVAS - 1) p = VM_CANVAS - 1;
  return (uint8_t)p;
}

// Run the bytecode program. Returns a rotate-XOR CRC16 over every emitted segment (the differential
// anchor). If `segs` is non-NULL, also records up to `maxseg` segments (and *nseg_out) for the renderer
// to draw — recording does NOT change the CRC, so gate (segs=NULL) and ROM agree bit-for-bit.
static uint16_t vm_run(const uint8_t *prog, uint16_t len,
                       Seg *segs, uint16_t maxseg, uint16_t *nseg_out) {
  int16_t st[VM_STACK]; uint8_t sp = 0;
  LoopFrame ls[VM_LOOPS]; uint8_t lp = 0;
  int32_t tx = (int32_t)VM_START_X << 8, ty = (int32_t)VM_START_Y << 8;            // turtle Q8.8
  uint8_t heading = 0, pen = 0;
  uint16_t pc = 0, nseg = 0, crc = 0xFFFF;
  uint16_t guard = 0;                       // belt-and-braces step cap (no runaway on a bad program)

  while (pc < len && guard < 50000u) {
    guard++;
    uint8_t op = prog[pc++];
    switch (op) {                            // <-- dense switch => JMP (abs,X) jump-table dispatch
      case OP_HALT:
        pc = len; break;
      case OP_PUSH:
        if (sp < VM_STACK) st[sp++] = (int16_t)(uint8_t)prog[pc];
        pc++; break;
      case OP_ALU: {                         // <-- function-pointer opcode table (indirect call)
        uint8_t sub = (uint8_t)(prog[pc++] % 6u);
        if (sp >= 2) {
          uint16_t b = (uint16_t)st[--sp], a = (uint16_t)st[--sp];
          st[sp++] = (int16_t)ALU_TAB[sub](a, b);
        }
        break;
      }
      case OP_FWD: {
        uint16_t d = (sp > 0) ? (uint16_t)st[--sp] : 0u;
        int32_t nx = tx + (int32_t)(int16_t)d * SINCOS[(uint8_t)(heading + 64)];   // __mulsi3 (cos)
        int32_t ny = ty + (int32_t)(int16_t)d * SINCOS[heading];                   // __mulsi3 (sin)
        if (pen) {
          uint8_t x0 = vm_px(tx), y0 = vm_px(ty), x1 = vm_px(nx), y1 = vm_px(ny);
          crc = (uint16_t)((uint16_t)(((unsigned)crc << 1) | ((unsigned)crc >> 15)) ^ (uint16_t)((x0 << 8) | y0));
          crc = (uint16_t)((uint16_t)(((unsigned)crc << 1) | ((unsigned)crc >> 15)) ^ (uint16_t)((x1 << 8) | y1));
          crc = (uint16_t)((uint16_t)(((unsigned)crc << 1) | ((unsigned)crc >> 15)) ^ (uint16_t)pen);
          if (segs && nseg < maxseg) { segs[nseg].x0 = x0; segs[nseg].y0 = y0;
            segs[nseg].x1 = x1; segs[nseg].y1 = y1; segs[nseg].col = pen; nseg++; }
        }
        tx = nx; ty = ny; break;
      }
      case OP_TURN: {
        uint16_t a = (sp > 0) ? (uint16_t)st[--sp] : 0u;
        heading = (uint8_t)(heading + (uint8_t)a); break;
      }
      case OP_PEN:
        if (sp > 0) pen = (uint8_t)((uint16_t)st[--sp] & 3u); break;
      case OP_REP:
        if (lp < VM_LOOPS) { ls[lp].count = prog[pc]; ls[lp].total = prog[pc];
          ls[lp].start = (uint16_t)(pc + 1); lp++; }
        pc++; break;
      case OP_ENDREP:
        if (lp > 0) {
          if (ls[lp - 1].count > 1) { ls[lp - 1].count--; pc = ls[lp - 1].start; }
          else lp--;
        }
        break;
      case OP_ITER:                          // current loop's iteration index (0-based)
        if (sp < VM_STACK) st[sp++] = (int16_t)(lp > 0 ? (uint8_t)(ls[lp - 1].total - ls[lp - 1].count) : 0);
        break;
      case OP_DUP:
        if (sp > 0 && sp < VM_STACK) { st[sp] = st[sp - 1]; sp++; } break;
      case OP_DROP:
        if (sp > 0) sp--; break;
      default: break;
    }
  }
  if (nseg_out) *nseg_out = nseg;
  return crc;
}

// The bytecode program: a multi-colour spiral rosette. REP 180 [ pen=iter%3+1; FWD step; TURN 67 ]. The
// per-iteration colour is computed through the ALU function-pointer table (MOD then ADD), and the whole
// run dispatches through the jump-table switch.
#ifndef VM_STEP
#define VM_STEP 75      // forward distance per segment (sets the rosette size)
#endif
#ifndef VM_TURN
#define VM_TURN 67      // turn per segment (of 256 = 360 deg)
#endif
#ifndef VM_REPS
#define VM_REPS 180     // number of segments
#endif
static const uint8_t VM_PROG[] = {
  OP_REP, VM_REPS,
    OP_ITER, OP_PUSH, 3, OP_ALU, ALU_MOD,    // iter % 3
            OP_PUSH, 1, OP_ALU, ALU_ADD,     // + 1  -> 1..3
    OP_PEN,                                  // pen colour = that
    OP_PUSH, VM_STEP, OP_FWD,                // forward VM_STEP
    OP_PUSH, VM_TURN, OP_TURN,               // turn VM_TURN/256
  OP_ENDREP,
  OP_HALT
};
#define VM_PROG_LEN ((uint16_t)(sizeof VM_PROG))
#define VM_MAX_SEG  192u            // upper bound on segments the program emits

// Differential anchor: run the program (no segment storage), return the path CRC. Far-pointer-free,
// flows through both the jump-table switch and the fnptr ALU table -> bit-exact witness of both.
static inline uint16_t vm_gate_crc(void) {
  return vm_run(VM_PROG, VM_PROG_LEN, (Seg *)0, 0, (uint16_t *)0);
}

#endif /* TURTLE_VM_H */
