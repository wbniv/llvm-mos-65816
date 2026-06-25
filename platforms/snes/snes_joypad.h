#ifndef _SNES_JOYPAD_H_
#define _SNES_JOYPAD_H_

/* SNES controller input.
 *
 * Two ways to read pads:
 *  - Automatic: set NMITIMEN bit 0 (AUTOJOY); the CPU latches all four pads each
 *    frame into JOY1..JOY4 ($4218..$421F). Read them after the auto-read finishes
 *    (HVBJOY bit 0 clear), i.e. a little after v-blank starts.
 *  - Manual (NES-style): strobe $4016, then shift 16 bits out of $4016/$4017.
 *
 * Button bit layout of the 16-bit JOYn word: B Y Sel Sta Up Dn Lf Rt | A X L R 0 0 0 0.
 *
 * Facts: nocash "fullsnes", SNESdev wiki (docs/refs/snes-hardware/SOURCES.md). */

#include "snes_mmio.h"

/* ---- Manual (serial) controller access ---- */

/* @reg JOYSER0 $4016 RW  Write: strobe/latch both ports. Read: controller 1 serial bit. */
#define REG_JOYSER0  _SNES_REG8(0x4016)
/* @reg JOYSER1 $4017 R  Controller 2 serial bit (read). */
#define REG_JOYSER1  _SNES_REG8(0x4017)

/* ---- Automatic-read latches ---- */

/* @reg JOY1L $4218 R  Controller 1, low byte.
 * @bit  7     A
 * @bit  6     X
 * @bit  5     L
 * @bit  4     R
 * @bits 3-0   ID       controller id (0 = standard pad)
 */
#define REG_JOY1L    _SNES_REG8(0x4218)
/* @reg JOY1H $4219 R  Controller 1, high byte.
 * @bit  7     B
 * @bit  6     Y
 * @bit  5     SELECT
 * @bit  4     START
 * @bit  3     UP
 * @bit  2     DOWN
 * @bit  1     LEFT
 * @bit  0     RIGHT
 */
#define REG_JOY1H    _SNES_REG8(0x4219)
/* @reg JOY2L $421A R  Controller 2, low byte (layout as JOY1L). */
#define REG_JOY2L    _SNES_REG8(0x421A)
/* @reg JOY2H $421B R  Controller 2, high byte (layout as JOY1H). */
#define REG_JOY2H    _SNES_REG8(0x421B)
/* @reg JOY3L $421C R  Controller 3 (multitap), low byte. */
#define REG_JOY3L    _SNES_REG8(0x421C)
/* @reg JOY3H $421D R  Controller 3 (multitap), high byte. */
#define REG_JOY3H    _SNES_REG8(0x421D)
/* @reg JOY4L $421E R  Controller 4 (multitap), low byte. */
#define REG_JOY4L    _SNES_REG8(0x421E)
/* @reg JOY4H $421F R  Controller 4 (multitap), high byte. */
#define REG_JOY4H    _SNES_REG8(0x421F)

/* @reg16 JOY1 $4218 R  Controller 1, full 16-bit button word.
 * @bit  15    B
 * @bit  14    Y
 * @bit  13    SELECT
 * @bit  12    START
 * @bit  11    UP
 * @bit  10    DOWN
 * @bit  9     LEFT
 * @bit  8     RIGHT
 * @bit  7     A
 * @bit  6     X
 * @bit  5     L
 * @bit  4     R
 */
#define REG_JOY1     _SNES_REG16(0x4218)
/* @reg16 JOY2 $421A R  Controller 2, 16-bit button word (layout as JOY1). */
#define REG_JOY2     _SNES_REG16(0x421A)
/* @reg16 JOY3 $421C R  Controller 3, 16-bit button word. */
#define REG_JOY3     _SNES_REG16(0x421C)
/* @reg16 JOY4 $421E R  Controller 4, 16-bit button word. */
#define REG_JOY4     _SNES_REG16(0x421E)

/* ============================ constants ============================ */

/* Button masks for the 16-bit JOYn word. */
#define JOY_B       0x8000
#define JOY_Y       0x4000
#define JOY_SELECT  0x2000
#define JOY_START   0x1000
#define JOY_UP      0x0800
#define JOY_DOWN    0x0400
#define JOY_LEFT    0x0200
#define JOY_RIGHT   0x0100
#define JOY_A       0x0080
#define JOY_X       0x0040
#define JOY_L       0x0020
#define JOY_R       0x0010

/* ============================ helpers ============================ */

/* Read controller 1 by the MANUAL serial protocol: strobe $4016 (write 1 then 0 to latch the
 * button state), then shift 16 bits out of $4016 bit 0, MSB first. Returns the JOY_* bitmask
 * (B,Y,Select,Start,U,D,L,R,A,X,L,R in bits 15..4; the low nibble is the controller signature).
 * Requires auto-joypad read OFF (NMITIMEN bit0 = 0 — crt0 leaves it 0); otherwise the hardware
 * auto-reader and this manual read fight over $4016. (Auto-read alternative: set NMITIMEN bit0,
 * wait HVBJOY bit0 == 0 each frame, then read the REG_JOY1 word.) */
static inline uint16_t snes_read_pad1(void) {
  REG_JOYSER0 = 1;
  REG_JOYSER0 = 0;
  uint16_t p = 0;
  for (uint8_t i = 0; i < 16; i++)
    p = (uint16_t)((p << 1) | (REG_JOYSER0 & 1));
  return p;
}

#endif /* _SNES_JOYPAD_H_ */
