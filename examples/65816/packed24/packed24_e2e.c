// #320 packed-24 (addrspace 3) — Increment B end-to-end: store / load / deref a
// 3-byte packed far pointer, across a real ROM bank boundary.
//
// `far_src` is forced into bank $01 (.far_rodata -> snes-far link.ld, CPU $018000),
// so a far pointer to it has bank byte $01 — NON-zero. The program:
//   1. stores that far pointer into `slot`, a *packed* (3-byte, addrspace 3) far
//      pointer in WRAM  -> addrspacecast p2->p3 + a 3-byte store (the bank byte MUST
//      survive the packing or the deref below reads the wrong bank);
//   2. reads `slot` back and casts it to a 4-byte far pointer -> a 3-byte load +
//      addrspacecast p3->p2 (zero-extend the pad byte);
//   3. dereferences it -> a far indirect-long load (`lda [dp]`) of bank $01.
// `slot` is volatile so the pack/unpack round-trip actually executes (no fold).
// Expect far_src(0xA9) ^ 0x5A == 0xF3. If the bank byte ($01) were dropped in the
// 3-byte storage, the deref would read bank $00 -> a different byte -> != 0xF3.
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os packed24_e2e.c
// Built (64 KiB) + booted in MAME and bsnes-jg by dev/packed24.sh (host: dev/run.sh packed24).
// See docs/plans/2026-06-21-320-packed24-incrementB-handoff.md.

#define FAR    __attribute__((address_space(2)))
#define PACKED __attribute__((address_space(3)))

// Far constant in ROM bank $01 (via .far_rodata -> rom_1 @ $018000). volatile -> the
// far load actually executes.
volatile const FAR unsigned char far_src
    __attribute__((section(".far_rodata"))) = 0xA9;

// The packed-24 far pointer under test: 3 bytes in WRAM. volatile so the store and
// load below are not elided / forwarded (the round-trip through memory must run).
PACKED const unsigned char *volatile slot;

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM). Expect 0xF3.
volatile FAR unsigned char corpus_result;

int main(void) {
  slot = (PACKED const unsigned char *)&far_src; // p2 -> p3, 3-byte store (bank $01)
  const FAR unsigned char *fp =
      (const FAR unsigned char *)slot;           // 3-byte load, p3 -> p2 (pad = 0)
  corpus_result = (*fp) ^ 0x5A;                  // far deref bank $01: 0xA9 ^ 0x5A = 0xF3
  for (;;) {                                     // stay alive while MAME settles
  }
}
