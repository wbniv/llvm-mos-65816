// Byte-register argument stores preserve both bytes, the returned value, and
// neighbouring bytes. Aligned packed objects place real word subobjects at
// offsets 254 and 255, exercising a page crossing with defined packed access.
#include <stdint.h>
#ifdef HOST_MAIN
#include <stdio.h>
#endif

typedef struct __attribute__((packed)) { uint16_t value; } Word;
typedef struct __attribute__((packed)) {
  unsigned char prefix[254];
  Word word;
  unsigned char suffix;
} Even;
typedef struct __attribute__((packed)) {
  unsigned char prefix[255];
  Word word;
  unsigned char suffix;
} Odd;
static volatile Even even __attribute__((aligned(256)));
static volatile Odd odd __attribute__((aligned(256)));
volatile uint16_t corpus_result;
volatile uint16_t source_word = 0xA53C;

__attribute__((noinline)) void put(volatile Word *p, uint16_t v) { p->value = v; }
__attribute__((noinline)) uint16_t put_return(volatile Word *p, uint16_t v) {
  p->value = v;
  return v;
}
__attribute__((noinline)) void native_put(volatile Word *p, uint16_t v) {
  p->value = v + 42;
}
__attribute__((noinline)) void native_copy(volatile Word *p) {
  p->value = source_word;
}
__attribute__((noinline)) void alias_put(volatile Word *p, volatile Word *q,
                                       uint16_t v) {
  p->value = v;
  q->value = v ^ 0xFFFFu;
}

static uint16_t kernel(void) {
  static const uint16_t values[] = {0, 1, 0xFF, 0x100, 0x8000, 0xA53C, 0xFFFF};
  uint16_t crc = 0x1234;
  for (unsigned i = 0; i < sizeof(values) / sizeof(values[0]); ++i) {
    unsigned offset = (i & 1u) ? 255 : 254;
    volatile Word *p = (i & 1u) ? &odd.word : &even.word;
    volatile unsigned char *bytes = (i & 1u)
        ? (volatile unsigned char *)&odd : (volatile unsigned char *)&even;
    uint16_t v = values[i];
    bytes[offset - 1] = 0x69;
    bytes[offset + 2] = 0x96;
    put(p, v);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    crc = (uint16_t)(crc * 33u) ^ bytes[offset];
    crc = (uint16_t)(crc * 33u) ^ bytes[offset + 1];
    crc ^= put_return(p, v ^ 0x5AC3);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    native_put(p, v);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    native_copy(p);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    alias_put(p, p, v);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    crc = (uint16_t)(crc * 33u) ^ bytes[offset - 1];
    crc = (uint16_t)(crc * 33u) ^ bytes[offset + 2];
  }
  return crc;
}

int main(void) {
#ifdef HOST_MAIN
  printf("0x%04X\n", (unsigned)kernel());
#else
  corpus_result = kernel();
  for (;;) __asm__ volatile("wai");
#endif
}
