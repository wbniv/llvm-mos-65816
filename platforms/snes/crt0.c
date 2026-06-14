// SNES startup for the llvm-mos SNES target.
//
// The 65816 powers on in 6502-emulation mode (E=1). This crt0 switches into
// 65816 NATIVE mode (E=0) during bring-up, then falls through to the common init
// chain (soft-stack setup, .data copy, .bss clear, init_array, call main) merged
// in via CMake. Native mode is required for 16-bit accumulator/index codegen
// (#321); with M/X pinned to 8-bit it runs the existing 8-bit code generator
// identically (see docs/plans/2026-06-14-321-native-mode-crt0.md), so it is the
// default for every program rather than a per-test opt-in.

#define __SNES__
#include "snes.h"

// .init.50 — earliest fragment. Mask interrupts, force binary mode, enter native
// mode with a page-1 hardware stack and 8-bit width, and force-blank the PPU so
// the screen holds a known state during the rest of initialization.
//
// The SDK assembles this TU for the 6502 (user C defaults to the 6502 code
// generator), so the four 65816-only opcodes of the native-mode preamble are
// emitted as `.byte` — the bytes execute on the SNES 65816 (a 5A22) exactly as
// the mnemonics, and `llvm-objdump --mcpu=mosw65816` decodes them back. clc/txs
// are plain 6502, so they stay as mnemonics.
asm(".section .init.50,\"axR\",@progbits\n"
    "  sei\n"                    // mask IRQ
    "  cld\n"                    // binary mode (decimal flag is undefined at reset)
    "  clc\n"                    // clear carry, then exchange it with E:
    "  .byte 0xfb\n"             // XCE      -> E=0, 65816 native mode (M=1,X=1 kept)
    "  .byte 0xc2, 0x10\n"       // REP #$10 -> 16-bit index regs (so txs takes 16 bits)
    "  .byte 0xa2, 0xff, 0x01\n" // LDX #$01ff (16-bit immediate; 8-bit txs => SP=$00FF)
    "  txs\n"                    // hardware stack pointer -> $01FF (page 1)
    "  .byte 0xe2, 0x30\n"       // SEP #$30 -> M=1,X=1: 8-bit A+index (codegen default)
    "  lda #$00\n"
    "  sta $4200\n"              // NMITIMEN: no NMI/IRQ/auto-joypad
    "  lda #$8f\n"
    "  sta $2100\n");            // INIDISP: force blank, brightness 0

// Default interrupt handlers — weak so a program can override `nmi` / `irq`.
asm(".text\n"
    ".weak irq\n"
    "irq:\n"
    "  rti\n"
    ".weak nmi\n"
    "nmi:\n"
    "  rti\n");
