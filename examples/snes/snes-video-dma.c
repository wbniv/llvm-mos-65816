#include "snes-video-dma.h"

#include <stdint.h>

uint8_t svc_snes_dma_plan(const SvcSnesDmaContext *context,
                          uint8_t source_bank, uint16_t source_address,
                          uint16_t destination_address, uint16_t bytes,
                          SvcSnesDmaPlan *plan) {
  if (!context || !plan || context->channel >= 8u || context->wram_bank >= 2u ||
      !bytes || (uint32_t)source_address + bytes > 0x10000ul ||
      (uint32_t)destination_address + bytes > 0x10000ul)
    return 0;

  plan->dma_registers = (uint16_t)(0x4300u + (uint16_t)context->channel * 0x10u);
  plan->mdmaen = (uint8_t)(1u << context->channel);
  plan->wram_address_low = (uint8_t)destination_address;
  plan->wram_address_middle = (uint8_t)(destination_address >> 8);
  plan->wram_address_high = context->wram_bank;
  plan->source_address_low = (uint8_t)source_address;
  plan->source_address_high = (uint8_t)(source_address >> 8);
  plan->source_bank = source_bank;
  plan->byte_count_low = (uint8_t)bytes;
  plan->byte_count_high = (uint8_t)(bytes >> 8);
  return 1;
}

uint8_t svc_snes_dma_copy_segment(void *context, uint8_t source_bank,
                                  uint16_t source_address,
                                  uint8_t *destination, uint16_t bytes) {
#ifdef __mos__
  SvcSnesDmaPlan plan;
  volatile uint8_t *dma;
  if (!svc_snes_dma_plan((const SvcSnesDmaContext *)context, source_bank,
                         source_address, (uint16_t)(uintptr_t)destination,
                         bytes, &plan))
    return 0;

  /* $2180 is the auto-incrementing WRAM data port. Transfer mode 0 writes
     every incrementing A-bus source byte to that single B-bus register. */
  *(volatile uint8_t *)(uintptr_t)0x2181u = plan.wram_address_low;
  *(volatile uint8_t *)(uintptr_t)0x2182u = plan.wram_address_middle;
  *(volatile uint8_t *)(uintptr_t)0x2183u = plan.wram_address_high;
  dma = (volatile uint8_t *)(uintptr_t)plan.dma_registers;
  dma[0] = 0x00u;
  dma[1] = 0x80u;
  dma[2] = plan.source_address_low;
  dma[3] = plan.source_address_high;
  dma[4] = plan.source_bank;
  dma[5] = plan.byte_count_low;
  dma[6] = plan.byte_count_high;
  *(volatile uint8_t *)(uintptr_t)0x420bu = plan.mdmaen;
  return 1;
#else
  (void)context;
  (void)source_bank;
  (void)source_address;
  (void)destination;
  (void)bytes;
  return 0;
#endif
}
