// #321 native s16 — regression for the ASHR-by->=8 compile-time hang (found by the
// Tier-1 differential fuzzer). A signed (arithmetic) right shift of a 16-bit value by
// an amount >= 8 took the byte-decomposition path, whose sign-fill was computed with
// an s16 ICMP_SLT; under +mos-a16 that re-entered the native signed-compare
// legalization as a compare-result-AS-VALUE and the legalizer looped forever (a16ashift
// only covers amounts 1..7, the native path). Fixed by broadcasting the sign with an
// 8-bit AShr of the high byte. This exercises amounts 8 and 13 on both a negative and a
// positive operand (sign-extension must fill the vacated high bits correctly).
// Differential: default == +mos-a16 == host on both emulators.
volatile short sneg = (short)0xF234;   // negative
volatile short spos = 0x1234;          // positive
volatile unsigned short corpus_result;

int main(void) {
  unsigned short r = 0;
  r ^= (unsigned short)((short)sneg >> 8);    // 0xFFF2 (sign-extended)
  r ^= (unsigned short)((short)sneg >> 13);   // 0xFFFF
  r ^= (unsigned short)((short)spos >> 8);    // 0x0012
  r ^= (unsigned short)((short)spos >> 13);   // 0x0000
  corpus_result = r;                          // 0xFFF2 ^ 0xFFFF ^ 0x0012 = 0x001F
  for (;;) {}
}
