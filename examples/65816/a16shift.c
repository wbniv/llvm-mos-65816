// #321 native s16 — native 16-bit constant shifts (`<<`, unsigned `>>`).
//
// Under +mos-a16 a small constant s16 shift compiles to one rep/sep bracket with
// single-byte 16-bit accumulator shifts (`lda; asl/lsr ×k; sta`) instead of the
// 8-bit asl/rol (or lsr/ror) byte-pair chain. `x` is a multi-use local, so it
// lands in an Imag16 zero-page pair and goes through the native selectShift16Native
// path (the all-global store peephole can't reach a shift).
//
//   x      = 0x0123
//   x << 4 = 0x1230   (bits move up across the byte boundary — proves 16-bit shift)
//   x >> 2 = 0x0048   (the high byte feeds the low byte — proves 16-bit shift)
//   sum    = 0x1230 + 0x0048 = 0x1278
//
// A broken 8-bit-only shift would mishandle the byte boundary and read wrong.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16shift.c
// See docs/plans/2026-06-15-321-native-16bit-constant-shifts.md.

volatile unsigned short v = 0x0123;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short x = v;        // multi-use local -> Imag16 (native shift path)
  unsigned short l = x << 4;   // 0x1230
  unsigned short r = x >> 2;   // 0x0048
  corpus_result = l + r;       // 0x1278
  for (;;) {
  }
}
