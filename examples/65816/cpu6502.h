// 6502/65C02 CPU Disassembler + Simulator — #102 of the compiler stress-test demo battery.
//
// Simulates the 6502/65C02 (8-bit A/X/Y, 16-bit PC) executing a small embedded "hello"
// program — the 6502 assembly equivalent of examples/snes/hello.c: sets a simulated color
// register to green (SNES_RGB(0,31,0) = 0x03E0), stores the sentinel 0x42, then loops
// exercising every ALU gate type (ADD/AND/XOR/OR/SHL/SHR/CMP/SUB).
//
// Codegen under test: 256-entry switch dispatch (jump table), uint16_t PC arithmetic,
// uint8_t flag bit-manipulation, and indexed array reads into mem[].
//
// Gate CRC folds A, X, PC, P after each of 256 steps (deterministic — the program loops).
//
// Differential safety: all arithmetic uses uint8_t/uint16_t; no signed integer overflow;
// widths explicitly cast so host int=32 and 65816 int=16 both produce identical bit patterns.
// See docs/plans/2026-07-02-102-snes-cpu6502.md.
#ifndef CPU6502_H
#define CPU6502_H

#include <stdint.h>
#include <string.h>

// ── Addressing modes ──────────────────────────────────────────────────────────
#define AM_IMP  0   // implied / accumulator
#define AM_IMM  1   // immediate:  #imm
#define AM_ZP   2   // zero-page:  zp
#define AM_ZPX  3   // zero-page X: zp,X
#define AM_ZPY  4   // zero-page Y: zp,Y
#define AM_ABS  5   // absolute:   abs
#define AM_ABX  6   // absolute X: abs,X
#define AM_ABY  7   // absolute Y: abs,Y
#define AM_IND  8   // indirect:   (abs)  — JMP only
#define AM_IZX  9   // indexed indirect: (zp,X)
#define AM_IZY  10  // indirect indexed: (zp),Y
#define AM_REL  11  // relative (branches)
#define AM_IZP  12  // zero-page indirect: (zp) — 65C02 only

// ── Gate types ────────────────────────────────────────────────────────────────
typedef enum {
    GATE_NONE = 0,
    GATE_AND,
    GATE_OR,
    GATE_XOR,
    GATE_ADD,
    GATE_SUB,
    GATE_SHL,
    GATE_SHR,
    GATE_CMP
} GateType;

// ── Opcode descriptor ─────────────────────────────────────────────────────────
typedef struct {
    char     mnem[4];   // 3-char mnemonic + NUL ("???" for illegal)
    uint8_t  am;        // addressing mode
    uint8_t  len;       // instruction length in bytes (1–3)
    GateType gate;      // ALU gate activated
} OpcodeInfo;

// ── CPU state ─────────────────────────────────────────────────────────────────
typedef struct {
    uint8_t  a, x, y, sp, p;
    uint16_t pc;
    uint8_t  mem[256];  // 256-byte simulated address space
} CPU6502;

// Flags in P
#define FLAG_C 0x01u
#define FLAG_Z 0x02u
#define FLAG_I 0x04u
#define FLAG_D 0x08u
#define FLAG_B 0x10u
#define FLAG_V 0x40u
#define FLAG_N 0x80u

// ── Opcode table (256 entries: 6502 + 65C02 extras) ──────────────────────────
// The large switch in cpu6502_step maps these; this table supports the disassembler.
static const OpcodeInfo CPU6502_OPS[256] = {
    /* 00 */ {"BRK",AM_IMP,1,GATE_NONE}, {"ORA",AM_IZX,2,GATE_OR  },
    /* 02 */ {"???",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* 04 */ {"TSB",AM_ZP, 2,GATE_NONE}, {"ORA",AM_ZP, 2,GATE_OR  }, // 04: 65C02
    /* 06 */ {"ASL",AM_ZP, 2,GATE_SHL }, {"???",AM_IMP,1,GATE_NONE},
    /* 08 */ {"PHP",AM_IMP,1,GATE_NONE}, {"ORA",AM_IMM,2,GATE_OR  },
    /* 0A */ {"ASL",AM_IMP,1,GATE_SHL }, {"???",AM_IMP,1,GATE_NONE},
    /* 0C */ {"TSB",AM_ABS,3,GATE_NONE}, {"ORA",AM_ABS,3,GATE_OR  }, // 0C: 65C02
    /* 0E */ {"ASL",AM_ABS,3,GATE_SHL }, {"???",AM_IMP,1,GATE_NONE},
    /* 10 */ {"BPL",AM_REL,2,GATE_NONE}, {"ORA",AM_IZY,2,GATE_OR  },
    /* 12 */ {"ORA",AM_IZP,2,GATE_OR  }, {"???",AM_IMP,1,GATE_NONE}, // 12: 65C02
    /* 14 */ {"TRB",AM_ZP, 2,GATE_NONE}, {"ORA",AM_ZPX,2,GATE_OR  }, // 14: 65C02
    /* 16 */ {"ASL",AM_ZPX,2,GATE_SHL }, {"???",AM_IMP,1,GATE_NONE},
    /* 18 */ {"CLC",AM_IMP,1,GATE_NONE}, {"ORA",AM_ABY,3,GATE_OR  },
    /* 1A */ {"INC",AM_IMP,1,GATE_ADD }, {"???",AM_IMP,1,GATE_NONE}, // 1A: 65C02
    /* 1C */ {"TRB",AM_ABS,3,GATE_NONE}, {"ORA",AM_ABX,3,GATE_OR  }, // 1C: 65C02
    /* 1E */ {"ASL",AM_ABX,3,GATE_SHL }, {"???",AM_IMP,1,GATE_NONE},
    /* 20 */ {"JSR",AM_ABS,3,GATE_NONE}, {"AND",AM_IZX,2,GATE_AND },
    /* 22 */ {"???",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* 24 */ {"BIT",AM_ZP, 2,GATE_AND }, {"AND",AM_ZP, 2,GATE_AND },
    /* 26 */ {"ROL",AM_ZP, 2,GATE_SHL }, {"???",AM_IMP,1,GATE_NONE},
    /* 28 */ {"PLP",AM_IMP,1,GATE_NONE}, {"AND",AM_IMM,2,GATE_AND },
    /* 2A */ {"ROL",AM_IMP,1,GATE_SHL }, {"???",AM_IMP,1,GATE_NONE},
    /* 2C */ {"BIT",AM_ABS,3,GATE_AND }, {"AND",AM_ABS,3,GATE_AND },
    /* 2E */ {"ROL",AM_ABS,3,GATE_SHL }, {"???",AM_IMP,1,GATE_NONE},
    /* 30 */ {"BMI",AM_REL,2,GATE_NONE}, {"AND",AM_IZY,2,GATE_AND },
    /* 32 */ {"AND",AM_IZP,2,GATE_AND }, {"???",AM_IMP,1,GATE_NONE}, // 32: 65C02
    /* 34 */ {"BIT",AM_ZPX,2,GATE_AND }, {"AND",AM_ZPX,2,GATE_AND }, // 34: 65C02
    /* 36 */ {"ROL",AM_ZPX,2,GATE_SHL }, {"???",AM_IMP,1,GATE_NONE},
    /* 38 */ {"SEC",AM_IMP,1,GATE_NONE}, {"AND",AM_ABY,3,GATE_AND },
    /* 3A */ {"DEC",AM_IMP,1,GATE_SUB }, {"???",AM_IMP,1,GATE_NONE}, // 3A: 65C02
    /* 3C */ {"BIT",AM_ABX,3,GATE_AND }, {"AND",AM_ABX,3,GATE_AND }, // 3C: 65C02
    /* 3E */ {"ROL",AM_ABX,3,GATE_SHL }, {"???",AM_IMP,1,GATE_NONE},
    /* 40 */ {"RTI",AM_IMP,1,GATE_NONE}, {"EOR",AM_IZX,2,GATE_XOR },
    /* 42 */ {"???",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* 44 */ {"???",AM_IMP,1,GATE_NONE}, {"EOR",AM_ZP, 2,GATE_XOR },
    /* 46 */ {"LSR",AM_ZP, 2,GATE_SHR }, {"???",AM_IMP,1,GATE_NONE},
    /* 48 */ {"PHA",AM_IMP,1,GATE_NONE}, {"EOR",AM_IMM,2,GATE_XOR },
    /* 4A */ {"LSR",AM_IMP,1,GATE_SHR }, {"???",AM_IMP,1,GATE_NONE},
    /* 4C */ {"JMP",AM_ABS,3,GATE_NONE}, {"EOR",AM_ABS,3,GATE_XOR },
    /* 4E */ {"LSR",AM_ABS,3,GATE_SHR }, {"???",AM_IMP,1,GATE_NONE},
    /* 50 */ {"BVC",AM_REL,2,GATE_NONE}, {"EOR",AM_IZY,2,GATE_XOR },
    /* 52 */ {"EOR",AM_IZP,2,GATE_XOR }, {"???",AM_IMP,1,GATE_NONE}, // 52: 65C02
    /* 54 */ {"???",AM_IMP,1,GATE_NONE}, {"EOR",AM_ZPX,2,GATE_XOR },
    /* 56 */ {"LSR",AM_ZPX,2,GATE_SHR }, {"???",AM_IMP,1,GATE_NONE},
    /* 58 */ {"CLI",AM_IMP,1,GATE_NONE}, {"EOR",AM_ABY,3,GATE_XOR },
    /* 5A */ {"PHY",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE}, // 5A: 65C02
    /* 5C */ {"???",AM_IMP,1,GATE_NONE}, {"EOR",AM_ABX,3,GATE_XOR },
    /* 5E */ {"LSR",AM_ABX,3,GATE_SHR }, {"???",AM_IMP,1,GATE_NONE},
    /* 60 */ {"RTS",AM_IMP,1,GATE_NONE}, {"ADC",AM_IZX,2,GATE_ADD },
    /* 62 */ {"???",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* 64 */ {"STZ",AM_ZP, 2,GATE_NONE}, {"ADC",AM_ZP, 2,GATE_ADD }, // 64: 65C02
    /* 66 */ {"ROR",AM_ZP, 2,GATE_SHR }, {"???",AM_IMP,1,GATE_NONE},
    /* 68 */ {"PLA",AM_IMP,1,GATE_NONE}, {"ADC",AM_IMM,2,GATE_ADD },
    /* 6A */ {"ROR",AM_IMP,1,GATE_SHR }, {"???",AM_IMP,1,GATE_NONE},
    /* 6C */ {"JMP",AM_IND,3,GATE_NONE}, {"ADC",AM_ABS,3,GATE_ADD },
    /* 6E */ {"ROR",AM_ABS,3,GATE_SHR }, {"???",AM_IMP,1,GATE_NONE},
    /* 70 */ {"BVS",AM_REL,2,GATE_NONE}, {"ADC",AM_IZY,2,GATE_ADD },
    /* 72 */ {"ADC",AM_IZP,2,GATE_ADD }, {"???",AM_IMP,1,GATE_NONE}, // 72: 65C02
    /* 74 */ {"STZ",AM_ZPX,2,GATE_NONE}, {"ADC",AM_ZPX,2,GATE_ADD }, // 74: 65C02
    /* 76 */ {"ROR",AM_ZPX,2,GATE_SHR }, {"???",AM_IMP,1,GATE_NONE},
    /* 78 */ {"SEI",AM_IMP,1,GATE_NONE}, {"ADC",AM_ABY,3,GATE_ADD },
    /* 7A */ {"PLY",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE}, // 7A: 65C02
    /* 7C */ {"JMP",AM_ABX,3,GATE_NONE}, {"ADC",AM_ABX,3,GATE_ADD }, // 7C: 65C02
    /* 7E */ {"ROR",AM_ABX,3,GATE_SHR }, {"???",AM_IMP,1,GATE_NONE},
    /* 80 */ {"BRA",AM_REL,2,GATE_NONE}, {"STA",AM_IZX,2,GATE_NONE}, // 80: 65C02
    /* 82 */ {"???",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* 84 */ {"STY",AM_ZP, 2,GATE_NONE}, {"STA",AM_ZP, 2,GATE_NONE},
    /* 86 */ {"STX",AM_ZP, 2,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* 88 */ {"DEY",AM_IMP,1,GATE_SUB }, {"BIT",AM_IMM,2,GATE_AND }, // 89: 65C02
    /* 8A */ {"TXA",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* 8C */ {"STY",AM_ABS,3,GATE_NONE}, {"STA",AM_ABS,3,GATE_NONE},
    /* 8E */ {"STX",AM_ABS,3,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* 90 */ {"BCC",AM_REL,2,GATE_NONE}, {"STA",AM_IZY,2,GATE_NONE},
    /* 92 */ {"STA",AM_IZP,2,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE}, // 92: 65C02
    /* 94 */ {"STY",AM_ZPX,2,GATE_NONE}, {"STA",AM_ZPX,2,GATE_NONE},
    /* 96 */ {"STX",AM_ZPY,2,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* 98 */ {"TYA",AM_IMP,1,GATE_NONE}, {"STA",AM_ABY,3,GATE_NONE},
    /* 9A */ {"TXS",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* 9C */ {"STZ",AM_ABS,3,GATE_NONE}, {"STA",AM_ABX,3,GATE_NONE}, // 9C: 65C02
    /* 9E */ {"STZ",AM_ABX,3,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE}, // 9E: 65C02
    /* A0 */ {"LDY",AM_IMM,2,GATE_NONE}, {"LDA",AM_IZX,2,GATE_NONE},
    /* A2 */ {"LDX",AM_IMM,2,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* A4 */ {"LDY",AM_ZP, 2,GATE_NONE}, {"LDA",AM_ZP, 2,GATE_NONE},
    /* A6 */ {"LDX",AM_ZP, 2,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* A8 */ {"TAY",AM_IMP,1,GATE_NONE}, {"LDA",AM_IMM,2,GATE_NONE},
    /* AA */ {"TAX",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* AC */ {"LDY",AM_ABS,3,GATE_NONE}, {"LDA",AM_ABS,3,GATE_NONE},
    /* AE */ {"LDX",AM_ABS,3,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* B0 */ {"BCS",AM_REL,2,GATE_NONE}, {"LDA",AM_IZY,2,GATE_NONE},
    /* B2 */ {"LDA",AM_IZP,2,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE}, // B2: 65C02
    /* B4 */ {"LDY",AM_ZPX,2,GATE_NONE}, {"LDA",AM_ZPX,2,GATE_NONE},
    /* B6 */ {"LDX",AM_ZPY,2,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* B8 */ {"CLV",AM_IMP,1,GATE_NONE}, {"LDA",AM_ABY,3,GATE_NONE},
    /* BA */ {"TSX",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* BC */ {"LDY",AM_ABX,3,GATE_NONE}, {"LDA",AM_ABX,3,GATE_NONE},
    /* BE */ {"LDX",AM_ABY,3,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* C0 */ {"CPY",AM_IMM,2,GATE_CMP }, {"CMP",AM_IZX,2,GATE_CMP },
    /* C2 */ {"???",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* C4 */ {"CPY",AM_ZP, 2,GATE_CMP }, {"CMP",AM_ZP, 2,GATE_CMP },
    /* C6 */ {"DEC",AM_ZP, 2,GATE_SUB }, {"???",AM_IMP,1,GATE_NONE},
    /* C8 */ {"INY",AM_IMP,1,GATE_ADD }, {"CMP",AM_IMM,2,GATE_CMP },
    /* CA */ {"DEX",AM_IMP,1,GATE_SUB }, {"???",AM_IMP,1,GATE_NONE},
    /* CC */ {"CPY",AM_ABS,3,GATE_CMP }, {"CMP",AM_ABS,3,GATE_CMP },
    /* CE */ {"DEC",AM_ABS,3,GATE_SUB }, {"???",AM_IMP,1,GATE_NONE},
    /* D0 */ {"BNE",AM_REL,2,GATE_NONE}, {"CMP",AM_IZY,2,GATE_CMP },
    /* D2 */ {"CMP",AM_IZP,2,GATE_CMP }, {"???",AM_IMP,1,GATE_NONE}, // D2: 65C02
    /* D4 */ {"???",AM_IMP,1,GATE_NONE}, {"CMP",AM_ZPX,2,GATE_CMP },
    /* D6 */ {"DEC",AM_ZPX,2,GATE_SUB }, {"???",AM_IMP,1,GATE_NONE},
    /* D8 */ {"CLD",AM_IMP,1,GATE_NONE}, {"CMP",AM_ABY,3,GATE_CMP },
    /* DA */ {"PHX",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE}, // DA: 65C02
    /* DC */ {"???",AM_IMP,1,GATE_NONE}, {"CMP",AM_ABX,3,GATE_CMP },
    /* DE */ {"DEC",AM_ABX,3,GATE_SUB }, {"???",AM_IMP,1,GATE_NONE},
    /* E0 */ {"CPX",AM_IMM,2,GATE_CMP }, {"SBC",AM_IZX,2,GATE_SUB },
    /* E2 */ {"???",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* E4 */ {"CPX",AM_ZP, 2,GATE_CMP }, {"SBC",AM_ZP, 2,GATE_SUB },
    /* E6 */ {"INC",AM_ZP, 2,GATE_ADD }, {"???",AM_IMP,1,GATE_NONE},
    /* E8 */ {"INX",AM_IMP,1,GATE_ADD }, {"SBC",AM_IMM,2,GATE_SUB },
    /* EA */ {"NOP",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE},
    /* EC */ {"CPX",AM_ABS,3,GATE_CMP }, {"SBC",AM_ABS,3,GATE_SUB },
    /* EE */ {"INC",AM_ABS,3,GATE_ADD }, {"???",AM_IMP,1,GATE_NONE},
    /* F0 */ {"BEQ",AM_REL,2,GATE_NONE}, {"SBC",AM_IZY,2,GATE_SUB },
    /* F2 */ {"SBC",AM_IZP,2,GATE_SUB }, {"???",AM_IMP,1,GATE_NONE}, // F2: 65C02
    /* F4 */ {"???",AM_IMP,1,GATE_NONE}, {"SBC",AM_ZPX,2,GATE_SUB },
    /* F6 */ {"INC",AM_ZPX,2,GATE_ADD }, {"???",AM_IMP,1,GATE_NONE},
    /* F8 */ {"SED",AM_IMP,1,GATE_NONE}, {"SBC",AM_ABY,3,GATE_SUB },
    /* FA */ {"PLX",AM_IMP,1,GATE_NONE}, {"???",AM_IMP,1,GATE_NONE}, // FA: 65C02
    /* FC */ {"???",AM_IMP,1,GATE_NONE}, {"SBC",AM_ABX,3,GATE_SUB },
    /* FE */ {"INC",AM_ABX,3,GATE_ADD }, {"???",AM_IMP,1,GATE_NONE},
};

// ── Embedded "hello.c" program in 6502 assembly ───────────────────────────────
// Mirrors hello.c: write green to "color register", write sentinel 0x42, loop.
// SNES_RGB(0,31,0) = 0x03E0 → low=0xE0, high=0x03.
// Then exercises every ALU gate type before repeating.
//
// Addr  Bytes         Mnemonic     Gate
// 0000: A9 E0         LDA #$E0     NONE  (green low)
// 0002: 85 F0         STA $F0      NONE  (color lo reg)
// 0004: A9 03         LDA #$03     NONE  (green high)
// 0006: 85 F1         STA $F1      NONE  (color hi reg)
// 0008: A9 42         LDA #$42     NONE  (sentinel value)
// 000A: 85 FF         STA $FF      NONE  (write sentinel — "sentinel = 0x42")
// 000C: A2 08         LDX #$08     NONE  (loop counter)
// 000E: 18            CLC          NONE
// 000F: 69 01         ADC #$01     ADD
// 0011: 25 FF         AND $FF      AND
// 0013: 45 FF         EOR $FF      XOR
// 0015: 05 FF         ORA $FF      OR
// 0017: 0A            ASL          SHL
// 0018: 4A            LSR          SHR
// 0019: C5 FF         CMP $FF      CMP
// 001B: CA            DEX          SUB
// 001C: D0 F0         BNE $000E    NONE  (loop 8 times)
// 001E: 4C 08 00      JMP $0008    NONE  (restart: re-write sentinel)
static const uint8_t HELLO6502[33] = {
    0xA9, 0xE0,        // $00: LDA #$E0   — green low
    0x85, 0xF0,        // $02: STA $F0
    0xA9, 0x03,        // $04: LDA #$03   — green high
    0x85, 0xF1,        // $06: STA $F1
    0xA9, 0x42,        // $08: LDA #$42   — sentinel (hello.c: "sentinel = 0x42")
    0x85, 0xFF,        // $0A: STA $FF
    0xA2, 0x08,        // $0C: LDX #$08   — loop count
    0x18,              // $0E: CLC
    0x69, 0x01,        // $0F: ADC #$01   [ADD]
    0x25, 0xFF,        // $11: AND $FF     [AND]
    0x45, 0xFF,        // $13: EOR $FF     [XOR]
    0x05, 0xFF,        // $15: ORA $FF     [OR]
    0x0A,              // $17: ASL         [SHL]
    0x4A,              // $18: LSR         [SHR]
    0xC5, 0xFF,        // $19: CMP $FF     [CMP]
    0xCA,              // $1B: DEX         [SUB]
    0xD0, 0xF0,        // $1C: BNE $000E   (offset -16 from $1E)
    0x4C, 0x08, 0x00,  // $1E: JMP $0008
};

// ── cpu6502_init ──────────────────────────────────────────────────────────────
static void cpu6502_init(CPU6502 *c) {
    uint8_t i;
    for (i = 0; i < 255u; i++) c->mem[i] = 0;
    c->mem[255] = 0;
    for (i = 0; i < (uint8_t)sizeof(HELLO6502); i++)
        c->mem[i] = HELLO6502[i];
    c->a = 0; c->x = 0; c->y = 0;
    c->sp = 0xFFu; c->p = 0x20u; c->pc = 0;
}

// ── Flag helpers ──────────────────────────────────────────────────────────────
static inline void set_nz(CPU6502 *c, uint8_t v) {
    c->p = (uint8_t)((c->p & (uint8_t)~(FLAG_N | FLAG_Z))
                     | (uint8_t)(v & FLAG_N)
                     | (uint8_t)(v ? 0u : FLAG_Z));
}

static inline uint8_t zp_read(const CPU6502 *c, uint8_t addr) {
    return c->mem[addr];
}
static inline void zp_write(CPU6502 *c, uint8_t addr, uint8_t val) {
    c->mem[addr] = val;
}

// ── cpu6502_step ──────────────────────────────────────────────────────────────
// Execute one instruction; return the gate type fired.
// Only implements the opcodes present in the hello program plus a few extras;
// everything else advances PC by len and returns GATE_NONE.
__attribute__((noinline))
static GateType cpu6502_step(CPU6502 *c) {
    uint8_t op = c->mem[(uint8_t)c->pc];
    GateType g = CPU6502_OPS[op].gate;
    uint8_t len = CPU6502_OPS[op].len;
    uint8_t arg = (len > 1u) ? c->mem[(uint8_t)((uint8_t)c->pc + 1u)] : 0u;
    uint16_t tmp16;
    uint8_t  tmp8;

    switch (op) {
    // ── Load / Store ──────────────────────────────────────────────────────
    case 0xA9: c->a = arg; set_nz(c, c->a); break;            // LDA imm
    case 0xA2: c->x = arg; set_nz(c, c->x); break;            // LDX imm
    case 0xA0: c->y = arg; set_nz(c, c->y); break;            // LDY imm
    case 0xA5: c->a = zp_read(c,arg); set_nz(c,c->a); break;  // LDA zp
    case 0x85: zp_write(c, arg, c->a); break;                  // STA zp
    case 0x86: zp_write(c, arg, c->x); break;                  // STX zp
    case 0x84: zp_write(c, arg, c->y); break;                  // STY zp
    case 0xAA: c->x = c->a; set_nz(c, c->x); break;           // TAX
    case 0xA8: c->y = c->a; set_nz(c, c->y); break;           // TAY
    case 0x8A: c->a = c->x; set_nz(c, c->a); break;           // TXA
    case 0x98: c->a = c->y; set_nz(c, c->a); break;           // TYA
    // ── Arithmetic ───────────────────────────────────────────────────────
    case 0x69: // ADC imm
        tmp16 = (uint16_t)c->a + (uint16_t)arg + (uint16_t)(c->p & FLAG_C);
        c->p = (uint8_t)(c->p & (uint8_t)~(FLAG_C|FLAG_Z|FLAG_N|FLAG_V));
        if (tmp16 > 0xFFu) c->p |= FLAG_C;
        if (!((uint8_t)tmp16)) c->p |= FLAG_Z;
        if ((uint8_t)tmp16 & 0x80u) c->p |= FLAG_N;
        if (~(c->a ^ arg) & ((uint8_t)tmp16 ^ c->a) & 0x80u) c->p |= FLAG_V;
        c->a = (uint8_t)tmp16;
        break;
    case 0x65: // ADC zp
        tmp8 = zp_read(c,arg);
        tmp16 = (uint16_t)c->a + (uint16_t)tmp8 + (uint16_t)(c->p & FLAG_C);
        c->p = (uint8_t)(c->p & (uint8_t)~(FLAG_C|FLAG_Z|FLAG_N|FLAG_V));
        if (tmp16 > 0xFFu) c->p |= FLAG_C;
        if (!((uint8_t)tmp16)) c->p |= FLAG_Z;
        if ((uint8_t)tmp16 & 0x80u) c->p |= FLAG_N;
        if (~(c->a ^ tmp8) & ((uint8_t)tmp16 ^ c->a) & 0x80u) c->p |= FLAG_V;
        c->a = (uint8_t)tmp16;
        break;
    case 0xE8: c->x = (uint8_t)(c->x + 1u); set_nz(c, c->x); break; // INX
    case 0xC8: c->y = (uint8_t)(c->y + 1u); set_nz(c, c->y); break; // INY
    case 0xCA: c->x = (uint8_t)(c->x - 1u); set_nz(c, c->x); break; // DEX
    case 0x88: c->y = (uint8_t)(c->y - 1u); set_nz(c, c->y); break; // DEY
    // ── Logic ────────────────────────────────────────────────────────────
    case 0x29: c->a = (uint8_t)(c->a & arg); set_nz(c, c->a); break; // AND imm
    case 0x25: c->a = (uint8_t)(c->a & zp_read(c,arg)); set_nz(c,c->a); break; // AND zp
    case 0x09: c->a = (uint8_t)(c->a | arg); set_nz(c, c->a); break; // ORA imm
    case 0x05: c->a = (uint8_t)(c->a | zp_read(c,arg)); set_nz(c,c->a); break; // ORA zp
    case 0x49: c->a = (uint8_t)(c->a ^ arg); set_nz(c, c->a); break; // EOR imm
    case 0x45: c->a = (uint8_t)(c->a ^ zp_read(c,arg)); set_nz(c,c->a); break; // EOR zp
    // ── Shifts ───────────────────────────────────────────────────────────
    case 0x0A: // ASL A
        c->p = (uint8_t)((c->p & (uint8_t)~FLAG_C) | (uint8_t)((c->a >> 7u) ? FLAG_C : 0u));
        c->a = (uint8_t)(c->a << 1u); set_nz(c, c->a);
        break;
    case 0x4A: // LSR A
        c->p = (uint8_t)((c->p & (uint8_t)~FLAG_C) | (uint8_t)(c->a & FLAG_C));
        c->a = (uint8_t)(c->a >> 1u); set_nz(c, c->a);
        break;
    case 0x2A: // ROL A
        tmp8 = (uint8_t)((c->a << 1u) | (uint8_t)(c->p & FLAG_C));
        c->p = (uint8_t)((c->p & (uint8_t)~FLAG_C) | (uint8_t)((c->a >> 7u) ? FLAG_C : 0u));
        c->a = tmp8; set_nz(c, c->a);
        break;
    case 0x6A: // ROR A
        tmp8 = (uint8_t)((c->a >> 1u) | (uint8_t)((c->p & FLAG_C) << 7u));
        c->p = (uint8_t)((c->p & (uint8_t)~FLAG_C) | (uint8_t)(c->a & FLAG_C));
        c->a = tmp8; set_nz(c, c->a);
        break;
    // ── Compare ──────────────────────────────────────────────────────────
    case 0xC9: // CMP imm
        tmp16 = (uint16_t)c->a - (uint16_t)arg;
        c->p = (uint8_t)(c->p & (uint8_t)~(FLAG_C|FLAG_Z|FLAG_N));
        if (c->a >= arg) c->p |= FLAG_C;
        if (!(tmp16 & 0xFFu)) c->p |= FLAG_Z;
        if ((uint8_t)tmp16 & 0x80u) c->p |= FLAG_N;
        break;
    case 0xC5: // CMP zp
        tmp8 = zp_read(c, arg);
        tmp16 = (uint16_t)c->a - (uint16_t)tmp8;
        c->p = (uint8_t)(c->p & (uint8_t)~(FLAG_C|FLAG_Z|FLAG_N));
        if (c->a >= tmp8) c->p |= FLAG_C;
        if (!(tmp16 & 0xFFu)) c->p |= FLAG_Z;
        if ((uint8_t)tmp16 & 0x80u) c->p |= FLAG_N;
        break;
    case 0xE0: // CPX imm
        tmp16 = (uint16_t)c->x - (uint16_t)arg;
        c->p = (uint8_t)(c->p & (uint8_t)~(FLAG_C|FLAG_Z|FLAG_N));
        if (c->x >= arg) c->p |= FLAG_C;
        if (!(tmp16 & 0xFFu)) c->p |= FLAG_Z;
        if ((uint8_t)tmp16 & 0x80u) c->p |= FLAG_N;
        break;
    case 0xC0: // CPY imm
        tmp16 = (uint16_t)c->y - (uint16_t)arg;
        c->p = (uint8_t)(c->p & (uint8_t)~(FLAG_C|FLAG_Z|FLAG_N));
        if (c->y >= arg) c->p |= FLAG_C;
        if (!(tmp16 & 0xFFu)) c->p |= FLAG_Z;
        if ((uint8_t)tmp16 & 0x80u) c->p |= FLAG_N;
        break;
    // ── Branches ─────────────────────────────────────────────────────────
    case 0xD0: // BNE
        c->pc = (uint16_t)(c->pc + (uint16_t)len);
        if (!(c->p & FLAG_Z)) {
            int8_t off = (int8_t)arg;
            c->pc = (uint16_t)((int16_t)c->pc + (int16_t)off);
        }
        return g;
    case 0xF0: // BEQ
        c->pc = (uint16_t)(c->pc + (uint16_t)len);
        if (c->p & FLAG_Z) {
            int8_t off = (int8_t)arg;
            c->pc = (uint16_t)((int16_t)c->pc + (int16_t)off);
        }
        return g;
    case 0x90: // BCC
        c->pc = (uint16_t)(c->pc + (uint16_t)len);
        if (!(c->p & FLAG_C)) {
            int8_t off = (int8_t)arg;
            c->pc = (uint16_t)((int16_t)c->pc + (int16_t)off);
        }
        return g;
    case 0xB0: // BCS
        c->pc = (uint16_t)(c->pc + (uint16_t)len);
        if (c->p & FLAG_C) {
            int8_t off = (int8_t)arg;
            c->pc = (uint16_t)((int16_t)c->pc + (int16_t)off);
        }
        return g;
    case 0x30: // BMI
        c->pc = (uint16_t)(c->pc + (uint16_t)len);
        if (c->p & FLAG_N) {
            int8_t off = (int8_t)arg;
            c->pc = (uint16_t)((int16_t)c->pc + (int16_t)off);
        }
        return g;
    case 0x10: // BPL
        c->pc = (uint16_t)(c->pc + (uint16_t)len);
        if (!(c->p & FLAG_N)) {
            int8_t off = (int8_t)arg;
            c->pc = (uint16_t)((int16_t)c->pc + (int16_t)off);
        }
        return g;
    case 0x80: // BRA (65C02)
    {
        int8_t off = (int8_t)arg;
        c->pc = (uint16_t)(c->pc + (uint16_t)len);
        c->pc = (uint16_t)((int16_t)c->pc + (int16_t)off);
        return g;
    }
    // ── Jumps ────────────────────────────────────────────────────────────
    case 0x4C: { // JMP abs
        uint8_t lo = c->mem[(uint8_t)((uint8_t)c->pc + 1u)];
        uint8_t hi = c->mem[(uint8_t)((uint8_t)c->pc + 2u)];
        c->pc = (uint16_t)((uint16_t)hi << 8u) | (uint16_t)lo;
        return g;
    }
    // ── Flag ops ─────────────────────────────────────────────────────────
    case 0x18: c->p = (uint8_t)(c->p & (uint8_t)~FLAG_C); break; // CLC
    case 0x38: c->p = (uint8_t)(c->p |  FLAG_C); break;           // SEC
    case 0x58: c->p = (uint8_t)(c->p & (uint8_t)~FLAG_I); break;  // CLI
    case 0x78: c->p = (uint8_t)(c->p |  FLAG_I); break;           // SEI
    case 0xD8: c->p = (uint8_t)(c->p & (uint8_t)~FLAG_D); break;  // CLD
    case 0xF8: c->p = (uint8_t)(c->p |  FLAG_D); break;           // SED
    case 0xB8: c->p = (uint8_t)(c->p & (uint8_t)~FLAG_V); break;  // CLV
    case 0xEA: break;                                               // NOP
    default:   break;                                               // all others: advance PC only
    }
    c->pc = (uint16_t)(c->pc + (uint16_t)len);
    return g;
}

// ── cpu6502_gate_crc ──────────────────────────────────────────────────────────
// Run 256 steps; fold A, X, PC, P each step into a rotating XOR CRC.
// Deterministic: the hello program loops, covering all gate types repeatedly.
// Width discipline: all arithmetic in uint8_t/uint16_t so int=16 and int=32 agree.
static inline uint16_t cpu6502_fold(uint16_t h, uint16_t x) {
    return (uint16_t)(((uint16_t)(h << 1u) | (uint16_t)(h >> 15u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 256u
#endif

static uint16_t cpu6502_gate_crc(void) {
    CPU6502 cpu;
    cpu6502_init(&cpu);
    uint16_t h = 0;
    uint16_t i;
    for (i = 0; i < (uint16_t)GATE_N; i++) {
        cpu6502_step(&cpu);
        h = cpu6502_fold(h, (uint16_t)((uint16_t)cpu.a | ((uint16_t)cpu.x << 8u)));
        h = cpu6502_fold(h, cpu.pc);
        h = cpu6502_fold(h, (uint16_t)cpu.p);
    }
    return h;
}

#endif /* CPU6502_H */
