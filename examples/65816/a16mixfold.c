// #321 native s16 mixed-operand load-fold: a 16-bit ALU op with ONE near-abs global
// operand and ONE Imag16 register operand (a multi-use local). The both-global
// combiner peephole can't fold this shape, so without the selectAlu16Native fold the
// global is copied byte-wise into an Imag16 pair first. With the fold the global is
// read directly — `lda abs` when it's the LHS (A), or `adc|sbc|and|ora|eor abs` when
// it's the ALU operand (B) — so each op is one rep/sep run with no Imag16 round-trip.
//
//   loc is read from a volatile once and reused 6x -> a multi-use Imag16 pair.
//   a16v is a single-use near-abs global (reloaded per op) -> folds each time.
//
//   a16v + loc   -> lda abs a16v; clc; adc zp loc      (A=global)
//   a16v - loc   -> lda abs a16v; sec; sbc zp loc      (A=global, minuend)
//   loc  - a16v  -> lda zp loc;  sec; sbc abs a16v     (B=global, subtrahend)
//   a16v & loc   -> fold a16v                          (commutative)
//   loc  | a16v  -> lda zp loc;  ora abs a16v          (B=global)
//   loc  ^ a16v  -> lda zp loc;  eor abs a16v          (B=global)
//
// With a16v=0x0F0F, loc=0x0033 the running sum is 0x2DC0.
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16mixfold.c
// See docs/plans/2026-06-15-321-native-s16-mixed-operand-load-fold.md.

volatile unsigned short a16v = 0x0F0F;
volatile unsigned short seed = 0x0033;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short loc = seed;   // one volatile read; reused 6x -> multi-use Imag16
  unsigned short r = 0;
  r += a16v + loc;             // 0x0F42  (ADD, A=global)
  r += a16v - loc;             // 0x0EDC  (SUB, A=global / minuend)
  r += loc - a16v;             // 0xF124  (SUB, B=global / subtrahend)
  r += a16v & loc;             // 0x0003  (AND, commutative)
  r += loc | a16v;             // 0x0F3F  (OR,  B=global)
  r += loc ^ a16v;             // 0x0F3C  (XOR, B=global)
  corpus_result = r;           // 0x2DC0
  for (;;) {
  }
}
