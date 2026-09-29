// A signed near offset must wrap within DBR. Distinct bytes in banks $7E
// and $7F distinguish modulo-16-bit pointer arithmetic from a bank carry.
// The two bytes are seeded with absolute-long stores in assembly, so this
// fixture needs no far address space.
#include <stdint.h>
volatile uint16_t corpus_result;
__attribute__((noinline,used))
uint8_t near_wrap(const uint8_t *p, int16_t offset) {
  return p[offset];
}
// php; sep #$20; lda #$5a; sta $7ea802; lda #$c3; sta $7fa802; plp; rts
asm(".text\n.global seed_banks\nseed_banks:\n"
    "php\n.byte $e2,$20\n"
    ".byte $a9,$5a\n.byte $8f,$02,$a8,$7e\n"
    ".byte $a9,$c3\n.byte $8f,$02,$a8,$7f\n"
    "plp\nrts\n");
// php; phb; pea $7e7e; plb; plb; jsr near_wrap; plb; plp; rts
asm(".text\n.global wrap_bank7e\nwrap_bank7e:\n"
    "php\n.byte $8b\n.byte $f4,$7e,$7e\n.byte $ab,$ab\n"
    "jsr near_wrap\n.byte $ab\nplp\nrts\n");
void seed_banks(void);
uint8_t wrap_bank7e(const uint8_t *p, int16_t offset);
int main(void) {
  seed_banks();
  uint8_t value = wrap_bank7e((const uint8_t *)0xa806, -4);
  corpus_result = value == 0x5a ? 0x5cf0 : (uint16_t)(0xa500 | value);
  for (;;) __asm__ volatile("wai");
}
