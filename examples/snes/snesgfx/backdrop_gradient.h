/* snesgfx — backdrop_gradient: a per-scanline backdrop (CGRAM colour 0) gradient via one HDMA
 * channel.
 *
 * The classic SNES vertical-gradient technique: transfer mode 3 (two registers, write twice —
 * $2121,$2121,$2122,$2122) re-points CGRAM colour 0 per band during h-blank. Each table run writes
 * CGADD=0 twice (the second write is idempotent) and then the BGR555 colour word into CGDATA, so
 * every scanline band gets its own backdrop colour. Anywhere colour 0 shows — the area outside a
 * canvas/tilemap box, blank tiles, letterbox fills — takes the gradient; painted pixels of colours
 * 1+ are untouched.
 *
 * Declare the table `static const` in ROM with BDROP_SPAN/BDROP_END (the table is walked by the
 * HDMA engine straight off the A-bus, so it costs zero per-frame CPU and zero v-blank upload
 * budget — nothing goes through the UploadQueue):
 *
 *   static const uint8_t grad_tab[] = {
 *     BDROP_SPAN(16, 0, 1,  5),      // 16 scanlines of a near-black blue
 *     BDROP_SPAN(16, 2, 4, 16),      // …
 *     BDROP_END,
 *   };
 *   bdrop_arm(7, grad_tab);          // any channel clear of upq's GP-DMA ch0 + other HDMA users
 *   REG_HDMAEN = 0x80u;              // caller owns HDMAEN (write-only, cannot be RMW'd here)
 *
 * A run's count byte carries at most 127 lines (bit 7 selects repeat mode) — split longer bands
 * into consecutive spans. Bands should sum to 224; a short table holds the last colour for the
 * remaining scanlines (benign, usually unintended). A v-blank CGRAM upload of colour 0 (e.g. a
 * palette push at cgidx 0) never wins against an armed gradient — the engine rewrites colour 0
 * from the first band at the top of every frame — so palettes that coexist with this helper
 * should push from cgidx 1.
 *
 * Header-only (static inline). Does NOT touch HDMAEN — the caller enables bit (1<<chan) when
 * ready and clears it when done, exactly as hdma_hscroll.h's users do. ROM tables arm with A-bus
 * source bank 0 (the near-rodata mirror), same as hud.h's ROM tables. */
#ifndef SNESGFX_BACKDROP_GRADIENT_H
#define SNESGFX_BACKDROP_GRADIENT_H

#include <snes.h>

/* One gradient band: `lines` scanlines (1..127) of colour (r,g,b), 5 bits per channel. */
#define BDROP_SPAN(lines, r, g, b) (uint8_t)(lines), 0u, 0u, \
    (uint8_t)(SNES_RGB(r, g, b) & 0xFFu), (uint8_t)(SNES_RGB(r, g, b) >> 8)

/* Table terminator. */
#define BDROP_END 0u

/* Arm HDMA channel `chan` to stream `tab` (a BDROP_SPAN table, bank 0) into CGADD/CGDATA.
   Caller then sets REG_HDMAEN's (1<<chan) bit to start and clears it to stop. */
static inline void bdrop_arm(uint8_t chan, const uint8_t *tab) {
  volatile uint8_t *c = (volatile uint8_t *)(uintptr_t)(0x4300u + (uint16_t)chan * 0x10u);
  c[0] = 0x03;                              /* DMAPx: A->B, transfer mode 3 (2 regs, write twice) */
  c[1] = 0x21;                              /* BBADx: $2121 CGADD (then $2122 CGDATA twice)       */
  c[2] = (uint8_t)(uintptr_t)tab;           /* A1TxL: table address low                           */
  c[3] = (uint8_t)((uintptr_t)tab >> 8);    /* A1TxH: table address high                          */
  c[4] = 0x00;                              /* A1Bx:  source bank 0 (near-rodata / low-WRAM)      */
}

#endif /* SNESGFX_BACKDROP_GRADIENT_H */
