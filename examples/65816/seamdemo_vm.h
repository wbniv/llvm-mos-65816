// examples/65816/seamdemo_vm.h — the Act 1 bytecode VM, shared by the SNES ROM
// and the host harness.
//
// One implementation, three consumers:
//   examples/snes/seamdemo.c   the ROM  (SEAMVM_MEM8 = a 24-bit far read)
//   tools/seamdemo-sim.c       the host (SEAMVM_MEM8 = an array index)
//   tools/snes_seamdemo_oracle.py   the independent Python re-derivation
// The gate asserts all three agree; that is the differential.
//
// The ISA is the "P0 design" section of
// docs/plans/2026-08-01-exhirom-three-act-synthesis-cart.md. Every opcode value,
// the direction table and the canvas mask come from the GENERATED
// seamdemo-data.h, which the includer must have included first — this header
// hard-codes nothing about the cartridge.
//
// The includer must define, before including:
//   SEAMVM_MEM8(file)                      -> uint8_t, read one cartridge byte
//                                             at a 24-bit FILE offset
//   SEAMVM_DRAW(ctx, x0, y0, x1, y1, pen)  -> void, may expand to nothing
//
// Codegen this is written to stress (asserted in dev/seamdemo.sh):
//   * every fetch is a far read through a runtime 24-bit cursor,
//   * the 16-way dense switch must lower to a jump table (JMP (abs,X)), and
//   * SEAMVM_ALU_TAB is a const function-pointer array with a runtime index,
//     which must lower to `jsr __call_indir` rather than being devirtualised.
#ifndef SEAMDEMO_VM_H
#define SEAMDEMO_VM_H

#include <stdint.h>

#ifndef SEAMVM_MEM8
#error "define SEAMVM_MEM8(file) before including seamdemo_vm.h"
#endif
#ifndef SEAMVM_DRAW
#define SEAMVM_DRAW(ctx, x0, y0, x1, y1, pen) ((void)0)
#endif

// --- status bits (0 == every structural check passed) ---------------------
#define SEAMVM_ST_XLAT 0x0001u        // the generated file->CPU table is not the assumed shape
#define SEAMVM_ST_SEAM_SHAPE 0x0002u  // the byte at the device seam is not the contract's SYNC
#define SEAMVM_ST_BAD_OPCODE 0x0004u  // the stream contains an opcode outside the ISA
#define SEAMVM_ST_BUDGET 0x0008u      // the stream did not terminate inside its op budget
#define SEAMVM_ST_CRC 0x0010u         // the act folded to something other than the oracle value

// Rotate left 1, then add — kept in lockstep with fold() in
// tools/snes-cartcanary.py (which the Python oracle imports). The add's carry is
// what stops the fold collapsing over the payload's power-of-two-aligned runs
// the way an XOR fold does.
static inline uint16_t seamvm_fold(uint16_t h, uint8_t b) {
  return (uint16_t)(((h << 1) | (h >> 15)) + b);
}

// --- the ALU table: eight tiny functions behind a runtime index -----------
static uint16_t seamvm_add(uint16_t d, uint16_t s) { return (uint16_t)(d + s); }
static uint16_t seamvm_sub(uint16_t d, uint16_t s) { return (uint16_t)(d - s); }
static uint16_t seamvm_xor(uint16_t d, uint16_t s) { return (uint16_t)(d ^ s); }
static uint16_t seamvm_and(uint16_t d, uint16_t s) { return (uint16_t)(d & s); }
static uint16_t seamvm_or(uint16_t d, uint16_t s) { return (uint16_t)(d | s); }
static uint16_t seamvm_shl(uint16_t d, uint16_t s) { (void)s; return (uint16_t)(d << 1); }
static uint16_t seamvm_ror(uint16_t d, uint16_t s) {
  (void)s;
  return (uint16_t)((d >> 1) | (d << 15));
}
static uint16_t seamvm_mullo(uint16_t d, uint16_t s) { return (uint16_t)(d * s); }

static uint16_t (*const SEAMVM_ALU_TAB[VMALU_COUNT])(uint16_t, uint16_t) = {
    seamvm_add, seamvm_sub, seamvm_xor, seamvm_and,
    seamvm_or,  seamvm_shl, seamvm_ror, seamvm_mullo,
};

typedef struct {
  unsigned long pc;  // 24-bit FILE offset — the whole point of the act
  unsigned long ops;
  uint16_t r[8];
  uint16_t crc;
  uint16_t nseg;    // drawn segments, for the HUD
  uint16_t status;
  uint8_t x, y, heading, pen;
  uint8_t halted;
  uint8_t yield;    // frames the last SYNC asked for
  uint8_t seam_hit; // the instruction split across the device seam just ran
} SeamVm;

static void seamvm_init(SeamVm *v) {
  for (uint8_t i = 0; i < 8; i++) v->r[i] = 0;
  v->pc = SEAMDEMO_ACT1_ENTRY;
  v->ops = 0;
  v->crc = 0;
  v->nseg = 0;
  v->x = 64;
  v->y = 64;
  v->heading = 0;
  v->pen = 1;
  v->halted = 0;
  v->yield = 0;
  v->seam_hit = 0;
  // `status` is deliberately NOT cleared: the caller's boot-time structural
  // checks live there and must survive a lap boundary.
}

// One instruction. noinline so the dispatch stays ONE jump table in ONE function
// rather than being cloned into the caller's frame loop — which is the shape the
// gate's disasm probe reads.
__attribute__((noinline)) static void seamvm_step(SeamVm *v, void *ctx) {
  unsigned long pc = v->pc;
  const unsigned long op_pc = pc;
  uint8_t tmp;
  (void)ctx;  // unused when SEAMVM_DRAW is the no-op (the host harness)
  uint8_t op = SEAMVM_MEM8(pc);
  pc = (pc + 1UL) & 0xFFFFFFUL;
  v->ops++;

  // The contract's seam: this opcode byte is the LAST byte of physical ROM 1 and
  // its operand is the FIRST byte of physical ROM 2.
  if (op_pc == (SEAMDEMO_SEAM0_FILE - 1UL)) {
    v->seam_hit = 1;
    if (op != VMOP_SYNC) v->status |= SEAMVM_ST_SEAM_SHAPE;
  }

#define SEAMVM_FETCH() (tmp = SEAMVM_MEM8(pc), pc = (pc + 1UL) & 0xFFFFFFUL, tmp)
#define SEAMVM_BRANCH(d) (pc = (pc + (unsigned long)(long)(int8_t)(d)) & 0xFFFFFFUL)

  switch (op) {
    case VMOP_HALT:
      v->halted = 1;
      break;

    case VMOP_NOP:
      break;

    case VMOP_IMM: {
      uint8_t a = SEAMVM_FETCH();
      uint8_t i = SEAMVM_FETCH();
      v->r[a & 7] = i;
      break;
    }

    case VMOP_IMMH: {
      uint8_t a = SEAMVM_FETCH();
      uint8_t i = SEAMVM_FETCH();
      v->r[a & 7] = (uint16_t)((v->r[a & 7] & 0x00FFu) | ((uint16_t)i << 8));
      break;
    }

    case VMOP_ALU: {
      uint8_t f = SEAMVM_FETCH();
      uint8_t ab = SEAMVM_FETCH();
      uint8_t d = (uint8_t)((ab >> 4) & 7u);
      uint8_t s = (uint8_t)(ab & 7u);
      v->r[d] = SEAMVM_ALU_TAB[f & 7u](v->r[d], v->r[s]);  // <-- __call_indir
      break;
    }

    case VMOP_MOVE: {
      uint8_t a = SEAMVM_FETCH();
      uint8_t dist = (uint8_t)(v->r[a & 7] & 0x3Fu);
      int16_t dx = seamdemo_dir16[(v->heading >> 4) & 15][0];
      int16_t dy = seamdemo_dir16[(v->heading >> 4) & 15][1];
      uint8_t x0 = v->x, y0 = v->y;
      v->x = (uint8_t)(((int16_t)v->x + dx * (int16_t)dist) & SEAMDEMO_CANVAS_MASK);
      v->y = (uint8_t)(((int16_t)v->y + dy * (int16_t)dist) & SEAMDEMO_CANVAS_MASK);
      v->crc = seamvm_fold(v->crc, x0);
      v->crc = seamvm_fold(v->crc, y0);
      v->crc = seamvm_fold(v->crc, v->x);
      v->crc = seamvm_fold(v->crc, v->y);
      v->crc = seamvm_fold(v->crc, v->pen);
      SEAMVM_DRAW(ctx, x0, y0, v->x, v->y, v->pen);
      v->nseg++;
      break;
    }

    case VMOP_TURN: {
      uint8_t i = SEAMVM_FETCH();
      v->heading = (uint8_t)(v->heading + i);
      break;
    }

    case VMOP_PEN: {
      uint8_t i = SEAMVM_FETCH();
      v->pen = (uint8_t)(i & 3u);
      break;
    }

    case VMOP_JREL: {
      uint8_t i = SEAMVM_FETCH();
      SEAMVM_BRANCH(i);
      break;
    }

    case VMOP_JZ: {
      uint8_t a = SEAMVM_FETCH();
      uint8_t i = SEAMVM_FETCH();
      if (v->r[a & 7] == 0) SEAMVM_BRANCH(i);
      break;
    }

    case VMOP_LOOP: {
      uint8_t a = SEAMVM_FETCH();
      uint8_t i = SEAMVM_FETCH();
      v->r[a & 7] = (uint16_t)(v->r[a & 7] - 1u);
      if (v->r[a & 7] != 0) SEAMVM_BRANCH(i);
      break;
    }

    case VMOP_EMIT: {
      uint8_t a = SEAMVM_FETCH();
      v->crc = seamvm_fold(v->crc, (uint8_t)(v->r[a & 7] & 0xFFu));
      v->crc = seamvm_fold(v->crc, (uint8_t)(v->r[a & 7] >> 8));
      break;
    }

    case VMOP_MARK:
      // Folds the PC *after* the opcode byte — the address of the next byte.
      v->crc = seamvm_fold(v->crc, (uint8_t)(pc & 0xFFUL));
      v->crc = seamvm_fold(v->crc, (uint8_t)((pc >> 8) & 0xFFUL));
      v->crc = seamvm_fold(v->crc, (uint8_t)((pc >> 16) & 0xFFUL));
      break;

    case VMOP_LOAD: {
      uint8_t a = SEAMVM_FETCH();
      uint8_t d = SEAMVM_FETCH();
      // This slot's data page. `pc` is post-operands, so at the seam chapter the
      // mask lands the read on the FAR side of the device boundary — deliberately.
      unsigned long src = (pc & ~((unsigned long)SEAMDEMO_SLOT - 1UL))
                          + (unsigned long)SEAMDEMO_DATA_OFF
                          + (unsigned long)(v->r[a & 7] & 0x0FFFu);
      uint8_t b = SEAMVM_MEM8(src);
      v->r[d & 7] = b;
      v->crc = seamvm_fold(v->crc, b);
      break;
    }

    case VMOP_JFAR: {
      uint8_t lo = SEAMVM_FETCH();
      uint8_t mid = SEAMVM_FETCH();
      uint8_t hi = SEAMVM_FETCH();
      pc = ((unsigned long)hi << 16) | ((unsigned long)mid << 8) | (unsigned long)lo;
      break;
    }

    case VMOP_SYNC: {
      uint8_t i = SEAMVM_FETCH();
      v->crc = seamvm_fold(v->crc, i);
      v->yield = i;
      break;
    }

    default:
      // Not in the ISA. A decode defect that returned the wrong byte lands here,
      // which is why the bound check is kept rather than masking `op & 15`.
      v->status |= SEAMVM_ST_BAD_OPCODE;
      v->halted = 1;
      break;
  }

#undef SEAMVM_FETCH
#undef SEAMVM_BRANCH

  v->pc = pc;
}

// The act's closing fold: every register, then the turtle state. Mirrors the tail
// of run_act1() in tools/snes_seamdemo_oracle.py.
static uint16_t seamvm_final_crc(const SeamVm *v) {
  uint16_t h = v->crc;
  for (uint8_t i = 0; i < 8; i++) {
    h = seamvm_fold(h, (uint8_t)(v->r[i] & 0xFFu));
    h = seamvm_fold(h, (uint8_t)(v->r[i] >> 8));
  }
  h = seamvm_fold(h, v->x);
  h = seamvm_fold(h, v->y);
  h = seamvm_fold(h, v->heading);
  h = seamvm_fold(h, v->pen);
  return h;
}

#endif /* SEAMDEMO_VM_H */
