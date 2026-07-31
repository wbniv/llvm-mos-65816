#ifndef SNES_VIDEO_DMA_H
#define SNES_VIDEO_DMA_H

#include <stdint.h>

typedef struct {
  uint8_t channel;
  uint8_t wram_bank;
} SvcSnesDmaContext;

typedef struct {
  uint16_t dma_registers;
  uint8_t mdmaen;
  uint8_t wram_address_low;
  uint8_t wram_address_middle;
  uint8_t wram_address_high;
  uint8_t source_address_low;
  uint8_t source_address_high;
  uint8_t source_bank;
  uint8_t byte_count_low;
  uint8_t byte_count_high;
} SvcSnesDmaPlan;

/* Validate and describe one ROM -> WRAM DMA. destination_address is the
   16-bit near address within WRAM bank $7E or $7F selected by context. */
uint8_t svc_snes_dma_plan(const SvcSnesDmaContext *context,
                          uint8_t source_bank, uint16_t source_address,
                          uint16_t destination_address, uint16_t bytes,
                          SvcSnesDmaPlan *plan);

/* SvcSegmentCopy adapter for svc_segment_cursor_read(). The caller owns the
   selected GP-DMA channel; it must not also be enabled for HDMA. */
uint8_t svc_snes_dma_copy_segment(void *context, uint8_t source_bank,
                                  uint16_t source_address,
                                  uint8_t *destination, uint16_t bytes);

#endif
