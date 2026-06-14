// #321 Increment 1a — 16-bit-accumulator REP/SEP demonstration.
//
// A 16-bit store-of-zero. Without -mattr=+mos-a16 it lowers to two 8-bit
// stores (8-bit mode). With +mos-a16, the MOSInsertREPSEP pass brackets a
// single 16-bit STZ: `rep #$20; stz g16; sep #$20` — fewer bytes, and the
// emulators (MAME + bsnes-jg) confirm the 16-bit zero round-trips. crt0 then
// writes a sentinel so the harness sees the program ran.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16.c
// See docs/plans/2026-06-14-321-increment-1-16bit-accumulator.md.

// 16-bit object the test zeroes in one 16-bit store (volatile -> not elided).
volatile unsigned short g16 = 0xBEEF;

// corpus_result: the harness reads this back. 0x0042 after g16 is zeroed.
volatile unsigned short corpus_result;

int main(void) {
  // 16-bit accumulator mode needs 65816 NATIVE mode (E=0); the SNES boots in
  // emulation mode (M/X forced 8-bit, REP ignored). Enter native mode here.
  // Test-local: main never returns (spins) and interrupts are masked (crt0 sei +
  // NMITIMEN=0), so a full native-mode crt0 isn't needed for this codegen check.
  __asm__ volatile("clc\n\txce");  // CLC; XCE -> exchange carry/emulation, E=0
  g16 = 0;                         // fused 16-bit store -> rep #$20; stz; sep #$20
  corpus_result = g16 + 0x42;      // 0x0000 + 0x42 = 0x0042 iff g16 fully zeroed
  for (;;) {
  }
}
