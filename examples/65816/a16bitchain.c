// #321 native s16 bitwise chains: a homogeneous >=3-term AND/OR/XOR chain of near-abs
// globals threads the running value through A16 (`lda a; and b; and c; sta`) with NO
// carry-init, instead of round-tripping each partial result through an Imag16 pair.
// The bitwise analogue of the add chain (Increment 1c + add_chain16_ld); covers both
// the store-rooted (bit_chain16) and multi-use-result (bit_chain16_ld) forms.
//
//   a=0x3333 b=0x5555 c=0x0F0F d=0x8080
//   oand = a & b & c        = 0x0101   (store-rooted AND chain)
//   oxor = a ^ b ^ c        = 0x6969   (store-rooted XOR chain)
//   t    = a | b | d (reused)= 0xF7F7  (multi-use OR chain)
//   corpus_result = oand + oxor + t    = 0x6261
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16bitchain.c
// See docs/plans/2026-06-15-321-native-s16-bitwise-chains.md.

volatile unsigned short a = 0x3333;
volatile unsigned short b = 0x5555;
volatile unsigned short c = 0x0F0F;
volatile unsigned short d = 0x8080;
volatile unsigned short oand, oxor, g, h;
volatile unsigned short corpus_result;

int main(void) {
  oand = a & b & c;             // store-rooted AND chain
  oxor = a ^ b ^ c;             // store-rooted XOR chain
  unsigned short t = a | b | d; // multi-use OR chain
  g = t;
  h = t;
  corpus_result = oand + oxor + t;   // 0x6261
  for (;;) {
  }
}
