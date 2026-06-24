#ifndef _SNES_CPU_H_
#define _SNES_CPU_H_

/* SNES CPU-side I/O registers — $4200..$4217 (the Ricoh 5A22's own MMIO: interrupt
 * control, the hardware multiply/divide unit, the H/V IRQ timers, and FastROM
 * select). These are NOT the 65816 core's programmer registers (A/X/Y/P/flags) —
 * for the instruction set and the 8<->16-bit mode model see
 * docs/refs/65816/65816-reference.md.
 *
 * NOTE: the DMA/HDMA enable triggers MDMAEN ($420B) / HDMAEN ($420C) and the
 * auto-read joypad ports JOY1..4 ($4218..$421F) sit in this address block too but
 * live in snes_dma.h and snes_joypad.h respectively.
 *
 * Bit-field facts: nocash "fullsnes", SNESdev wiki (docs/refs/snes-hardware/SOURCES.md). */

#include "snes_mmio.h"

/* ---- Interrupt / joypad enable ---- */

/* @reg NMITIMEN $4200 W  Interrupt + auto-joypad enable.
 * @bit  7     NMI      enable v-blank NMI
 * @bits 5-4   HVIRQ    IRQ source (0 off, 1 H=HTIME, 2 V=VTIME, 3 H+V)
 * @bit  0     AUTOJOY  enable automatic joypad read each frame
 */
#define REG_NMITIMEN _SNES_REG8(0x4200)

/* @reg WRIO $4201 W  Programmable I/O port (output). Bit 7 drives the controller-port
 *                    latch pin used to latch the PPU H/V counters.
 * @bit  7     IO7      I/O pin 7 (port 2; 1->0 latches OPHCT/OPVCT)
 * @bit  6     IO6      I/O pin 6 (port 1)
 */
#define REG_WRIO     _SNES_REG8(0x4201)

/* ---- Hardware multiply / divide unit (the 65816 has no multiply instruction) ---- */

/* @reg WRMPYA $4202 W  Unsigned multiply: factor A (8-bit). */
#define REG_WRMPYA   _SNES_REG8(0x4202)
/* @reg WRMPYB $4203 W  Unsigned multiply: factor B (8-bit); writing starts 8x8->16, result in RDMPY after ~8 cycles. */
#define REG_WRMPYB   _SNES_REG8(0x4203)
/* @reg WRDIVL $4204 W  Unsigned divide: dividend low (16-bit dividend). */
#define REG_WRDIVL   _SNES_REG8(0x4204)
/* @reg WRDIVH $4205 W  Unsigned divide: dividend high. */
#define REG_WRDIVH   _SNES_REG8(0x4205)
/* @reg WRDIVB $4206 W  Unsigned divide: divisor (8-bit); writing starts 16/8, quotient in RDDIV / remainder in RDMPY after ~16 cycles. */
#define REG_WRDIVB   _SNES_REG8(0x4206)
/* @reg16 WRDIV $4204 W  16-bit access alias for the divide dividend (WRDIVL/H). */
#define REG_WRDIV    _SNES_REG16(0x4204)

/* ---- H/V IRQ timers ---- */

/* @reg HTIMEL $4207 W  H-count IRQ position, low (0..339). */
#define REG_HTIMEL   _SNES_REG8(0x4207)
/* @reg HTIMEH $4208 W  H-count IRQ position, high (bit 0). */
#define REG_HTIMEH   _SNES_REG8(0x4208)
/* @reg VTIMEL $4209 W  V-count IRQ position, low (0..261 NTSC). */
#define REG_VTIMEL   _SNES_REG8(0x4209)
/* @reg VTIMEH $420A W  V-count IRQ position, high (bit 0). */
#define REG_VTIMEH   _SNES_REG8(0x420A)
/* @reg16 HTIME $4207 W  16-bit access alias for the H IRQ position (HTIMEL/H). */
#define REG_HTIME    _SNES_REG16(0x4207)
/* @reg16 VTIME $4209 W  16-bit access alias for the V IRQ position (VTIMEL/H). */
#define REG_VTIME    _SNES_REG16(0x4209)

/* ---- Misc control ---- */

/* @reg MEMSEL $420D W  ROM access speed.
 * @bit  0     FASTROM  banks $80+ at 3.58 MHz (1) vs 2.68 MHz (0)
 */
#define REG_MEMSEL   _SNES_REG8(0x420D)

/* ---- Status / result read ports ---- */

/* @reg RDNMI $4210 R  NMI flag + CPU version.
 * @bit  7     NMIFLAG  v-blank NMI occurred (cleared on read)
 * @bits 3-0   VERSION  5A22 CPU version
 */
#define REG_RDNMI    _SNES_REG8(0x4210)
/* @reg TIMEUP $4211 R  IRQ flag.
 * @bit  7     IRQFLAG  H/V IRQ occurred (cleared on read)
 */
#define REG_TIMEUP   _SNES_REG8(0x4211)
/* @reg HVBJOY $4212 R  Blanking + auto-joypad status.
 * @bit  7     VBLANK   currently in v-blank
 * @bit  6     HBLANK   currently in h-blank
 * @bit  0     JOYBUSY  auto-joypad read in progress
 */
#define REG_HVBJOY   _SNES_REG8(0x4212)
/* @reg RDIO $4213 R  Programmable I/O port (input). */
#define REG_RDIO     _SNES_REG8(0x4213)
/* @reg RDDIVL $4214 R  Divide quotient, low. */
#define REG_RDDIVL   _SNES_REG8(0x4214)
/* @reg RDDIVH $4215 R  Divide quotient, high. */
#define REG_RDDIVH   _SNES_REG8(0x4215)
/* @reg RDMPYL $4216 R  Multiply product low (or divide remainder low). */
#define REG_RDMPYL   _SNES_REG8(0x4216)
/* @reg RDMPYH $4217 R  Multiply product high (or divide remainder high). */
#define REG_RDMPYH   _SNES_REG8(0x4217)
/* @reg16 RDDIV $4214 R  16-bit access alias for the divide quotient (RDDIVL/H). */
#define REG_RDDIV    _SNES_REG16(0x4214)
/* @reg16 RDMPY $4216 R  16-bit access alias for the multiply product / remainder (RDMPYL/H). */
#define REG_RDMPY    _SNES_REG16(0x4216)

/* ============================ constants ============================ */

/* NMITIMEN bits. */
#define NMITIMEN_NMI      0x80
#define NMITIMEN_IRQ_H    0x10
#define NMITIMEN_IRQ_V    0x20
#define NMITIMEN_IRQ_HV   0x30
#define NMITIMEN_AUTOJOY  0x01

/* MEMSEL. */
#define MEMSEL_FASTROM    0x01

/* RDNMI / TIMEUP / HVBJOY flags. */
#define RDNMI_FLAG        0x80
#define TIMEUP_FLAG       0x80
#define HVBJOY_VBLANK     0x80
#define HVBJOY_HBLANK     0x40
#define HVBJOY_JOYBUSY    0x01

#endif /* _SNES_CPU_H_ */
