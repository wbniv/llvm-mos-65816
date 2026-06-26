// examples/snes/hud.h — split-screen HUD: a Mode 7 plot box with tiled BG3 text bars top & bottom.
//
// The screen is carved by an HDMA mode-switch (the F-Zero / Super Mario Kart split): BGMODE ($2105)
// and TM ($212C) are streamed per-scanline so the top and bottom strips render in Mode 1 — a normal
// tiled BG3 2bpp text layer — while the middle band stays Mode 7 (the attractor). Text is a tiled BG,
// not sprites: no per-scanline OBJ limit, and drawing a string is a tilemap poke (hud_text). First
// HDMA + BG-text helper in the repo; a thin layer over snes.h, mirroring mode7.h.
//
// VRAM: Mode 7 already owns words $0000-$3FFF (tilemap = low bytes, chr = high bytes); the HUD lives in
// the free upper half — BG3 tilemap at word $4000, the 2bpp font at word $5000. CGRAM: the BG3 text
// uses palette 0, colour 1 = entry 1 (the demo reserves entry 1, off the attractor's cycle).
#ifndef HUD_H
#define HUD_H
#include <snes.h>
#include "font8.h"

#define HUD_TILEMAP_WORD 0x4000u  // BG3 32x32 tilemap base (-> BG3SC, $400-word units)
#define HUD_CHR_WORD     0x5000u  // BG3 2bpp char base     (-> BG34NBA nibble, $1000-word units)
#define HUD_COLS         32       // 256 px / 8
#define HUD_SCREEN_ROWS  28       // visible tile-rows (224 / 8) — NOT the 32-row tilemap height
#define HUD_BAR_ROWS     2        // tile-rows per bar (16 scanlines)
#define HUD_BAR_L        (HUD_BAR_ROWS * 8)            // scanlines per bar
#define HUD_PLOT_L       (224 - 2 * HUD_BAR_L)         // Mode 7 plot-band scanlines (192)
#define HUD_TOP_ROW      0                              // value bar   -> BG3 rows 0..(BAR-1)
#define HUD_BOT_ROW      (HUD_SCREEN_ROWS - HUD_BAR_ROWS)  // control bar -> rows 26..27

// HDMA line tables (ROM consts; A-bus source bank 0 in this single-bank LoROM). Direct, 1 byte/run;
// the count byte's repeat-bit 0 => write the value once and HOLD for `count` scanlines; 0 ends the
// table. Layout HUD_BAR_L / HUD_PLOT_L / HUD_BAR_L = 224; HUD_PLOT_L (192) > 127 so the plot run is
// split 127 + remainder.
static const uint8_t hud_bgmode_tab[] = {
  HUD_BAR_L, BGMODE_1,  127, BGMODE_7,  HUD_PLOT_L - 127, BGMODE_7,  HUD_BAR_L, BGMODE_1,  0 };
static const uint8_t hud_tm_tab[] = {
  HUD_BAR_L, TM_BG3,    127, TM_BG1,    HUD_PLOT_L - 127, TM_BG1,    HUD_BAR_L, TM_BG3,    0 };

// Write `nwords` from a near array to VRAM starting at word `dst` (force-blank / vblank only).
static inline void hud_vram_words(uint16_t dst, const uint16_t *src, uint16_t nwords) {
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = dst;
  for (uint16_t i = 0; i < nwords; i++) REG_VMDATA = src[i];
}

// Load the 2bpp font (64 glyphs x 8 words) into BG3 char VRAM. Force-blank / vblank only.
static inline void hud_load_font(void) { hud_vram_words(HUD_CHR_WORD, FONT8, FONT8_N * 8); }

// Draw NUL-terminated ASCII `s` into the BG3 tilemap at (tile-row `row`, start column `col`). Each
// tilemap entry = tile# | pal<<10; tile# = ch - FONT8_FIRST (palette 0, so ink = CGRAM entry 1). The
// auto-increment writes consecutive columns of one row — keep col + strlen(s) <= HUD_COLS. Force-blank
// or vblank only (it pokes VRAM).
static inline void hud_text(uint8_t row, uint8_t col, const char *s) {
  REG_VMAIN = VMAIN_INC_HIGH_1;
  REG_VMADD = (uint16_t)(HUD_TILEMAP_WORD + (uint16_t)row * HUD_COLS + col);
  for (; *s; s++) {
    uint8_t ch = (uint8_t)*s;
    REG_VMDATA = (ch >= FONT8_FIRST && ch < FONT8_FIRST + FONT8_N) ? (uint16_t)(ch - FONT8_FIRST) : 0;
  }
}

// Blank `n` tilemap entries from (row, col) — clears a field before redrawing a shorter value.
static inline void hud_blank(uint8_t row, uint8_t col, uint8_t n) {
  REG_VMAIN = VMAIN_INC_HIGH_1;
  REG_VMADD = (uint16_t)(HUD_TILEMAP_WORD + (uint16_t)row * HUD_COLS + col);
  for (uint8_t i = 0; i < n; i++) REG_VMDATA = 0x0000;
}

// Arm HDMA channel 1 -> BGMODE ($2105) and channel 2 -> TM ($212C) from the line tables above.
static inline void hud_arm_hdma(void) {
  REG_DMAP1 = 0x00; REG_BBAD1 = 0x05;   // direct, 1 byte/write, dest $2105 (BGMODE)
  REG_A1T1L = (uint8_t)(uintptr_t)hud_bgmode_tab; REG_A1T1H = (uint8_t)((uintptr_t)hud_bgmode_tab >> 8);
  REG_A1B1  = 0x00;
  REG_DMAP2 = 0x00; REG_BBAD2 = 0x2C;   // direct, 1 byte/write, dest $212C (TM)
  REG_A1T2L = (uint8_t)(uintptr_t)hud_tm_tab; REG_A1T2H = (uint8_t)((uintptr_t)hud_tm_tab >> 8);
  REG_A1B2  = 0x00;
  REG_HDMAEN = 0x06;                     // arm channels 1 + 2 (GP-DMA stays on channel 0)
}

// Set up the BG3 text layer + the screen split. Call once in force-blank, after the Mode 7 setup and
// before m7_show(). The caller then draws field text with hud_text().
static inline void hud_begin(void) {
  REG_BG3SC   = SNES_BGSC(HUD_TILEMAP_WORD, 0);           // 32x32 map at word $4000
  REG_BG34NBA = (uint8_t)((HUD_CHR_WORD >> 12) & 0x0F);   // BG3 char base nibble = 5 ($5000)
  REG_BG3HOFS = 0; REG_BG3HOFS = 0;                       // scroll (0,0) — write twice
  REG_BG3VOFS = 0; REG_BG3VOFS = 0;

  hud_load_font();
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = HUD_TILEMAP_WORD;
  for (uint16_t i = 0; i < (uint16_t)HUD_COLS * 32; i++) REG_VMDATA = 0x0000;   // blank (tile 0 = space)

  hud_arm_hdma();
}

#endif /* HUD_H */
