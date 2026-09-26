#include <stdint.h>
#include <stdio.h>

extern int16_t ashr_8(int16_t);
extern int16_t ashr_15(int16_t);
extern int32_t ashr_16(int32_t);

/* Unsigned reference arithmetic specifies the sign-extension bits directly.
   Every 16-bit input and every 32-bit high half is exercised. */
int main(void) {
  for (uint32_t n = 0; n < 65536UL; ++n) {
    uint16_t x = (uint16_t)n;
    uint16_t sign = (x & 0x8000U) ? 0xffffU : 0;
    uint16_t want8 = (x >> 8) | (sign & 0xff00U);
    uint32_t wide = ((uint32_t)x << 16) | (uint16_t)(x ^ 0x5a5aU);
    uint32_t want16 = (uint32_t)x | ((uint32_t)sign << 16);
    if ((uint16_t)ashr_8((int16_t)x) != want8 ||
        (uint16_t)ashr_15((int16_t)x) != sign ||
        (uint32_t)ashr_16((int32_t)wide) != want16) {
      puts("FAIL: arithmetic shift result");
      return 1;
    }
  }
  puts("PASS: 196608 arithmetic shift checks");
  return 0;
}
