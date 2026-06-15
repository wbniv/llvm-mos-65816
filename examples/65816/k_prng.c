// #321 Tier-1 realistic kernel — xorshift16 (7,9,8) PRNG iterated in a noinline step
// function, so the 16-bit state crosses the call boundary every iteration (the pass
// must drop to 8-bit at the call and re-enter 16-bit after). Exercises native 16-bit
// constant shifts + XOR threaded through the accumulator. Differential:
// default == +mos-a16 == host on both emulators.
volatile unsigned short seed = 0x1234;
volatile unsigned short corpus_result;

__attribute__((noinline)) static unsigned short xs16(unsigned short x) {
  x ^= (unsigned short)((unsigned)x << 7);
  x ^= (unsigned short)((unsigned)x >> 9);
  x ^= (unsigned short)((unsigned)x << 8);
  return x;
}

int main(void) {
  unsigned short x = seed;
  for (unsigned char i = 0; i < 64; i++)
    x = xs16(x);
  corpus_result = x;
  for (;;) {}
}
