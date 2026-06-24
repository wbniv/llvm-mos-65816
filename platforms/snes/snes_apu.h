#ifndef _SNES_APU_H_
#define _SNES_APU_H_

/* SNES audio, as seen from the main CPU: just four communication ports.
 *
 * The audio system is a physically separate processor — an SPC700 CPU with its
 * own 64 KB RAM and an 8-voice S-DSP — that the 65816 cannot address directly.
 * ALL interaction happens through these four mailbox ports ($2140..$2143) via a
 * handshake protocol with the IPL boot ROM. The SPC700 register file and the
 * S-DSP's 128 registers are a separate address space and are intentionally NOT
 * part of this CPU-visible register map (see the hardware summary for an
 * overview).
 *
 * Facts: nocash "fullsnes", SNESdev wiki (docs/refs/snes-hardware/SOURCES.md). */

#include "snes_mmio.h"

/* @reg APUIO0 $2140 RW  APU I/O port 0 (CPU<->SPC700 mailbox; also the command port). */
#define REG_APUIO0   _SNES_REG8(0x2140)
/* @reg APUIO1 $2141 RW  APU I/O port 1. */
#define REG_APUIO1   _SNES_REG8(0x2141)
/* @reg APUIO2 $2142 RW  APU I/O port 2. */
#define REG_APUIO2   _SNES_REG8(0x2142)
/* @reg APUIO3 $2143 RW  APU I/O port 3. */
#define REG_APUIO3   _SNES_REG8(0x2143)

#endif /* _SNES_APU_H_ */
