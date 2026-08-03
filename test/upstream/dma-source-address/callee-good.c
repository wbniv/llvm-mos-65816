#include <stdint.h>

volatile uint8_t call_was_observed;

__attribute__((noinline)) void abi_conforming_call(void) {
  ++call_was_observed;
}
