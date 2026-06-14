// #321 Increment 1d-retry: a GISel-native 16-bit value that lives in Imag16.
// `t` is a LOCAL reused by three stores, so the 1b/1c combiner peephole (which
// matches a single store-of-ALU over globals) CANNOT fire — the s16 add must go
// native: legalizer keeps it un-narrowed, the value is allocated to an Imag16
// zero-page pair, and selectAdd16Native emits lda zp; clc; adc zp; sta zp on the
// transient A16. This is the case the peephole can't do (a multi-use local).
volatile unsigned short a16v = 0x1000;
volatile unsigned short b16v = 0x0122;
volatile unsigned short g16;
volatile unsigned short h16;
volatile unsigned short corpus_result;
int main(void) {
  unsigned short t = a16v + b16v;   // 0x1122 — a local, reused below
  g16 = t;                          // use 1
  h16 = t;                          // use 2
  corpus_result = t;                // use 3 -> harness reads 0x1122
  for (;;) {}
}
