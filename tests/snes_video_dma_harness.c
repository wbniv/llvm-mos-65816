#include <stdint.h>
#include "../examples/snes/snes-video-dma.h"

int main(void) {
  SvcSnesDmaContext context = {3, 1};
  SvcSnesDmaPlan plan;
  if (!svc_snes_dma_plan(&context, 0x41, 0xff00, 0x1f00, 0x0100, &plan)) return 1;
  if (plan.dma_registers != 0x4330 || plan.mdmaen != 0x08) return 2;
  if (plan.wram_address_low != 0x00 || plan.wram_address_middle != 0x1f ||
      plan.wram_address_high != 1) return 3;
  if (plan.source_address_low != 0x00 || plan.source_address_high != 0xff ||
      plan.source_bank != 0x41) return 4;
  if (plan.byte_count_low != 0x00 || plan.byte_count_high != 0x01) return 5;
  if (svc_snes_dma_plan(&context, 0x41, 0xffff, 0, 2, &plan)) return 6;
  if (svc_snes_dma_plan(&context, 0x41, 0, 0xffff, 2, &plan)) return 7;
  if (svc_snes_dma_plan(&context, 0x41, 0, 0, 0, &plan)) return 8;
  context.channel = 8;
  if (svc_snes_dma_plan(&context, 0x41, 0, 0, 1, &plan)) return 9;
  context.channel = 3;
  context.wram_bank = 2;
  if (svc_snes_dma_plan(&context, 0x41, 0, 0, 1, &plan)) return 10;
  return 0;
}
