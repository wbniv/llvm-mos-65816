// #321 Tier-1 combinatorial mixing test #2 — a bitwise (AND/OR/XOR) chain and an
// add-chain feeding a loop that interleaves a shift+XOR with a conditional add of an
// 8-bit counter, plus a signed compare gating a noinline call. Holds several 16-bit
// values live across the loop and the call (spill pressure). Differential:
// default == +mos-a16 == host on both emulators.
volatile unsigned short v0 = 0xABCD, v1 = 0x1357, v2 = 0x2468, v3 = 0x0F0F;
volatile unsigned short corpus_result;

__attribute__((noinline)) static unsigned short tripl(unsigned short x) {
  return (unsigned short)(((unsigned)x << 1) + (unsigned)x);   // x * 3, no libcall
}

int main(void) {
  unsigned short acc = (unsigned short)((unsigned)v0 & (unsigned)v3);
  acc = (unsigned short)((unsigned)acc | (unsigned)v1);
  acc = (unsigned short)((unsigned)acc ^ (unsigned)v2);                       // AND/OR/XOR chain
  unsigned short sum = (unsigned short)((unsigned)v0 + (unsigned)v1 +
                                        (unsigned)v2 + (unsigned)v3);          // add-chain
  if ((short)acc < (short)v1)                                                  // signed compare -> branch
    sum = (unsigned short)((unsigned)sum + (unsigned)tripl(acc));             // call
  for (unsigned char i = 0; i < 6; i++) {
    acc = (unsigned short)(((unsigned)acc << 1) ^ (unsigned)sum);             // shift + xor in loop
    if (acc & 1)                                                              // bit test -> branch
      sum = (unsigned short)((unsigned)sum + (unsigned)i);                    // 8-bit counter into 16-bit
  }
  corpus_result = (unsigned short)((unsigned)acc + (unsigned)sum);
  for (;;) {}
}
