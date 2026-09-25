#include <stdint.h>

// Callers supply counts below 64; the count reaches the shift as a byte value.
uint64_t onehot(uint8_t count) {
  return UINT64_C(1) << count;
}
