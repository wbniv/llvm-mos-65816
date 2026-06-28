/* snesgfx — splash: a blocking title splash for the NON-snesgfx (Mode 7) demos.
 *
 * Mode 7 has only one BG, so the BG2 TitleLayer (title_layer.h) can't be used there. Instead, the
 * Mode 7 demos (blossom, mandel-display) call splash_show() ONCE — right after snes_ppu_reset_blank()
 * and BEFORE their Mode 7 / VRAM setup. It brings up a temporary BGMODE_1 + BG3 2bpp text layer,
 * shows two centred UPPERCASE lines for `frames` v-blanks, then restores force-blank, disables the
 * layers, and ZEROES the VRAM footprint it used so the caller's Mode 7 setup starts from clean VRAM
 * (important: a Mode 7 demo that only clears its tilemap would otherwise read this splash's bytes as
 * char-plane garbage). Self-contained: writes its own VRAM (font + tilemap) and CGRAM in force-blank,
 * and manages NMITIMEN for the v-blank pacing (the caller re-arms NMITIMEN after m7_show anyway).
 *
 * GATE NOTE: this adds `frames` v-blanks before the demo's render begins. Only use it where the gate's
 * read deadline has the headroom — confirm against the demo's dev/<demo>.sh frame budget. For a demo
 * with a frame-alignment-sensitive scripted-input differential (e.g. blossom), the shift can desync
 * the input replay; verify before adopting.
 *
 * Header-only (static inline). Reuses examples/snes/font8.h. */
#ifndef SNESGFX_SPLASH_H
#define SNESGFX_SPLASH_H

#include <snes.h>
#include "../font8.h"

#define SPLASH_CHR_WORD 0x0000u
#define SPLASH_MAP_WORD 0x4000u
#define SPLASH_COLS     32u
#define SPLASH_CLEAR_WORDS 0x4400u   /* footprint to zero on exit: font@0 + tilemap@0x4000..0x4400 */

static void _splash_line(uint16_t row, const char *s) {
  if (!s) return;
  uint8_t len = 0;
  for (const char *p = s; *p && len < SPLASH_COLS; p++) len++;
  uint8_t col = (uint8_t)((SPLASH_COLS - len) / 2u);
  snes_vram_addr((uint16_t)(SPLASH_MAP_WORD + row * SPLASH_COLS + col));
  for (const char *p = s; *p && col < SPLASH_COLS; p++, col++) {
    uint8_t ch = (uint8_t)*p;
    uint16_t tile = (ch >= FONT8_FIRST && ch < (uint8_t)(FONT8_FIRST + FONT8_N))
                      ? (uint16_t)(ch - FONT8_FIRST) : 0u;
    REG_VMDATA = tile;
  }
}

/* Show `l0`/`l1` centred for `frames` v-blanks. Assumes force-blank on entry (caller just reset). */
static void splash_show(const char *l0, const char *l1, uint16_t frames) {
  REG_BGMODE  = BGMODE_1;
  REG_BG3SC   = SNES_BGSC(SPLASH_MAP_WORD, 0);
  REG_BG34NBA = (uint8_t)((SPLASH_CHR_WORD >> 12) & 0x0Fu);   /* BG3 char base (low nibble) */

  /* CGRAM palette 0: colour 0 black (backdrop), colour 1 white (ink). */
  REG_CGADD  = 0;
  REG_CGDATA = 0x00; REG_CGDATA = 0x00;
  REG_CGDATA = 0xFF; REG_CGDATA = 0x7F;

  /* 2bpp font at BG3 tile 0. */
  snes_vram_addr(SPLASH_CHR_WORD);
  for (uint16_t i = 0; i < (uint16_t)FONT8_N * 8u; i++) REG_VMDATA = FONT8[i];

  /* Clear the tilemap to the space glyph (tile 0), then lay the centred lines. */
  snes_vram_addr(SPLASH_MAP_WORD);
  for (uint16_t i = 0; i < (uint16_t)(SPLASH_COLS * 32u); i++) REG_VMDATA = 0u;
  _splash_line(12u, l0);
  _splash_line(14u, l1);

  REG_TM       = TM_BG3;
  REG_NMITIMEN = NMITIMEN_NMI;
  REG_INIDISP  = INIDISP_ON;                 /* screen on */
  while (frames--) { (void)REG_RDNMI; snes_wait_vblank(); }

  /* Restore force-blank, disable layers, and wipe the VRAM footprint for the caller's setup. */
  REG_INIDISP = 0x80;
  REG_TM      = 0;
  snes_vram_addr(0x0000);
  for (uint16_t i = 0; i < SPLASH_CLEAR_WORDS; i++) REG_VMDATA = 0u;
}

#endif /* SNESGFX_SPLASH_H */
