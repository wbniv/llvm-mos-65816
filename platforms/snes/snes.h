#ifndef _SNES_H_
#define _SNES_H_

/* Minimal SNES (Super Famicom) hardware register map for the llvm-mos SNES
 * target (M0). This is deliberately small — just enough to bring the machine
 * up and prove code runs. It will grow into a proper HAL as the target matures.
 *
 * All registers are in bank $00 and reachable via absolute addressing while the
 * CPU runs in 6502-emulation mode. */

#include <stdint.h>

#define _SNES_REG8(addr) (*(volatile uint8_t *)(uintptr_t)(addr))

/* --- PPU --- */
#define REG_INIDISP  _SNES_REG8(0x2100) /* screen on/off + brightness         */
#define REG_OBSEL    _SNES_REG8(0x2101) /* object size / base                 */
#define REG_BGMODE   _SNES_REG8(0x2105) /* BG mode / tile size                */
#define REG_CGADD    _SNES_REG8(0x2121) /* CGRAM (palette) word address       */
#define REG_CGDATA   _SNES_REG8(0x2122) /* CGRAM data port (write low, high)  */
#define REG_TM       _SNES_REG8(0x212C) /* main-screen layer enable           */

/* --- CPU / DMA control --- */
#define REG_NMITIMEN _SNES_REG8(0x4200) /* NMI / IRQ / auto-joypad enable     */
#define REG_MEMSEL   _SNES_REG8(0x420D) /* ROM access speed (0=slow,1=fast)   */

/* Force-blank, brightness 0 — safe state to hold the PPU in during init. */
#define INIDISP_FORCE_BLANK 0x8F
/* Screen on, full brightness. */
#define INIDISP_ON          0x0F

/* Pack an RGB555 (5-5-5 BGR) colour for CGRAM. */
#define SNES_RGB(r, g, b) ((uint16_t)(((b) & 0x1F) << 10 | ((g) & 0x1F) << 5 | ((r) & 0x1F)))

#endif /* _SNES_H_ */
