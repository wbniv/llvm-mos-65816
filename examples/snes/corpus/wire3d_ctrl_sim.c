/* Corpus slice: the 3-D wireframe INTERACTIVE controller + HUD-format math, HAL-free, run over a fixed
 * deterministic pad script so the differential engine (dev/run.sh corpus-a16) checks it 5 ways:
 * host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean. Shares
 * examples/snes/wireframe.h with the demo (examples/snes/wireframe.c), so they can't drift. This is the
 * controller-math gate (the deterministic-scripted-input equivalent of a JGX replay). Golden from the
 * HOST_ORACLE build below. */
#include "../wireframe.h"

/* Deterministic pad script: ramp the X/Y spin rates and the dolly (LEVEL controls), then pulse
   A/Y/X/SELECT (with release frames) to exercise the edge controls (solid / palette / trail cycles).
   The auto-spin advances ax/ay/az every frame regardless, so the angle wrap math is exercised too. */
static uint16_t wire3d_ctrl_crc(void) {
  wire3d_view v; wire3d_view_reset(&v);
  uint16_t crc = 0xFFFF;
  for (uint16_t f = 0; f < 64; f++) {
    uint16_t pad = 0;
    if (f < 8)        pad = JOY_RIGHT;            /* ramp dax */
    else if (f < 16)  pad = JOY_UP;              /* ramp day */
    else if (f < 24)  pad = JOY_R;               /* dolly out */
    else if (f < 28)  pad = JOY_L;               /* dolly back in */
    else if ((f & 1) == 0) {
      switch (((f - 28) / 2) & 3) {
        case 0: pad = JOY_A; break; case 1: pad = JOY_Y; break;
        case 2: pad = JOY_X; break; default: pad = JOY_SELECT; break;
      }
    }
    wire3d_view_step(&v, pad);
    crc = wire3d_view_fold(crc, &v);
  }
  return crc;
}

#ifdef HOST_ORACLE
#include <stdio.h>
int main(void) { printf("0x%04X\n", wire3d_ctrl_crc()); return 0; }
#else
volatile uint16_t corpus_result;
int main(void) { corpus_result = wire3d_ctrl_crc(); for (;;) __asm__ volatile("wai"); return 0; }
#endif
