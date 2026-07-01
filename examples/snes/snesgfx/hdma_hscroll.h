/* snesgfx — hdma_hscroll: a tiny per-scanline horizontal-scroll HDMA helper.
 *
 * Streams a write-twice BGnHOFS register ($210D/$210F/$2111/$2113) per scanline so different
 * vertical *bands* of ONE background get independent horizontal scroll. The motivating use is two
 * text lines sharing a single BG, each pixel-centred independently: tilemap placement only centres
 * to the 8 px tile grid, so an odd-width line sits 4 px off true centre, and two lines of different
 * parity need different nudges — which one shared BGnHOFS cannot give. HDMA can.
 *
 * Transfer mode 2 (one register, write-twice) feeds the 16-bit scroll latch (low byte then high
 * byte) from the table. The table uses write-once-and-hold runs (count byte bit 7 = 0): the value is
 * latched on the first scanline of the run and held for the rest. A 0 count byte ends the table.
 *
 *   table = [ split, lo0,hi0,  (224-split), lo1,hi1,  0 ]
 *           |__ band A: scanlines [0,split)  __|  |__ band B: [split,224) __|
 *
 * The table holds runtime-computed offsets, so it lives in WRAM. Low-WRAM bss ($0200-$1FFF) is
 * mirrored at bank 0 $0000-$1FFF, so arm with A-bus source bank 0 (as hud.h does for ROM tables).
 *
 * Header-only (static inline). Does NOT touch HDMAEN — the caller enables bit (1<<chan) when ready
 * and clears it when done (HDMAEN $420C is write-only, so it cannot be read-modify-written here). */
#ifndef SNESGFX_HDMA_HSCROLL_H
#define SNESGFX_HDMA_HSCROLL_H

#include <snes.h>

/* B-bus destination low bytes for the four BG horizontal-scroll latches (for hscroll2_arm `reg_lo`). */
#define HSCROLL_BG1HOFS  0x0Du
#define HSCROLL_BG2HOFS  0x0Fu
#define HSCROLL_BG3HOFS  0x11u
#define HSCROLL_BG4HOFS  0x13u

/* B-bus destination low bytes for the four BG vertical-scroll latches. */
#define VSCROLL_BG1VOFS  0x0Eu
#define VSCROLL_BG2VOFS  0x10u
#define VSCROLL_BG3VOFS  0x12u
#define VSCROLL_BG4VOFS  0x14u

/* A 2-band horizontal-scroll HDMA table (7 bytes incl. the 0 terminator). */
typedef struct { uint8_t tab[7]; } HScroll2;

/* Build the table: scroll `top` for scanlines [0,`split`), scroll `bot` for [`split`,224).
   `top`/`bot` are 10-bit BGnHOFS values (only the low 10 bits matter); −4 == shift content 4 px
   right == 0x3FC in the latch. `split` is the scanline where band B begins (1..127 for a single
   write-once run on each side; 112 cleanly separates two title lines at rows 12 and 14). */
static inline void hscroll2_build(HScroll2 *h, uint8_t split, int16_t top, int16_t bot) {
  h->tab[0] = split;                                                   /* band A length */
  h->tab[1] = (uint8_t)(uint16_t)top;  h->tab[2] = (uint8_t)((uint16_t)top >> 8);
  h->tab[3] = (uint8_t)(224u - split);                                 /* band B length */
  h->tab[4] = (uint8_t)(uint16_t)bot;  h->tab[5] = (uint8_t)((uint16_t)bot >> 8);
  h->tab[6] = 0;                                                       /* terminator */
}

/* Arm HDMA channel `chan` to stream `h->tab` into the write-twice scroll register whose B-bus low
   byte is `reg_lo` (one of the HSCROLL_BGnHOFS macros). The table must be in bank 0 (low WRAM/ROM).
   Caller then sets REG_HDMAEN |= (1<<chan) to start it and clears that bit to stop. */
static inline void hscroll2_arm(uint8_t chan, uint8_t reg_lo, const HScroll2 *h) {
  volatile uint8_t *c = (volatile uint8_t *)(uintptr_t)(0x4300u + (uint16_t)chan * 0x10u);
  c[0] = 0x02;                              /* DMAPx: A->B, transfer mode 2 (1 reg, write twice) */
  c[1] = reg_lo;                            /* BBADx: B-bus destination low byte ($21xx)         */
  c[2] = (uint8_t)(uintptr_t)h->tab;        /* A1TxL: table address low                          */
  c[3] = (uint8_t)((uintptr_t)h->tab >> 8); /* A1TxH: table address high                         */
  c[4] = 0x00;                              /* A1Bx:  source bank 0 (low-WRAM mirror)            */
}

#endif /* SNESGFX_HDMA_HSCROLL_H */
