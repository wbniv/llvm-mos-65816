/* Corpus slice: the spirograph INTERACTIVE controller + HUD-format math, HAL-free, run over a fixed
 * deterministic pad script so the differential engine (dev/run.sh corpus-a16) checks it 5 ways:
 * host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean. Shares
 * examples/snes/spirograph.h with the demo (examples/snes/spirograph.c), so they can't drift. This is
 * the controller-math gate (the deterministic-scripted-input equivalent of a JGX replay). Golden from
 * the HOST_ORACLE build below. */
#include "../spirograph.h"

/* Deterministic pad script: hold UP/RIGHT/R to ramp R/wheel/pen, then pulse A/Y/SELECT/X (with
   release frames) to exercise the edge controls (mode/preset/palette cycles). */
static uint16_t spiro_ctrl_crc(void) {
  spiro_view v; spiro_view_reset(&v);
  uint16_t crc = 0xFFFF;
  for (uint16_t f = 0; f < 64; f++) {
    uint16_t pad = 0;
    if (f < 8)        pad = JOY_UP;
    else if (f < 16)  pad = JOY_RIGHT;
    else if (f < 24)  pad = JOY_R;
    else if ((f & 1) == 0) {
      switch (((f - 24) / 2) & 3) {
        case 0: pad = JOY_A; break; case 1: pad = JOY_Y; break;
        case 2: pad = JOY_SELECT; break; default: pad = JOY_X; break;
      }
    }
    spiro_view_step(&v, pad);
    crc = spiro_view_fold(crc, &v);
  }
  return crc;
}

#ifdef HOST_ORACLE
#include <stdio.h>
int main(void) { printf("0x%04X\n", spiro_ctrl_crc()); return 0; }
#else
volatile uint16_t corpus_result;
int main(void) { corpus_result = spiro_ctrl_crc(); for (;;) {} return 0; }
#endif
