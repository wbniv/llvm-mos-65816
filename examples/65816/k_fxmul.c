// #321 Tier-1 realistic kernel — Q8.8 fixed-point multiply via a 16x16->16 shift-add
// loop. Holds the accumulator + (shifting) multiplicand + (shifting) multiplier live
// at once (3 live 16-bit values) while an 8-bit counter drives the loop — exactly the
// >1-value-live register pressure that A16-threading (Tier 2) must survive. The
// multiply runs in a real (inlinable) callee. Differential: default==+mos-a16==host.
volatile unsigned short fa = 0x0280;  // 2.5   in Q8.8
volatile unsigned short fb = 0x0140;  // 1.25  in Q8.8
volatile unsigned short corpus_result;

static unsigned short mul16(unsigned short a, unsigned short b) {
  unsigned short acc = 0;
  for (unsigned char i = 0; i < 16; i++) {
    if (b & 1)
      acc = (unsigned short)(acc + a);
    a = (unsigned short)((unsigned)a << 1);
    b = (unsigned short)((unsigned)b >> 1);
  }
  return acc;                        // low 16 bits of a*b
}

int main(void) {
  unsigned short p = mul16(fa, fb);            // 0x0280 * 0x0140 = 0x32000 -> low16 0x2000
  corpus_result = (unsigned short)((unsigned)p >> 8);  // Q8.8 -> 0x0020 (= 3.125)
  for (;;) __asm__ volatile("wai");
}
