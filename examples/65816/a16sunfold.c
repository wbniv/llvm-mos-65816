// #321 native s16 load-fold (b): single-use-non-store results. A 16-bit ALU op with
// two near-abs global operands whose result is SINGLE-USE but the use is NOT a near-abs
// store. The store peephole (alu16_abs) needs a near-abs-store result; the multi-use
// load-fold (alu16_absld) explicitly skips single-use results — so neither combiner
// fires. selectAlu16Native (generalized by the mixed-operand fold) folds BOTH globals
// directly: `lda abs a; (clc|sec;) adc|sbc|and abs b; sta tmp`, with NO global ever
// materialized into an Imag16 pair.
//
// Each inner (X OP Y) below is both-global, single-use, feeding a further (non-store) op:
//   (a + b) ^ c   -> a+b folds both; ^c folds c
//   (a - b) | d   -> a-b folds both; |d folds d
//   (a & b) + c   -> a&b folds both; +c folds c
//
//   a=0x1234 b=0x1111 c=0x0042 d=0x0005:
//     (a+b)^c = 0x2345^0x0042 = 0x2307
//     (a-b)|d = 0x0123|0x0005 = 0x0127
//     (a&b)+c = 0x1010+0x0042 = 0x1052
//     corpus_result = 0x2307+0x0127+0x1052 = 0x3480
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16sunfold.c
// See docs/plans/2026-06-15-321-native-s16-single-use-non-store-fold.md.

volatile unsigned short a = 0x1234;
volatile unsigned short b = 0x1111;
volatile unsigned short c = 0x0042;
volatile unsigned short d = 0x0005;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short r = 0;
  r += (a + b) ^ c;   // 0x2307  (ADD, both-global single-use non-store)
  r += (a - b) | d;   // 0x0127  (SUB)
  r += (a & b) + c;   // 0x1052  (AND)
  corpus_result = r;  // 0x3480
  for (;;) __asm__ volatile("wai");
}
