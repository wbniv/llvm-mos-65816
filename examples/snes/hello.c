// M0 smoke test: prove llvm-mos-compiled C boots and runs on the SNES.
//
// Sets the screen backdrop (CGRAM colour 0) to a recognizable green, turns the
// screen on, and writes a sentinel byte to WRAM in a loop. A headless emulator
// screenshot should be solid green; a WRAM dump should show the sentinel.

#include <snes.h>

// Placed in low WRAM; its value (0x42) is the "I ran" sentinel.
volatile unsigned char sentinel;

int main(void) {
  // FIRST, before anything touches the screen: force-blank and zero every PPU
  // control register. Power-on leaves them indeterminate and bsnes-jg fills
  // them with clock()-seeded noise (window masks, colour math, layer enables
  // this ROM never sets), so without this the picture -- though not the WRAM
  // sentinel -- is different on every single boot
  // (docs/plans/2026-08-01-cartsize-canary-display-nondeterminism.md).
  snes_ppu_reset_blank();

  // Backdrop colour = green (BGR555). CGRAM is written low byte then high byte.
  REG_CGADD = 0;
  REG_CGDATA = SNES_RGB(0, 31, 0) & 0xFF;
  REG_CGDATA = SNES_RGB(0, 31, 0) >> 8;

  // Release force-blank: screen on, full brightness.
  REG_INIDISP = INIDISP_ON;

  for (;;) {
    sentinel = 0x42;
  }
  return 0;
}
