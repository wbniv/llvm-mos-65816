// #321 native s16 inc/dec: a 16-bit register/local `x + 1` / `x - 1` selects to a
// single `inc a` / `dec a` in 16-bit-accumulator mode (1 byte, stays in the rep/sep
// bracket), NOT the 8-bit byte inc/dec-with-carry chain (`sep; ldx; stx; inc zp; bne;
// inc zp; rep`) the default path emits — which thrashes M-mode inside a 16-bit region.
//
// x and y are multi-use locals (held in Imag16 pairs); each ±1 below writes a distinct
// volatile, so nothing folds away:
//   o1 = x + 1  -> lda x; inc a; sta o1   (0x1235)
//   o2 = y - 1  -> lda y; dec a; sta o2   (0x00FF)
//   o3 = y + 1  -> lda y; inc a; sta o3   (0x0101)
//   o4 = x - 1  -> lda x; dec a; sta o4   (0x1233)
//   corpus_result = o1 + o2 + o3 + o4 = 0x2668
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16incdec.c
// See docs/plans/2026-06-15-321-native-s16-inc-dec-accumulator.md.

volatile unsigned short seed = 0x1234;
volatile unsigned short p = 0x0100;
volatile unsigned short o1, o2, o3, o4;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short x = seed;   // 0x1234 (multi-use -> Imag16)
  unsigned short y = p;      // 0x0100 (multi-use -> Imag16)
  o1 = x + 1;                // inc a
  o2 = y - 1;                // dec a
  o3 = y + 1;                // inc a
  o4 = x - 1;                // dec a
  corpus_result = o1 + o2 + o3 + o4;   // 0x2668
  for (;;) {
  }
}
