// Absolute stores exercise byte-register arguments and native s16 producers.
// Values with different high bytes make width and byte-order errors observable.
#include <stdint.h>
#ifdef HOST_MAIN
#include <stdio.h>
#endif

volatile uint16_t store_g, store_h;
volatile uint16_t corpus_result;

__attribute__((noinline)) void store_arg(uint16_t v) { store_g = v; }
__attribute__((noinline)) uint16_t store_return(uint16_t v) {
  store_g = v;
  return v;
}
__attribute__((noinline)) void store_twice(uint16_t v) {
  store_g = v;
  store_h = v;
}
__attribute__((noinline)) uint16_t produce(uint16_t v) { return v ^ 0xA53C; }
__attribute__((noinline)) void store_call(uint16_t v) { store_g = produce(v); }
__attribute__((noinline)) void store_add(uint16_t v) { store_g = v + 0x1234; }
__attribute__((noinline)) void store_copy(void) { store_g = store_h; }
__attribute__((noinline)) uint16_t store_mixed(uint16_t v) {
  store_g = v;
  return v + 1;
}

static uint16_t kernel(void) {
  static const uint16_t inputs[] = {0, 1, 0xFF, 0x100, 0x5A3C, 0x8000, 0xFFFF};
  uint16_t crc = 0x1234;
  for (unsigned i = 0; i < sizeof(inputs) / sizeof(inputs[0]); ++i) {
    uint16_t v = inputs[i];
    store_arg(v);
    crc = (uint16_t)(crc * 33u) ^ store_g;
    crc ^= store_return(v);
    crc = (uint16_t)(crc * 33u) ^ store_g;
    store_twice(v);
    crc ^= store_g;
    crc = (uint16_t)(crc * 33u) ^ store_h;
    store_call(v);
    crc = (uint16_t)(crc * 33u) ^ store_g;
    store_add(v);
    crc = (uint16_t)(crc * 33u) ^ store_g;
    store_copy();
    crc = (uint16_t)(crc * 33u) ^ store_g;
    crc ^= store_mixed(v);
    crc = (uint16_t)(crc * 33u) ^ store_g;
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
