#include <stdint.h>

/* Upstream-only reproducer: no SNES, 65816, far-pointer, or linker-script
   extensions.  LINKED_OBJECT_ADDRESS is supplied by the link gate. */
extern const uint8_t linked_object[];
extern void abi_conforming_call(void);

volatile uint8_t dma_source_low;
volatile uint8_t dma_source_high;
volatile uint8_t dma_source_bank;

__attribute__((noinline)) uint8_t program_dma(void) {
  uintptr_t source = (uintptr_t)linked_object;
  uint8_t low = (uint8_t)source;

  /* Keep low live across a call, matching the visible-proof shape. */
  abi_conforming_call();
  dma_source_low = low;
  dma_source_high = (uint8_t)(source >> 8);
  dma_source_bank = 0;
  return (uint8_t)(dma_source_low ^ dma_source_high ^ dma_source_bank);
}
