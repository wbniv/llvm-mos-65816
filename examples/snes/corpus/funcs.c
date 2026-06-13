// Corpus: function calls, multiple args, return values, and recursion. Catches the
// calling convention and soft-stack handling — the ABI work M2 lands. The fib index and
// add3 args are volatile so the recursion + calls actually execute at runtime.
//
// Result (unsigned 16-bit):
//   fib(12) = 144            (0,1,1,2,3,5,8,13,21,34,55,89,144)
//   add3(30,12,100) = 142
//   total = 286 = 0x011E
#include <stdint.h>

volatile uint8_t  fn = 12;
volatile uint16_t a = 30, b = 12;
volatile uint16_t corpus_result;

static uint16_t fib(uint8_t n) {
  if (n < 2) return n;
  return (uint16_t)(fib((uint8_t)(n - 1)) + fib((uint8_t)(n - 2)));
}

static uint16_t add3(uint16_t x, uint16_t y, uint16_t z) {
  return (uint16_t)(x + y + z);
}

int main(void) {
  uint16_t r = 0;
  r += fib(fn);               // 144
  r += add3(a, b, 100);       // 142
  corpus_result = r;
  for (;;) {}
}
