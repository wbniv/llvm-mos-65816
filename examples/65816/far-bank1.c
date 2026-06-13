// #320 Increment 2b — multi-bank ROM far-read (emulation mode).
//
// Increment 2 proved a far access executes in MAME, but with the far data in
// bank $00 — the same 64 KiB the 6502 already reaches. This program proves the
// thing far pointers exist for: reading data PAST 64 KiB, in a higher ROM bank.
// far_src is forced into the .far_rodata section, which the snes-far 64 KiB
// linker script (platforms/snes-far/link.ld) places in bank $01 at CPU $018000.
// The far load is therefore `lda $018000` (opcode AF, bank byte 01) — a true
// cross-bank, un-relaxable absolute-long (a non-zero bank can never zero-bank-
// relax to 16-bit). Still emulation mode: absolute-long carries the bank byte
// and ignores the DBR, so no native mode / XCE is needed.
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 -Os far-bank1.c -o far-bank1.sfc
// Built (64 KiB) + booted in MAME by dev/far-bank1.sh (host: dev/run.sh far-bank1).
// See docs/plans/2026-06-14-320-increment-2b-multi-bank-rom-far-read.md.

#define FAR __attribute__((address_space(2)))

// Far constant in ROM bank $01 (via .far_rodata -> link.ld rule -> rom_1 @ $018000).
// volatile -> the far load actually executes (not constant-folded).
volatile const FAR unsigned char far_src
    __attribute__((section(".far_rodata"))) = 0xA9;

// Far store target in WRAM (bank $00 low RAM; aliases the $7E mirror the harness
// reads). The harness samples this symbol back; expect 0xF3.
volatile FAR unsigned char corpus_result;

int main(void) {
  corpus_result = far_src ^ 0x5A;   // far LOAD from bank $01 -> far STORE to bank $00 WRAM
  for (;;) {                        // stay alive while MAME settles, then it samples
  }
}
