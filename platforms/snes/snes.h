#ifndef _SNES_H_
#define _SNES_H_

/* Minimal SNES (Super Famicom) hardware register map for the llvm-mos SNES
 * target (M0). This is deliberately small — just enough to bring the machine
 * up and prove code runs. It will grow into a proper HAL as the target matures.
 *
 * All registers are in bank $00 and reachable via absolute addressing while the
 * CPU runs in 6502-emulation mode. */

#include <stdint.h>

#define _SNES_REG8(addr)  (*(volatile uint8_t  *)(uintptr_t)(addr))
#define _SNES_REG16(addr) (*(volatile uint16_t *)(uintptr_t)(addr))

/* --- PPU --- */
#define REG_INIDISP  _SNES_REG8(0x2100) /* screen on/off + brightness         */
#define REG_OBSEL    _SNES_REG8(0x2101) /* object size / base                 */
#define REG_BGMODE   _SNES_REG8(0x2105) /* BG mode / tile size                */
#define REG_BG1SC    _SNES_REG8(0x2107) /* BG1 tilemap base ($400-word) + size*/
#define REG_BG2SC    _SNES_REG8(0x2108) /* BG2 tilemap base + size            */
#define REG_BG12NBA  _SNES_REG8(0x210B) /* BG1/BG2 char base ($1000-word nib) */
#define REG_BG1HOFS  _SNES_REG8(0x210D) /* BG1 horiz scroll (write low, high) */
#define REG_BG1VOFS  _SNES_REG8(0x210E) /* BG1 vert  scroll (write low, high) */
#define REG_VMAIN    _SNES_REG8(0x2115) /* VRAM addr increment mode           */
#define REG_VMADDL   _SNES_REG8(0x2116) /* VRAM word address low              */
#define REG_VMADDH   _SNES_REG8(0x2117) /* VRAM word address high             */
#define REG_VMDATAL  _SNES_REG8(0x2118) /* VRAM data write low                */
#define REG_VMDATAH  _SNES_REG8(0x2119) /* VRAM data write high (triggers inc)*/
#define REG_VMADD    _SNES_REG16(0x2116)/* VRAM word address, 16-bit          */
#define REG_VMDATA   _SNES_REG16(0x2118)/* VRAM data, 16-bit (low then high)  */
#define REG_CGADD    _SNES_REG8(0x2121) /* CGRAM (palette) word address       */
#define REG_CGDATA   _SNES_REG8(0x2122) /* CGRAM data port (write low, high)  */
#define REG_TM       _SNES_REG8(0x212C) /* main-screen layer enable           */
#define REG_TS       _SNES_REG8(0x212D) /* sub-screen layer enable            */
#define REG_CGWSEL   _SNES_REG8(0x2130) /* colour-math window / main-sub blend */
#define REG_CGADSUB  _SNES_REG8(0x2131) /* colour-math enable / add-sub        */
#define REG_COLDATA  _SNES_REG8(0x2132) /* fixed colour (sub-screen backdrop)  */

/* --- CPU / DMA control --- */
#define REG_NMITIMEN _SNES_REG8(0x4200) /* NMI / IRQ / auto-joypad enable     */
#define REG_MDMAEN   _SNES_REG8(0x420B) /* general-purpose DMA channel enable */
#define REG_MEMSEL   _SNES_REG8(0x420D) /* ROM access speed (0=slow,1=fast)   */

/* --- DMA channel 0 (general purpose) --- */
#define REG_DMAP0    _SNES_REG8(0x4300) /* ch0 transfer params (dir/mode)     */
#define REG_BBAD0    _SNES_REG8(0x4301) /* ch0 B-bus dest ($21xx low byte)    */
#define REG_A1T0L    _SNES_REG8(0x4302) /* ch0 A-bus src address low          */
#define REG_A1T0H    _SNES_REG8(0x4303) /* ch0 A-bus src address high         */
#define REG_A1B0     _SNES_REG8(0x4304) /* ch0 A-bus src bank                 */
#define REG_DAS0L    _SNES_REG8(0x4305) /* ch0 byte-count low                 */
#define REG_DAS0H    _SNES_REG8(0x4306) /* ch0 byte-count high                */

/* Force-blank, brightness 0 — safe state to hold the PPU in during init. */
#define INIDISP_FORCE_BLANK 0x8F
/* Screen on, full brightness. */
#define INIDISP_ON          0x0F

/* VMAIN: increment the VRAM word address by 1 after a write to $2119 (VMDATAH).
 * The usual setting for sequential word writes via the 16-bit VMDATA port. */
#define VMAIN_INC_HIGH_1    0x80

/* Main-screen layer-enable bits (REG_TM). */
#define TM_BG1 0x01
#define TM_BG2 0x02
#define TM_BG3 0x04
#define TM_BG4 0x08
#define TM_OBJ 0x10

/* BG tile-size / mode helpers (REG_BGMODE low 3 bits = mode 0..7). */
#define BGMODE_1 0x01   /* BG1/BG2 4bpp (16 colour), BG3 2bpp */
#define BGMODE_3 0x03   /* BG1 8bpp (256 colour), BG2 4bpp    */

/* Build a BG?SC value: tilemap base in $400-word units (bits 7-2) + map size
 * (bits 1-0; 0 = 32x32). REG_BG?SC = SNES_BGSC(word_base, 0). */
#define SNES_BGSC(word_base, size) ((uint8_t)(((((word_base) >> 10) & 0x3F) << 2) | ((size) & 3)))

/* Pack an RGB555 (5-5-5 BGR) colour for CGRAM. */
#define SNES_RGB(r, g, b) ((uint16_t)(((b) & 0x1F) << 10 | ((g) & 0x1F) << 5 | ((r) & 0x1F)))

/* Point the VRAM data port at word address `wa` for subsequent REG_VMDATA writes. */
static inline void snes_vram_addr(uint16_t wa) { REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = wa; }

/* Force-blank the screen and reset the PPU CONTROL registers to a known-zero state
 * (BG mode, mosaic, BG/char bases, scrolls, mode-7, windows, main/sub layer-enables,
 * colour math). SNES power-on leaves these indeterminate — bsnes-jg randomises them —
 * so a program that configures only the registers it "uses" renders nondeterministically
 * (a random mosaic, window mask, or colour-math enable corrupts the picture differently
 * each boot). Call once at startup, before configuring the display. The VRAM/CGRAM/OAM
 * address+data ports ($2104/$2116-$2119/$2121/$2122) are skipped — writing them has side
 * effects (they'd poke video memory at the current pointer). */
static inline void snes_ppu_reset_blank(void) {
  REG_INIDISP = INIDISP_FORCE_BLANK;
  for (uint16_t a = 0x2101; a <= 0x2133; a++) {
    if (a == 0x2104 || a == 0x2116 || a == 0x2117 || a == 0x2118 ||
        a == 0x2119 || a == 0x2121 || a == 0x2122) continue;       /* data/addr ports */
    *(volatile uint8_t *)(uintptr_t)a = 0;
  }
}

#endif /* _SNES_H_ */
