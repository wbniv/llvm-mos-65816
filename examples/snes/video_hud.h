/* SVX2 video dashboard: Mode 7 video on scanlines 0..191, Mode 1 BG3 text on 192..223. */
#ifndef VIDEO_HUD_H
#define VIDEO_HUD_H
#include <snes.h>
#include "font8.h"

#define VIDEO_HUD_MAP_WORD 0x4000u
#define VIDEO_HUD_CHR_WORD 0x5000u
#define VIDEO_HUD_COLS 32u
#define VIDEO_HUD_FIRST_ROW 24u

static const uint8_t video_hud_bgmode[] = {
  127u, BGMODE_7, 65u, BGMODE_7, 32u, BGMODE_1, 0u
};
static const uint8_t video_hud_tm[] = {
  127u, TM_BG1, 65u, TM_BG1, 32u, TM_BG3, 0u
};

static inline void video_hud_words(uint16_t dst, const uint16_t *src, uint16_t count) {
  REG_VMAIN = VMAIN_INC_HIGH_1;
  REG_VMADD = dst;
  while (count--) REG_VMDATA = *src++;
}

static inline void video_hud_text(uint8_t row, uint8_t col, const char *text) {
  REG_VMAIN = VMAIN_INC_HIGH_1;
  REG_VMADD = (uint16_t)(VIDEO_HUD_MAP_WORD + (uint16_t)row * VIDEO_HUD_COLS + col);
  while (*text) {
    uint8_t ch = (uint8_t)*text++;
    REG_VMDATA = (ch >= FONT8_FIRST && ch < FONT8_FIRST + FONT8_N)
        ? (uint16_t)(ch - FONT8_FIRST) : 0u;
  }
}

static inline void video_hud_begin(void) {
  uint16_t i;
  REG_BG3SC = SNES_BGSC(VIDEO_HUD_MAP_WORD, 0);
  REG_BG34NBA = (uint8_t)((VIDEO_HUD_CHR_WORD >> 12) & 0x0fu);
  REG_BG3HOFS = 0u; REG_BG3HOFS = 0u;
  REG_BG3VOFS = 0u; REG_BG3VOFS = 0u;
  video_hud_words(VIDEO_HUD_CHR_WORD, FONT8, FONT8_N * 8u);
  REG_VMAIN = VMAIN_INC_HIGH_1;
  REG_VMADD = VIDEO_HUD_MAP_WORD;
  for (i = 0; i != VIDEO_HUD_COLS * 32u; ++i) REG_VMDATA = 0u;

  REG_DMAP1 = 0u; REG_BBAD1 = 0x05u;
  REG_A1T1L = (uint8_t)(uintptr_t)video_hud_bgmode;
  REG_A1T1H = (uint8_t)((uintptr_t)video_hud_bgmode >> 8);
  REG_A1B1 = 0u;
  REG_DMAP2 = 0u; REG_BBAD2 = 0x2cu;
  REG_A1T2L = (uint8_t)(uintptr_t)video_hud_tm;
  REG_A1T2H = (uint8_t)((uintptr_t)video_hud_tm >> 8);
  REG_A1B2 = 0u;
  REG_HDMAEN = 0x06u;
}
#endif
