#ifndef _SNES_H_
#define _SNES_H_

/* SNES (Super Famicom) hardware HAL — umbrella header.
 *
 * Pulls in the full CPU-visible register map, split by subsystem. Including this
 * header gives you everything (the historical `#include <snes.h>` surface); to
 * keep a translation unit lean, include just the subsystem header(s) you need —
 * each is independently usable and idempotent.
 *
 *   snes_ppu.h     PPU:    display, BG, OAM, VRAM, Mode 7, CGRAM, windows,
 *                          color math, read ports ($2100..$213F) + gfx helpers
 *   snes_dma.h     DMA:    8 GP-DMA/HDMA channels ($43x0..$43xB) + MDMAEN/HDMAEN
 *   snes_cpu.h     CPU IO: interrupts, hw multiply/divide, IRQ timers, FastROM
 *   snes_joypad.h  Input:  auto-read pads JOY1..4 + serial $4016/$4017
 *   snes_apu.h     Audio:  the four APU mailbox ports ($2140..$2143)
 *   snes_wram.h    WRAM:   the WMDATA/WMADD access window ($2180..$2183)
 *
 * The machine runs in 65816 native mode after crt0's XCE (so absolute addressing
 * reaches these bank-$00 registers, and under +mos-a16 the accumulator is 16-bit).
 * The 65816 instruction-set / 8<->16-bit mode reference is a separate document:
 * docs/refs/65816/65816-reference.md. The full annotated register map renders to
 * docs/refs/snes-hardware/snes-register-map.md (generated from these headers). */

#include "snes_mmio.h"
#include "snes_ppu.h"
#include "snes_dma.h"
#include "snes_cpu.h"
#include "snes_joypad.h"
#include "snes_apu.h"
#include "snes_wram.h"

#endif /* _SNES_H_ */
