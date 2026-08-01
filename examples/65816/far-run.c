// #320 Increment 2 — far-pointer emulator end-to-end (minimal, emulation mode).
//
// Increment 1 proved at the DISASSEMBLY level that a far (addrspace 2) access
// lowers to 65816 absolute-long (LDA/STA $xxxxxx, AF/8F). This program proves it
// EXECUTES correctly on emulated silicon: it produces its result via a real far
// LOAD and writes it via a real far STORE, then MAME reads the byte back.
//
// Why this needs no 65816 native mode: absolute-long carries the full 24-bit
// address and ignores the data bank register, so it works in plain 6502-emulation
// mode (the state the SNES powers on in and the existing crt0 keeps it in).
//   - far_src is const -> rodata -> ROM bank $00 ($8000-$FFFF); far-loaded as
//     `lda $00xxxx`. `volatile` so the load is not constant-folded away.
//   - corpus_result is bss -> low WRAM ($0200-$1FFF, bank $00); far-stored as
//     `sta $00020C`. SNES WRAM $7E0xxx physically aliases low-RAM $000xxx, so the
//     store lands exactly where the harness samples ($7E0000 + VMA; dev/_emu.sh).
//
// Both operands are far GLOBALS and the accesses are 8-bit, so they match
// Increment 1's constant/global absolute-long path with no scalar narrowing and
// no far-pointer arithmetic (both deliberately deferred to a later increment).
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -Os far-run.c -o far-run.sfc
// Built + booted in MAME by dev/far-run.sh (host: dev/run.sh far-run).
// See docs/plans/2026-06-14-320-increment-2-far-pointer-emulator-end-to-end-mi.md.

#define FAR __attribute__((address_space(2)))

// A far constant in ROM (bank $00). volatile -> the far load actually executes.
volatile const FAR unsigned char far_src = 0xA9;

// The far store target in WRAM. The harness reads this symbol back from the $7E
// WRAM mirror; the far store writes the aliased bank-$00 byte. Expect 0xF3.
volatile FAR unsigned char corpus_result;

int main(void) {
  corpus_result = far_src ^ 0x5A;   // far load (LDA long) + far store (STA long)
  for (;;) __asm__ volatile("wai");
}
