// SNES startup for the llvm-mos SNES target (M0).
//
// The 65816 powers on in 6502-emulation mode (E=1), so the existing mos 6502
// code generator runs directly. This crt0 does the minimum bring-up, then falls
// through to the common init chain (soft-stack setup, .data copy, .bss clear,
// init_array, call main) merged in via CMake.

#define __SNES__
#include "snes.h"

// .init.50 — earliest fragment. Mask interrupts, force binary mode, set the
// hardware stack to $01FF, and force-blank the PPU so the screen holds a known
// state during the rest of initialization.
asm(".section .init.50,\"axR\",@progbits\n"
    "  sei\n"            // mask IRQ
    "  cld\n"            // binary mode (decimal flag is undefined at reset)
    "  ldx #$ff\n"
    "  txs\n"            // hardware stack pointer -> $01FF (emulation mode)
    "  lda #$00\n"
    "  sta $4200\n"      // NMITIMEN: no NMI/IRQ/auto-joypad
    "  lda #$8f\n"
    "  sta $2100\n");    // INIDISP: force blank, brightness 0

// Default interrupt handlers — weak so a program can override `nmi` / `irq`.
asm(".text\n"
    ".weak irq\n"
    "irq:\n"
    "  rti\n"
    ".weak nmi\n"
    "nmi:\n"
    "  rti\n");
