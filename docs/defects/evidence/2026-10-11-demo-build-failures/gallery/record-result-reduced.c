#include <stdint.h>
volatile uint16_t corpus_result;
uint8_t g_failed[62], g_done[62], g_count;
__attribute__((noinline))
uint16_t record_result(uint8_t k, uint16_t gate, uint8_t ok) {
  g_failed[k] = ok;
  if (!g_done[k]) { g_done[k] = 1; g_count++; }
  if (g_count == 62) {
    uint8_t any = 0;
    for (uint8_t i = 0; i < 62; i++) any |= g_failed[i];
    gate = (uint16_t)(0x1512u ^ (any ? 0x8000u : 0u));
    corpus_result = gate;
  }
  return gate;
}
