#ifndef _SNES_WRAM_H_
#define _SNES_WRAM_H_

/* SNES work-RAM access port — a CPU window into the full 128 KB of WRAM
 * (banks $7E..$7F) usable from any bank. Set the 17-bit address via
 * WMADDL/M/H, then read or write WMDATA repeatedly; the address auto-increments
 * on each WMDATA access (and wraps within $7E..$7F).
 *
 * Mostly useful for touching high WRAM ($7E2000+ / bank $7F) without far
 * addressing; the +mos-a16 far-pointer path is the alternative (see
 * docs/refs/65816/65816-reference.md and examples/65816/far_*.c).
 *
 * Facts: nocash "fullsnes", SNESdev wiki (docs/refs/snes-hardware/SOURCES.md). */

#include "snes_mmio.h"

/* @reg WMDATA $2180 RW  WRAM data port; each access auto-increments WMADD. */
#define REG_WMDATA   _SNES_REG8(0x2180)
/* @reg WMADDL $2181 W  WRAM address, low byte. */
#define REG_WMADDL   _SNES_REG8(0x2181)
/* @reg WMADDM $2182 W  WRAM address, middle byte. */
#define REG_WMADDM   _SNES_REG8(0x2182)
/* @reg WMADDH $2183 W  WRAM address, high byte.
 * @bit  0     BANK     address bit 16 (0 = bank $7E, 1 = bank $7F)
 */
#define REG_WMADDH   _SNES_REG8(0x2183)

#endif /* _SNES_WRAM_H_ */
