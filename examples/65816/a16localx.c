// #321 Increment 1d-retry, step 4: the COMPLEX multi-op case that crashed the
// first 1d prototype's register coalescer. Five native s16 adds with locals
// reused across later ops (t used 3x, u 2x, w 2x) force heavy Imag16 pressure +
// spills — exactly where the prototype coalesced an 8-bit value into A16 and
// emitted a malformed `$a16 = LDImm`. With the value resident in Imag16 and the
// accumulator entered/left only via load/store (no Ac16<->8-bit COPY), this must
// compile clean and run correct on both emulators. All operands are volatile
// loads (no immediates yet — that's step 5).
volatile unsigned short a16v = 0x1000;
volatile unsigned short b16v = 0x0122;
volatile unsigned short c16v = 0x0034;
volatile unsigned short d16v = 0x0006;
volatile unsigned short g16, h16, i16;
volatile unsigned short corpus_result;
int main(void) {
  unsigned short t = a16v + b16v;   // 0x1122
  unsigned short u = t + c16v;      // 0x1156
  unsigned short w = t + u;         // 0x2278   (reuse t and u)
  unsigned short x = w + d16v;      // 0x227E
  g16 = t;                          // keep t/u/w live across the ops
  h16 = u;
  i16 = w;
  corpus_result = x + t;            // 0x227E + 0x1122 = 0x33A0  (reuse t again)
  for (;;) {}
}
