#ifndef _SNES_MMIO_H_
#define _SNES_MMIO_H_

/* Shared MMIO accessor macros for the SNES HAL headers (snes_ppu.h, snes_dma.h,
 * snes_cpu.h, snes_joypad.h, snes_apu.h, snes_wram.h). Every REG_* in those
 * headers expands to one of these volatile lvalues.
 *
 * Annotation contract (parsed by tools/gen-snes-regmap.py to generate
 * docs/refs/snes-hardware/snes-register-map.md):
 *
 *   |* @reg   NAME  $ADDR  R|W|RW  one-line purpose
 *    * @bit   N        MNEMONIC  description
 *    * @bits  HI-LO    MNEMONIC  description
 *    *|
 *   #define REG_NAME  _SNES_REG8(0xADDR)
 *
 * Use @reg16 for a 16-bit access alias laid over an L/H byte-register pair
 * (e.g. REG_VMADD over VMADDL/VMADDH). The generator cross-checks that each
 * annotation's $ADDR equals the 0xADDR literal in the #define, and that bit
 * ranges are in 0..7 with no overlap — a mismatch fails the build. So: edit the
 * headers, never the generated .md. */

#include <stdint.h>

#define _SNES_REG8(addr)  (*(volatile uint8_t  *)(uintptr_t)(addr))
#define _SNES_REG16(addr) (*(volatile uint16_t *)(uintptr_t)(addr))

#endif /* _SNES_MMIO_H_ */
