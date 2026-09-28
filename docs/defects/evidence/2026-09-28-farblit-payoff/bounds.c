#include <stdint.h>
#define FAR __attribute__((address_space(2)))
#define NOINLINE __attribute__((noinline))
volatile uint32_t rbase = 0xFFFFu;
volatile uint32_t wbase = 0x7EFF80u;
#ifdef HOST
#include <stdio.h>
static uint8_t ram[0x20000];
static uint8_t byteat(uint32_t off) {
  uint32_t i = off >> 1;
  uint16_t v = (uint16_t)(i + (i >> 16));
  return off & 1 ? v >> 8 : (uint8_t)v;
}
static uint16_t wordat(uint32_t off) {
  return byteat(off) | ((uint16_t)byteat(off + 1) << 8);
}
#define WORD_BASE uint32_t src = rbase
#define BYTE_BASE uint32_t src = rbase
#define READ_WORD(j) wordat(src + (uint32_t)(j) * 2)
#define READ_BYTE(j) byteat(src + (j))
#define DEST_BASE uint32_t dst = wbase - 0x7E0000u
#define WRITE_BYTE(j,v) (ram[dst + (j)] = (v))
#define READ_BACK(j) ram[0xFF80u + (j)]
#else
extern const FAR uint16_t tbl[];
#define WORD_BASE const FAR uint16_t *src = (const FAR uint16_t *)((const FAR uint8_t *)tbl + rbase)
#define BYTE_BASE const FAR uint8_t *src = (const FAR uint8_t *)tbl + rbase
#define READ_WORD(j) src[j]
#define READ_BYTE(j) src[j]
#define DEST_BASE FAR uint8_t *dst = (FAR uint8_t *)wbase
#define WRITE_BYTE(j,v) (dst[j] = (v))
#define READ_BACK(j) (*(volatile FAR uint8_t *)(0x7EFF80u + (uint32_t)(j)))
#endif
static uint16_t mix16(uint16_t h, uint16_t v) {
  return (uint16_t)((uint16_t)(h << 3) | (h >> 13)) ^ v;
}
static uint32_t mix32(uint32_t h, uint16_t v) {
  return ((h << 5) | (h >> 27)) ^ v;
}
// Starting at an odd byte offset makes the first word straddle a bank.
NOINLINE uint16_t word128(void) {
  WORD_BASE; uint16_t h = 0;
  for (uint8_t j = 0; j < 128; ++j) h = mix16(h, READ_WORD(j));
  return h;
}
// The last element needs byte index 256 and must retain the word fallback.
NOINLINE uint16_t word129(void) {
  WORD_BASE; uint16_t h = 0;
  for (uint8_t j = 0; j < 129; ++j) h = mix16(h, READ_WORD(j));
  return h;
}
// The induction value wraps before it reaches the exit value.
NOINLINE uint16_t word_wrap(void) {
  WORD_BASE; uint16_t h = 0; uint8_t j = 250;
  do { h = mix16(h, READ_WORD(j)); } while (++j != 6);
  return h;
}
NOINLINE uint16_t word256(void) {
  WORD_BASE; uint16_t h = 0; uint8_t j = 0;
  do { h = mix16(h, READ_WORD(j)); } while (++j != 0);
  return h;
}
// Wrapping an expression before scaling differs from wrapping the byte offset.
NOINLINE uint16_t word_wrapped_index(void) {
  WORD_BASE; uint16_t h = 0;
  for (uint8_t j = 0; j < 64; ++j) h = mix16(h, READ_WORD((uint8_t)(j + 248)));
  return h;
}
// A non-unit induction step is outside the bounded-loop proof.
NOINLINE uint16_t word_step2(void) {
  WORD_BASE; uint16_t h = 0;
  for (uint8_t j = 0; j != 64; j += 2) h = mix16(h, READ_WORD(j));
  return h;
}
NOINLINE void copy248(void) {
  BYTE_BASE; DEST_BASE;
  for (uint8_t j = 0; j < 248; ++j) WRITE_BYTE(j, READ_BYTE((uint16_t)j + 8));
}
NOINLINE void copy249(void) {
  BYTE_BASE; DEST_BASE;
  for (uint8_t j = 0; j < 249; ++j) WRITE_BYTE(j, READ_BYTE((uint16_t)j + 8));
}
NOINLINE void copy_wrap(void) {
  BYTE_BASE; DEST_BASE; uint8_t j = 250;
  do { WRITE_BYTE(j, READ_BYTE((uint16_t)j + 8)); } while (++j != 6);
}
NOINLINE void copy_wrapped_index(void) {
  BYTE_BASE; DEST_BASE;
  for (uint8_t j = 0; j < 64; ++j) WRITE_BYTE(j, READ_BYTE((uint8_t)(j + 248)));
}
NOINLINE uint16_t bump(uint16_t x) { return (uint16_t)(x * 5u + 7u); }
NOINLINE uint16_t word_pressure(void) {
  WORD_BASE;
  uint16_t a=1,b=2,c=3,d=4,e=5,f=6,g=7,h=8;
  for (uint8_t j=0; j<64; ++j) {
    a=bump(a); uint16_t v=READ_WORD(j);
    b=mix16(b,v); c=mix16(c,b); d=mix16(d,c); e=mix16(e,d);
    f=mix16(f,e); g=mix16(g,f); h=mix16(h,g);
  }
  return a^b^c^d^e^f^g^h;
}
static uint16_t readback(void) {
  uint16_t h=0;
  for (uint16_t j=0; j<256; ++j) h=mix16(h,READ_BACK(j));
  return h;
}
static uint32_t run(void) {
  uint32_t h=0;
  for (uint8_t k=0; k<3; ++k) {
    rbase = k==0 ? 0xFFFFu : k==1 ? 0x1FFFFu : 0xFF80u;
    h=mix32(h,word128()); h=mix32(h,word129());
    h=mix32(h,word_wrap()); h=mix32(h,word256());
    h=mix32(h,word_wrapped_index()); h=mix32(h,word_step2());
    h=mix32(h,word_pressure());
    DEST_BASE;
    for (uint16_t j=0; j<256; ++j) WRITE_BYTE(j,0);
    copy248(); h=mix32(h,readback());
    copy249(); h=mix32(h,readback());
    copy_wrap(); h=mix32(h,readback());
    copy_wrapped_index(); h=mix32(h,readback());
  }
  return h;
}
#ifdef HOST
int main(void) { printf("0x%08lX\n",(unsigned long)run()); }
#else
volatile uint32_t corpus_result;
int main(void) { corpus_result=run(); for (;;) __asm__ volatile("wai"); }
#endif
