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

// .init.50 — earliest fragment, runs at the reset entry. Establishes the 65816
// native-mode contract the codegen depends on, then force-blanks the PPU so the
// screen holds a known state during the rest of initialization. The contract:
//
//   E   = 0        native mode (XCE)
//   SP  = $01FF    page-1 hardware stack (16-bit txs via a transient REP #$10; an
//                  8-bit txs would set SP=$00FF and collide with the direct page)
//   M   = 1        8-bit accumulator   } SEP #$30 — the codegen default; 16-bit
//   X   = 1        8-bit index regs    } regions are bracketed by rep/sep #$20/#$10
//   DBR = 0        data bank 0: the 8-bit `abs` / R_MOS_ADDR16 global path AND the
//                  MMIO writes below read DBR:addr, and all near data lives in
//                  bank-0 low WRAM ($0200-$1FFF). Reset leaves DBR=0, but we set it
//                  EXPLICITLY (phk/plb) so the invariant is a stated contract, not
//                  a reliance on the reset default that a later DBR change (bank
//                  switch, MVN/MVP, interrupt) could silently break. The native
//                  16-bit-accumulator path uses DBR-independent `long`/R_MOS_ADDR24
//                  and is unaffected either way. See
//                  docs/plans/2026-06-18-321-native-mode-crt0-xy16.md.
//   DP  = 0        direct page at $0000 (reset default; never moved on this platform)
//
// crt0 is assembled with -mcpu=mosw65816 (set in CMakeLists.txt, independent of the
// user-facing clang.cfg default), so the 65816-only preamble is written as plain
// mnemonics. The assembler tracks the rep/sep widths, so `ldx #$01ff` encodes as a
// 16-bit immediate (a2 ff 01) — verified byte-identical to the old hand-encoded form;
// `llvm-objdump --mcpu=mosw65816` round-trips it.
asm(".section .init.50,\"axR\",@progbits\n"
    "  sei\n"                    // mask IRQ
    "  cld\n"                    // binary mode (decimal flag is undefined at reset)
    "  clc\n"                    // clear carry, then exchange it with E:
    "  xce\n"                    // E=0 -> 65816 native mode (M=1,X=1 kept)
    "  rep #$10\n"               // 16-bit index regs (so the txs below takes 16 bits)
    "  ldx #$01ff\n"             // 16-bit immediate; an 8-bit txs would set SP=$00FF
    "  txs\n"                    // hardware stack pointer -> $01FF (page 1)
    "  sep #$30\n"               // M=1,X=1: 8-bit A+index (codegen default)
    "  phk\n"                    // push program bank (=0; reset code is bank $00)
    "  plb\n"                    // DBR := 0 (explicit; abs globals + MMIO read DBR:addr)
    "  lda #$00\n"               // A = $00 for the NMITIMEN store below
    "  sta $4200\n"              // NMITIMEN: no NMI/IRQ/auto-joypad
    "  lda #$8f\n"               // A = $8F (bit 7 = force-blank, brightness 0)
    "  sta $2100\n");            // INIDISP: force blank, brightness 0

// Default interrupt handlers — weak so a program can override any of them.
//
// `brk` and `cop` are the two SYNCHRONOUS (software) 65816 interrupts. In native mode they have
// their own vectors ($FFE6 BRK, $FFE4 COP), distinct from IRQ ($FFEE). Until 2026-08-04 this
// platform wired BRK to the shared `irq` symbol (so a BRK was indistinguishable from a hardware
// IRQ) and COP to the literal address $0000 — a native-mode `cop` therefore jumped into low WRAM
// and executed data as code. Both now have their own weak `rti` stub and their own vector slot,
// so a program can override either with a real `__attribute__((interrupt))` C handler exactly the
// way it already can for `nmi` / `irq`. See docs/plans/2026-08-04-140-snes-brkcop.md.
asm(".text\n"
    ".weak irq\n"
    "irq:\n"
    "  rti\n"
    ".weak nmi\n"
    "nmi:\n"
    "  rti\n"
    ".weak brk\n"
    "brk:\n"
    "  rti\n"
    ".weak cop\n"
    "cop:\n"
    "  rti\n");
