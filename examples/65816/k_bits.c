// #321 Tier-1 realistic kernel — popcount + bit-reverse over an array, accumulated.
// Each element holds several live values at once (the value being consumed, the
// reversed value being built, a popcount, plus 8-bit loop counters) — heavy mixed
// 8/16-bit register pressure with shifts, AND, OR and adds. Differential:
// default == +mos-a16 == host on both emulators.
volatile unsigned short vals[6] = {0x0001, 0x8000, 0xF00F, 0xA5A5, 0x1234, 0xFFFF};
volatile unsigned short corpus_result;

int main(void) {
  unsigned short acc = 0;
  for (unsigned char k = 0; k < 6; k++) {
    unsigned short v = vals[k];
    unsigned char pc = 0;
    for (unsigned char b = 0; b < 16; b++) {
      pc = (unsigned char)(pc + (unsigned char)(v & 1));
      v = (unsigned short)((unsigned)v >> 1);
    }
    unsigned short r = 0, w = vals[k];
    for (unsigned char b = 0; b < 16; b++) {
      r = (unsigned short)(((unsigned)r << 1) | (unsigned)(w & 1));
      w = (unsigned short)((unsigned)w >> 1);
    }
    acc = (unsigned short)((unsigned)acc + (unsigned)r + (unsigned)pc);
  }
  corpus_result = acc;
  for (;;) {}
}
