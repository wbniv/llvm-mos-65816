// #321 Tier-1 combinatorial mixing test #1 — many s16 features interacting in one
// body: an add-chain, a constant shift + XOR, signed and unsigned compares feeding
// branches, a noinline call (forcing spills of several live 16-bit values), and a
// counted loop. The micro-tests prove each in isolation; this stresses the seams.
// Differential: default == +mos-a16 == host on both emulators.
volatile unsigned short A = 0x1234, B = 0x00F0, C = 0x0007, D = 0x4001, E = 0x0102;
volatile unsigned short corpus_result;

__attribute__((noinline)) static unsigned short mixf(unsigned short x, unsigned short y) {
  return (unsigned short)((unsigned)(x ^ y) + (unsigned)(x & y));
}

int main(void) {
  unsigned short a = A, b = B, c = C, d = D, e = E;
  unsigned short s = (unsigned short)((unsigned)a + (unsigned)b + (unsigned)d);   // add-chain
  s = (unsigned short)((unsigned)s ^ ((unsigned)e << 2));                          // const shift + xor
  if (a > b)                                                                       // unsigned compare -> branch
    s = (unsigned short)((unsigned)s + (unsigned)c);
  else
    s = (unsigned short)((unsigned)s - (unsigned)c);
  unsigned short t = mixf(s, d);                                                    // call: s,a,... live across
  if ((short)t < (short)0)                                                          // signed compare -> branch
    t = (unsigned short)((unsigned)t >> 3);
  for (unsigned char i = 0; i < 5; i++)                                             // loop accumulate (8-bit ctr)
    t = (unsigned short)((unsigned)t + (unsigned)a);
  corpus_result = (unsigned short)((unsigned)t ^ (unsigned)s);
  for (;;) {}
}
