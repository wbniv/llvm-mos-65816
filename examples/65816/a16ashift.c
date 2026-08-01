// #321 native s16 — native 16-bit signed (arithmetic) right shift (`>>` on short).
//
// Under +mos-a16 a small constant arithmetic right shift compiles to one rep/sep
// bracket with `cmp #$8000; ror a` per bit (the 65816 has no native ASR; `cmp
// #$8000` sets carry = the sign bit, `ror a` rotates it back into bit 15 so the
// sign replicates) — NOT the 8-bit lsr/ror byte chain with an ICMP_SLT sign fill.
// `x` is a multi-use signed local, so it lands in an Imag16 pair (native path).
//
//   x      = -4096  = 0xF000
//   x >> 3 = -512   = 0xFE00   (arithmetic: sign extended)
//   +1     =          0xFE01   (distinct corpus value)
//
// A broken LOGICAL >>3 would give 0x1E00 (+1 = 0x1E01); the correct 0xFE01 proves
// the sign extended through all 16 bits.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16ashift.c
// See docs/plans/2026-06-15-321-native-16bit-signed-shift-ashr.md.

volatile short sv = -4096; // 0xF000
volatile unsigned short corpus_result;

int main(void) {
  short x = sv;                          // multi-use signed local -> Imag16
  short r = x >> 3;                       // arithmetic: 0xF000 >> 3 = 0xFE00
  corpus_result = (unsigned short)r + 1;  // 0xFE01
  for (;;) __asm__ volatile("wai");
}
