// Corpus: struct layout, array-of-struct, pointer-to-struct field access, and a
// write-through-pointer. Catches struct field-offset codegen + pointer deref — what
// M1's far pointers change. `pts` is volatile so every field access is a real runtime
// load/store (no folding); the computed sum is layout-independent (accessed by field).
//
// Result (unsigned 16-bit):
//   sum x = 1+2+3      = 6
//   sum y = 100+200+300= 600   (running 606)
//   sum tag = 7+8+9    = 24    (running 630)
//   pts[1].y += bump -> 202; r += 202        (running 832)
//   total = 832 = 0x0340
#include <stdint.h>

struct point { uint8_t x; uint16_t y; uint8_t tag; };

static volatile struct point pts[3] = { {1, 100, 7}, {2, 200, 8}, {3, 300, 9} };
volatile uint8_t  bump = 2;
volatile uint16_t corpus_result;

int main(void) {
  uint16_t r = 0;
  uint8_t i;

  volatile struct point *p = pts;
  for (i = 0; i < 3; i++) {
    r += p->x;
    r += p->y;
    r += p->tag;
    p++;
  }                                       // 630

  pts[1].y = (uint16_t)(pts[1].y + bump); // 200 + 2 = 202
  r += pts[1].y;                          // 832

  corpus_result = r;
  for (;;) __asm__ volatile("wai");
}
