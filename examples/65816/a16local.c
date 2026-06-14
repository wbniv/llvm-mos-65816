// #321 Increment 1d: a multi-use 16-bit LOCAL intermediate — the GISel-native path.
// t = a + b is used twice (g and h), so the peephole bails and the legalizer keeps
// the s16 G_ADD un-narrowed -> selectAdd16Native (one 16-bit ADC on an Imag16 pair).
volatile unsigned short a16v = 0x1100;
volatile unsigned short b16v = 0x0022;
volatile unsigned short g16, h16;
volatile unsigned short corpus_result;
int main(void) {
  unsigned short t = a16v + b16v;   // 0x1122; a local, used twice below
  g16 = t;
  h16 = t;
  corpus_result = g16;              // 0x1122
  for (;;) {}
}
