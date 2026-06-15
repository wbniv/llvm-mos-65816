// #321 Tier-1 realistic kernel — unsigned 16-bit saturating accumulate. The overflow
// test is a native 16-bit unsigned compare (`s < acc`) feeding a branch, interleaved
// with 16-bit adds and an array walk. Differential: default==+mos-a16==host on both
// emulators. The inputs overflow partway, so the saturate branch is genuinely taken.
volatile unsigned short xs[8] = {0x4000, 0x4000, 0x4000, 0x4000, 0x1000, 0x0001, 0x0001, 0x0001};
volatile unsigned short corpus_result;

int main(void) {
  unsigned short acc = 0;
  for (unsigned char i = 0; i < 8; i++) {
    unsigned short s = (unsigned short)((unsigned)acc + (unsigned)xs[i]);
    if (s < acc)            // unsigned wrap -> overflowed
      s = 0xFFFF;           // saturate
    acc = s;
  }
  corpus_result = acc;      // saturates to 0xFFFF
  for (;;) {}
}
