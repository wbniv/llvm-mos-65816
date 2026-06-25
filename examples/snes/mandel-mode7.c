// #321 Track 3b — a BIG, per-pixel Mandelbrot on the SNES: computed into HIGH WRAM via
// #320 far stores, displayed crisply via Mode 7, uploaded to VRAM by DMA.
//
// Why this exists / what it exercises:
//   * 128x128 escape buffer = 16 KiB — too big for low WRAM (8 KiB), so it lives at
//     $7E2000 (high WRAM) and is filled via far stores (the motivating far-pointer use
//     case; cf. Track 3a / k_mandel_far.c).
//   * Mode 7 character data is LINEAR 8bpp (1 byte/pixel, no bitplanes) with a 256-tile
//     cap, so a 128x128 image is exactly 16x16 = 256 tiles — the natural per-pixel path
//     (vs the fat-pixel BG of Track 2). We show it at 2x zoom so 128x128 fills the screen.
//   * The Mode 7 VRAM build + 32 KiB DMA + register setup are shared with the interactive
//     demo via examples/snes/mode7.h (this file is the regression guard for that refactor).
//
// +mos-a16-only (far pointers are 32-bit values). corpus_result carries the CRC of the
// raster buffer (far loads) as the proof channel. Capture: dev/run.sh mandel-mode7.
// Build with -DMANDEL_TESTPAT to fill a fast synthetic pattern (display de-risk) instead
// of the slow Mandelbrot. See docs/plans/2026-06-24-snes-mandelbrot-beefy-demo.md (Track 3).
#include <snes.h>
#include "mode7.h"
#include "../65816/mandel.h"

#define W 128            // image width  (must equal M7_W; dev/mandel-mode7.sh awk's this literal)
#define H 128            // image height (must equal M7_H)
#define DN 12            // max iterations. 8bpp indexes CGRAM directly; kept modest because
                         // 128x128 = 16384 cells of software 32-bit fixed-point is heavy
                         // (~thousands of frames of emulated time even at this N).

// High-WRAM raster escape buffer (reachable only via 24-bit/far addressing). The interleaved
// Mode 7 staging image is m7_vbuf (mode7.h, $7E6000).
static M7_FAR uint8_t *const fb = (M7_FAR uint8_t *)0x7E2000u;  // 16 KiB

volatile uint16_t corpus_result;     // near — CRC of fb, the proof channel

// Fill the raster buffer (far stores). Test pattern is instant; the real kernel is slow.
static void fill(void) {
#ifdef MANDEL_TESTPAT
  for (uint16_t y = 0; y < H; y++)
    for (uint16_t x = 0; x < W; x++)
      fb[y * W + x] = (uint8_t)(((x >> 2) ^ (y >> 2)) & 0x1F);  // reveals tiling/orientation
#else
  int16_t dre = (int16_t)(MANDEL_REW / W);
  int16_t dim = (int16_t)(MANDEL_IMW / H);
  for (uint16_t y = 0; y < H; y++) {
    int16_t ci = (int16_t)(MANDEL_IM0 + (int16_t)y * dim);
    for (uint16_t x = 0; x < W; x++) {
      int16_t cr = (int16_t)(MANDEL_RE0 + (int16_t)x * dre);
      fb[y * W + x] = mandel_cell(cr, ci, DN);                  // FAR STORE
    }
  }
#endif
}

// CRC16-CCITT over the raster buffer via far loads (== host reference over the same grid).
static uint16_t crc_fb(void) {
  uint16_t crc = 0xFFFF;
  for (uint16_t k = 0; k < (uint16_t)(W * H); k++) {
    crc ^= (uint16_t)((uint16_t)fb[k] << 8);                    // FAR LOAD
    for (uint8_t b = 0; b < 8; b++)
      crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021)
                           : (uint16_t)(crc << 1);
  }
  return crc;
}

// CGRAM: escape count -> colour (8bpp indexes CGRAM directly), 0..DN.
static void load_palette(void) {
  REG_CGADD = 0;
  for (uint16_t n = 0; n <= DN; n++) {
    uint8_t r, g, b;
    mandel_palette((uint8_t)n, DN, &r, &g, &b);
    uint16_t c = SNES_RGB(r, g, b);
    REG_CGDATA = (uint8_t)(c & 0xFF);
    REG_CGDATA = (uint8_t)(c >> 8);
  }
}

// De-linearize fb (far) into the interleaved Mode 7 image — shared math from mode7.h.
M7_DEFINE_BUILD_VBUF(build_vbuf, M7_FAR)

int main(void) {
  snes_ppu_reset_blank();              // force-blank + zero PPU control regs (determinism)
  fill();
  corpus_result = crc_fb();
  load_palette();
  build_vbuf(fb);                      // far source -> m7_vbuf
  m7_dma_vbuf_to_vram();

  m7_begin();                          // Mode 7, BG1 main screen
  m7_set_matrix(0x0080, 0x0000, 0x0000, 0x0080);   // 2x zoom (screen steps 0.5 source), identity
  m7_set_center(0, 0);                 // rotation centre (0,0)
  m7_set_scroll(0, 0);                 // Mode 7 scroll = 0
  m7_show();                           // release force-blank
  for (;;) {}
}
