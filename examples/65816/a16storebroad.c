// The stored word and arithmetic result exercise independent uses of both bytes.
// Packed word subobjects cover valid odd addresses and a near page crossing.
#include <stdint.h>
#ifdef HOST_MAIN
#include <stdio.h>
#endif

typedef struct __attribute__((packed)) { uint16_t value; } Word;
typedef struct __attribute__((packed)) {
  unsigned char prefix[255];
  Word word;
  unsigned char suffix;
} Storage;
static volatile Storage storage __attribute__((aligned(256)));
volatile uint16_t corpus_result, word_source, absolute_word;
volatile uint8_t byte_source;

__attribute__((noinline)) uint16_t produce(void) { return word_source; }
__attribute__((noinline)) void clobber(void) { word_source ^= 0x5AC3; }
__attribute__((noinline)) uint16_t absolute_dec(uint16_t v) {
  absolute_word = v;
  return v - 1;
}
__attribute__((noinline)) uint16_t indirect_inc(volatile Word *p, uint16_t v) {
  p->value = v;
  return v + 1;
}
__attribute__((noinline)) uint16_t indirect_dec(volatile Word *p, uint16_t v) {
  p->value = v;
  return v - 1;
}
__attribute__((noinline)) void call_result(volatile Word *p) {
  p->value = produce();
}
__attribute__((noinline)) uint16_t call_return(volatile Word *p) {
  uint16_t v = produce();
  p->value = v;
  return v;
}
__attribute__((noinline)) void byte_argument(volatile Word *p, uint8_t v) {
  p->value = v;
}
__attribute__((noinline)) void byte_absolute(volatile Word *p) {
  p->value = byte_source;
}
__attribute__((noinline)) void byte_indirect(volatile Word *p,
                                          volatile uint8_t *q) {
  p->value = *q;
}
__attribute__((noinline)) void loaded_pointer(volatile Word *volatile *p,
                                           uint16_t v) {
  (*p)->value = v;
}
__attribute__((noinline)) void call_live(volatile Word *p, uint16_t v) {
  clobber();
  p->value = v;
}

static uint16_t kernel(void) {
  static const uint16_t values[] = {0, 1, 0xFF, 0x100, 0x101, 0x8000,
                                  0xA53C, 0xFF00, 0xFFFE, 0xFFFF};
  volatile Word *volatile pointer = &storage.word;
  volatile Word *p = pointer;
  uint16_t crc = 0x1234;
  for (unsigned i = 0; i < sizeof(values) / sizeof(values[0]); ++i) {
    uint16_t v = values[i];
    storage.prefix[254] = 0x69;
    storage.suffix = 0x96;
    word_source = v;
    byte_source = (uint8_t)v;
    crc ^= absolute_dec(v);
    crc = (uint16_t)(crc * 33u) ^ absolute_word;
    crc ^= indirect_inc(p, v);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    crc ^= indirect_dec(p, v);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    call_result(p);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    crc ^= call_return(p);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    byte_argument(p, (uint8_t)v);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    byte_absolute(p);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    byte_indirect(p, &byte_source);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    // A byte load may alias the low byte of the destination word.
    p->value = v;
    byte_indirect(p, (volatile uint8_t *)p);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    loaded_pointer(&pointer, v);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    call_live(p, v);
    crc = (uint16_t)(crc * 33u) ^ p->value;
    crc = (uint16_t)(crc * 33u) ^ storage.prefix[254];
    crc = (uint16_t)(crc * 33u) ^ storage.suffix;
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
