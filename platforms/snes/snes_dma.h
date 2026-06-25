#ifndef _SNES_DMA_H_
#define _SNES_DMA_H_

/* SNES DMA / HDMA controller — 8 channels at $43x0..$43xB (channel x), plus the
 * two enable/trigger registers MDMAEN ($420B) and HDMAEN ($420C) that live in the
 * CPU I/O block but belong functionally to DMA.
 *
 * General-purpose DMA: set up a channel ($43x0..$43x6), point VMADD/CGADD/OAMADD
 * at the destination, then write MDMAEN with the channel's bit — the CPU stalls
 * until the transfer completes. DMA touches VRAM/CGRAM/OAM, so do it in
 * force-blank or v-blank (same access-window rule as the PPU). HDMA (per-scanline
 * register streaming) is a different mechanism enabled via HDMAEN; the $43x7..
 * $43xA registers are HDMA-only.
 *
 * Bit-field facts: nocash "fullsnes", SNESdev wiki (docs/refs/snes-hardware/SOURCES.md). */

#include "snes_mmio.h"

/* ---- Enable / trigger (in the $42xx CPU I/O block) ---- */

/* @reg MDMAEN $420B W  General-purpose DMA enable + trigger; CPU stalls until done.
 * @bit  7     CH7      start GP-DMA on channel 7
 * @bit  6     CH6      start GP-DMA on channel 6
 * @bit  5     CH5      start GP-DMA on channel 5
 * @bit  4     CH4      start GP-DMA on channel 4
 * @bit  3     CH3      start GP-DMA on channel 3
 * @bit  2     CH2      start GP-DMA on channel 2
 * @bit  1     CH1      start GP-DMA on channel 1
 * @bit  0     CH0      start GP-DMA on channel 0
 */
#define REG_MDMAEN   _SNES_REG8(0x420B)
/* @reg HDMAEN $420C W  HDMA enable (per-scanline); bit n = arm channel n for HDMA.
 * @bits 7-0   CH       one bit per channel (bit n arms channel n for HDMA)
 */
#define REG_HDMAEN   _SNES_REG8(0x420C)

/* ---- Channel 0 (fully documented; channels 1..7 are identical at $43n_) ---- */

/* @reg DMAP0 $4300 RW  Channel 0 transfer parameters.
 * @bit  7     DIR      direction (0 = A-bus->B-bus / CPU->PPU, 1 = B->A)
 * @bit  6     INDIRECT HDMA indirect addressing (HDMA only)
 * @bits 4-3   STEP     A-bus address step, GP-DMA (0 = +1, 1 = fixed, 2 = -1, 3 = fixed)
 * @bits 2-0   UNIT     transfer unit (0:1b 1reg; 1:2b B,B+1; 2:1b x2; 3:2w B,B,B+1,B+1; 4:4b B..B+3)
 */
#define REG_DMAP0    _SNES_REG8(0x4300)
/* @reg BBAD0 $4301 RW  Channel 0 B-bus destination (low byte of $21xx, e.g. $18 -> VMDATA). */
#define REG_BBAD0    _SNES_REG8(0x4301)
/* @reg A1T0L $4302 RW  Channel 0 A-bus source address, low byte. */
#define REG_A1T0L    _SNES_REG8(0x4302)
/* @reg A1T0H $4303 RW  Channel 0 A-bus source address, high byte. */
#define REG_A1T0H    _SNES_REG8(0x4303)
/* @reg A1B0 $4304 RW  Channel 0 A-bus source bank. */
#define REG_A1B0     _SNES_REG8(0x4304)
/* @reg DAS0L $4305 RW  Channel 0 byte count low (GP-DMA) / HDMA indirect addr low. 0 count = 65536. */
#define REG_DAS0L    _SNES_REG8(0x4305)
/* @reg DAS0H $4306 RW  Channel 0 byte count high / HDMA indirect addr high. */
#define REG_DAS0H    _SNES_REG8(0x4306)
/* @reg DASB0 $4307 RW  Channel 0 HDMA indirect address bank (HDMA only). */
#define REG_DASB0    _SNES_REG8(0x4307)
/* @reg A2A0L $4308 RW  Channel 0 HDMA table current address, low (HDMA only). */
#define REG_A2A0L    _SNES_REG8(0x4308)
/* @reg A2A0H $4309 RW  Channel 0 HDMA table current address, high (HDMA only). */
#define REG_A2A0H    _SNES_REG8(0x4309)
/* @reg NTRL0 $430A RW  Channel 0 HDMA line counter (HDMA only). */
#define REG_NTRL0    _SNES_REG8(0x430A)

/* ---- Channel 1 ($4310) ---- */
/* @reg DMAP1 $4310 RW  Channel 1 transfer parameters (see DMAP0). */
#define REG_DMAP1    _SNES_REG8(0x4310)
/* @reg BBAD1 $4311 RW  Channel 1 B-bus destination. */
#define REG_BBAD1    _SNES_REG8(0x4311)
/* @reg A1T1L $4312 RW  Channel 1 A-bus source low. */
#define REG_A1T1L    _SNES_REG8(0x4312)
/* @reg A1T1H $4313 RW  Channel 1 A-bus source high. */
#define REG_A1T1H    _SNES_REG8(0x4313)
/* @reg A1B1 $4314 RW  Channel 1 A-bus source bank. */
#define REG_A1B1     _SNES_REG8(0x4314)
/* @reg DAS1L $4315 RW  Channel 1 byte count low / HDMA indirect low. */
#define REG_DAS1L    _SNES_REG8(0x4315)
/* @reg DAS1H $4316 RW  Channel 1 byte count high / HDMA indirect high. */
#define REG_DAS1H    _SNES_REG8(0x4316)
/* @reg DASB1 $4317 RW  Channel 1 HDMA indirect bank. */
#define REG_DASB1    _SNES_REG8(0x4317)
/* @reg A2A1L $4318 RW  Channel 1 HDMA table address low. */
#define REG_A2A1L    _SNES_REG8(0x4318)
/* @reg A2A1H $4319 RW  Channel 1 HDMA table address high. */
#define REG_A2A1H    _SNES_REG8(0x4319)
/* @reg NTRL1 $431A RW  Channel 1 HDMA line counter. */
#define REG_NTRL1    _SNES_REG8(0x431A)

/* ---- Channel 2 ($4320) ---- */
/* @reg DMAP2 $4320 RW  Channel 2 transfer parameters (see DMAP0). */
#define REG_DMAP2    _SNES_REG8(0x4320)
/* @reg BBAD2 $4321 RW  Channel 2 B-bus destination. */
#define REG_BBAD2    _SNES_REG8(0x4321)
/* @reg A1T2L $4322 RW  Channel 2 A-bus source low. */
#define REG_A1T2L    _SNES_REG8(0x4322)
/* @reg A1T2H $4323 RW  Channel 2 A-bus source high. */
#define REG_A1T2H    _SNES_REG8(0x4323)
/* @reg A1B2 $4324 RW  Channel 2 A-bus source bank. */
#define REG_A1B2     _SNES_REG8(0x4324)
/* @reg DAS2L $4325 RW  Channel 2 byte count low / HDMA indirect low. */
#define REG_DAS2L    _SNES_REG8(0x4325)
/* @reg DAS2H $4326 RW  Channel 2 byte count high / HDMA indirect high. */
#define REG_DAS2H    _SNES_REG8(0x4326)
/* @reg DASB2 $4327 RW  Channel 2 HDMA indirect bank. */
#define REG_DASB2    _SNES_REG8(0x4327)
/* @reg A2A2L $4328 RW  Channel 2 HDMA table address low. */
#define REG_A2A2L    _SNES_REG8(0x4328)
/* @reg A2A2H $4329 RW  Channel 2 HDMA table address high. */
#define REG_A2A2H    _SNES_REG8(0x4329)
/* @reg NTRL2 $432A RW  Channel 2 HDMA line counter. */
#define REG_NTRL2    _SNES_REG8(0x432A)

/* ---- Channel 3 ($4330) ---- */
/* @reg DMAP3 $4330 RW  Channel 3 transfer parameters (see DMAP0). */
#define REG_DMAP3    _SNES_REG8(0x4330)
/* @reg BBAD3 $4331 RW  Channel 3 B-bus destination. */
#define REG_BBAD3    _SNES_REG8(0x4331)
/* @reg A1T3L $4332 RW  Channel 3 A-bus source low. */
#define REG_A1T3L    _SNES_REG8(0x4332)
/* @reg A1T3H $4333 RW  Channel 3 A-bus source high. */
#define REG_A1T3H    _SNES_REG8(0x4333)
/* @reg A1B3 $4334 RW  Channel 3 A-bus source bank. */
#define REG_A1B3     _SNES_REG8(0x4334)
/* @reg DAS3L $4335 RW  Channel 3 byte count low / HDMA indirect low. */
#define REG_DAS3L    _SNES_REG8(0x4335)
/* @reg DAS3H $4336 RW  Channel 3 byte count high / HDMA indirect high. */
#define REG_DAS3H    _SNES_REG8(0x4336)
/* @reg DASB3 $4337 RW  Channel 3 HDMA indirect bank. */
#define REG_DASB3    _SNES_REG8(0x4337)
/* @reg A2A3L $4338 RW  Channel 3 HDMA table address low. */
#define REG_A2A3L    _SNES_REG8(0x4338)
/* @reg A2A3H $4339 RW  Channel 3 HDMA table address high. */
#define REG_A2A3H    _SNES_REG8(0x4339)
/* @reg NTRL3 $433A RW  Channel 3 HDMA line counter. */
#define REG_NTRL3    _SNES_REG8(0x433A)

/* ---- Channel 4 ($4340) ---- */
/* @reg DMAP4 $4340 RW  Channel 4 transfer parameters (see DMAP0). */
#define REG_DMAP4    _SNES_REG8(0x4340)
/* @reg BBAD4 $4341 RW  Channel 4 B-bus destination. */
#define REG_BBAD4    _SNES_REG8(0x4341)
/* @reg A1T4L $4342 RW  Channel 4 A-bus source low. */
#define REG_A1T4L    _SNES_REG8(0x4342)
/* @reg A1T4H $4343 RW  Channel 4 A-bus source high. */
#define REG_A1T4H    _SNES_REG8(0x4343)
/* @reg A1B4 $4344 RW  Channel 4 A-bus source bank. */
#define REG_A1B4     _SNES_REG8(0x4344)
/* @reg DAS4L $4345 RW  Channel 4 byte count low / HDMA indirect low. */
#define REG_DAS4L    _SNES_REG8(0x4345)
/* @reg DAS4H $4346 RW  Channel 4 byte count high / HDMA indirect high. */
#define REG_DAS4H    _SNES_REG8(0x4346)
/* @reg DASB4 $4347 RW  Channel 4 HDMA indirect bank. */
#define REG_DASB4    _SNES_REG8(0x4347)
/* @reg A2A4L $4348 RW  Channel 4 HDMA table address low. */
#define REG_A2A4L    _SNES_REG8(0x4348)
/* @reg A2A4H $4349 RW  Channel 4 HDMA table address high. */
#define REG_A2A4H    _SNES_REG8(0x4349)
/* @reg NTRL4 $434A RW  Channel 4 HDMA line counter. */
#define REG_NTRL4    _SNES_REG8(0x434A)

/* ---- Channel 5 ($4350) ---- */
/* @reg DMAP5 $4350 RW  Channel 5 transfer parameters (see DMAP0). */
#define REG_DMAP5    _SNES_REG8(0x4350)
/* @reg BBAD5 $4351 RW  Channel 5 B-bus destination. */
#define REG_BBAD5    _SNES_REG8(0x4351)
/* @reg A1T5L $4352 RW  Channel 5 A-bus source low. */
#define REG_A1T5L    _SNES_REG8(0x4352)
/* @reg A1T5H $4353 RW  Channel 5 A-bus source high. */
#define REG_A1T5H    _SNES_REG8(0x4353)
/* @reg A1B5 $4354 RW  Channel 5 A-bus source bank. */
#define REG_A1B5     _SNES_REG8(0x4354)
/* @reg DAS5L $4355 RW  Channel 5 byte count low / HDMA indirect low. */
#define REG_DAS5L    _SNES_REG8(0x4355)
/* @reg DAS5H $4356 RW  Channel 5 byte count high / HDMA indirect high. */
#define REG_DAS5H    _SNES_REG8(0x4356)
/* @reg DASB5 $4357 RW  Channel 5 HDMA indirect bank. */
#define REG_DASB5    _SNES_REG8(0x4357)
/* @reg A2A5L $4358 RW  Channel 5 HDMA table address low. */
#define REG_A2A5L    _SNES_REG8(0x4358)
/* @reg A2A5H $4359 RW  Channel 5 HDMA table address high. */
#define REG_A2A5H    _SNES_REG8(0x4359)
/* @reg NTRL5 $435A RW  Channel 5 HDMA line counter. */
#define REG_NTRL5    _SNES_REG8(0x435A)

/* ---- Channel 6 ($4360) ---- */
/* @reg DMAP6 $4360 RW  Channel 6 transfer parameters (see DMAP0). */
#define REG_DMAP6    _SNES_REG8(0x4360)
/* @reg BBAD6 $4361 RW  Channel 6 B-bus destination. */
#define REG_BBAD6    _SNES_REG8(0x4361)
/* @reg A1T6L $4362 RW  Channel 6 A-bus source low. */
#define REG_A1T6L    _SNES_REG8(0x4362)
/* @reg A1T6H $4363 RW  Channel 6 A-bus source high. */
#define REG_A1T6H    _SNES_REG8(0x4363)
/* @reg A1B6 $4364 RW  Channel 6 A-bus source bank. */
#define REG_A1B6     _SNES_REG8(0x4364)
/* @reg DAS6L $4365 RW  Channel 6 byte count low / HDMA indirect low. */
#define REG_DAS6L    _SNES_REG8(0x4365)
/* @reg DAS6H $4366 RW  Channel 6 byte count high / HDMA indirect high. */
#define REG_DAS6H    _SNES_REG8(0x4366)
/* @reg DASB6 $4367 RW  Channel 6 HDMA indirect bank. */
#define REG_DASB6    _SNES_REG8(0x4367)
/* @reg A2A6L $4368 RW  Channel 6 HDMA table address low. */
#define REG_A2A6L    _SNES_REG8(0x4368)
/* @reg A2A6H $4369 RW  Channel 6 HDMA table address high. */
#define REG_A2A6H    _SNES_REG8(0x4369)
/* @reg NTRL6 $436A RW  Channel 6 HDMA line counter. */
#define REG_NTRL6    _SNES_REG8(0x436A)

/* ---- Channel 7 ($4370) ---- */
/* @reg DMAP7 $4370 RW  Channel 7 transfer parameters (see DMAP0). */
#define REG_DMAP7    _SNES_REG8(0x4370)
/* @reg BBAD7 $4371 RW  Channel 7 B-bus destination. */
#define REG_BBAD7    _SNES_REG8(0x4371)
/* @reg A1T7L $4372 RW  Channel 7 A-bus source low. */
#define REG_A1T7L    _SNES_REG8(0x4372)
/* @reg A1T7H $4373 RW  Channel 7 A-bus source high. */
#define REG_A1T7H    _SNES_REG8(0x4373)
/* @reg A1B7 $4374 RW  Channel 7 A-bus source bank. */
#define REG_A1B7     _SNES_REG8(0x4374)
/* @reg DAS7L $4375 RW  Channel 7 byte count low / HDMA indirect low. */
#define REG_DAS7L    _SNES_REG8(0x4375)
/* @reg DAS7H $4376 RW  Channel 7 byte count high / HDMA indirect high. */
#define REG_DAS7H    _SNES_REG8(0x4376)
/* @reg DASB7 $4377 RW  Channel 7 HDMA indirect bank. */
#define REG_DASB7    _SNES_REG8(0x4377)
/* @reg A2A7L $4378 RW  Channel 7 HDMA table address low. */
#define REG_A2A7L    _SNES_REG8(0x4378)
/* @reg A2A7H $4379 RW  Channel 7 HDMA table address high. */
#define REG_A2A7H    _SNES_REG8(0x4379)
/* @reg NTRL7 $437A RW  Channel 7 HDMA line counter. */
#define REG_NTRL7    _SNES_REG8(0x437A)

/* ============================ constants ============================ */

/* DMAP transfer direction (bit 7). */
#define DMAP_TO_PPU        0x00   /* A-bus -> B-bus (CPU/ROM/RAM -> PPU)  */
#define DMAP_FROM_PPU      0x80   /* B-bus -> A-bus (PPU -> CPU/RAM)      */
/* DMAP HDMA indirect addressing (bit 6, HDMA only). */
#define DMAP_HDMA_INDIRECT 0x40
/* DMAP A-bus address step for GP-DMA (bits 4-3). */
#define DMAP_ADDR_INC      0x00   /* +1 after each byte (the usual setting) */
#define DMAP_ADDR_FIXED    0x08   /* address held fixed                     */
#define DMAP_ADDR_DEC      0x10   /* -1 after each byte                     */
/* DMAP transfer unit / pattern (bits 2-0). */
#define DMAP_UNIT_1        0x00   /* 1 byte  -> 1 register  (B)            */
#define DMAP_UNIT_2        0x01   /* 2 bytes -> 2 registers (B, B+1)  e.g. VRAM via $2118/$2119 */
#define DMAP_UNIT_1X2      0x02   /* 1 byte  -> 1 register, written twice */
#define DMAP_UNIT_2X2      0x03   /* 4 bytes -> 2 registers (B,B,B+1,B+1) */
#define DMAP_UNIT_4        0x04   /* 4 bytes -> 4 registers (B..B+3)      */

/* Common B-bus destinations (BBADn = low byte of the $21xx port). */
#define BBAD_VMDATA        0x18   /* -> $2118/$2119 (VRAM, with DMAP_UNIT_2)   */
#define BBAD_CGDATA        0x22   /* -> $2122 (CGRAM, with DMAP_UNIT_1)        */
#define BBAD_OAMDATA       0x04   /* -> $2104 (OAM,   with DMAP_UNIT_1)        */

#endif /* _SNES_DMA_H_ */
