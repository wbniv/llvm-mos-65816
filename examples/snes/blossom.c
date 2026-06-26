// #3 Blossom — Stage 2: a static Mode 7 render of the Hopalong attractor.
//
// Accumulate K_POINTS orbit points into a 128x128 hit-count grid in high WRAM ($7E2000) via the far
// read-modify-write path (Stage 1, examples/65816/k_blossom_far.c — differentially proven). The hit
// count IS the 8bpp Mode 7 pixel value (a CGRAM index), so DISPLAY it by revealing the grid one Mode 7
// tile-row at a time: build_band() far-loads one band of the grid into a NEAR staging buffer in Mode 7
// tiled order, then dma_chr_to() DMAs that band into VRAM's character (high) bytes; an identity
// tilemap + a 256-entry CGRAM palette do the colouring. The grid's hash is parked in corpus_result
// (the boot gate == the host oracle, examples/65816/k_blossom_far.c -DHOST -DK_GATE=K_POINTS).
//
// The band reveal (far grid -> NEAR chrbuf -> DMA) keeps only ONE far pointer live per helper (the
// grid_hash idiom), sidestepping the +mos-a16 far-pointer pressure that derails a far->far whole-image
// build; it is also the per-vblank unit the Stage-3 amortised animation reuses. All compute runs
// force-blanked (slow per-pixel far work is fine for a one-time static image — the mandel-mode7 model).
// +mos-a16-only (far pointers). Capture: dev/run.sh blossom.
//
// Plan: docs/plans/2026-06-24-3-snes-blossom-on-screen-interactive-hopalong-attr.md.
#define HOP_GRID 128                              // Rung A: 16 KiB grid in $7E2000 (1:1 with display)
#define HOP_NOINLINE __attribute__((noinline))    // bound +mos-a16 pressure on the far-RMW path
#include <snes.h>
#include "mode7.h"
#include "../65816/hopalong.h"

#ifndef K_POINTS
#define K_POINTS 24000     // points to accumulate for a dense, recognizable cloud (host oracle matches)
#endif
#define TILES     16       // 128/8 — Mode 7 tiles per axis (128x128 image = 16x16 = 256 tiles)
#define ROW_BYTES 1024     // one Mode 7 tile-row of character data (16 tiles * 64 bytes)

#define FAR __attribute__((address_space(2)))
static FAR uint8_t *const grid = (FAR uint8_t *)0x7E2000u;   // 16 KiB hit grid (the 8bpp source)

HOP_DEFINE_CLEAR(grid_clear, FAR)
HOP_DEFINE_PLOT (grid_plot,  FAR)
HOP_DEFINE_HASH (grid_hash,  FAR)

// Classic params, VOLATILE so the optimizer can't fold the orbit to a constant grid.
volatile short pa = HOP_A_CLASSIC, pb = HOP_B_CLASSIC, pc = HOP_C_CLASSIC;
volatile uint16_t corpus_result;                  // near: grid hash (boot gate == host reference)
static const uint8_t m7_zero = 0;                 // fixed-source byte for the tilemap-clear DMA
static uint8_t chrbuf[ROW_BYTES];                 // near: one tile-row, Mode 7 tiled order, staged for DMA

// 256-entry "fire" CGRAM palette (the pixel value IS the hit count). Index 0 (no hits) = black
// backdrop; counts ramp blue -> magenta -> orange -> white. The count is pre-scaled (t = count*3 +
// bright floor) so even a SINGLE hit glows clearly and the dense core saturates white — the attractor
// is a sparse point cloud, so a near-black low end (count==index linearly) would render it invisible.
static void load_palette(void) {
  REG_CGADD = 0;
  for (uint16_t i = 0; i < 256; i++) {
    uint8_t r, g, b;
    if (i == 0) { r = 0; g = 0; b = 0; }
    else {
      uint16_t t = (uint16_t)i * 3u + 40u;  if (t > 255) t = 255;   // bright floor + fast ramp
      r = (t < 96)  ? (uint8_t)(t * 31u / 96u)                       : 31;
      g = (t < 96)  ? 0 : (t < 176) ? (uint8_t)((t - 96) * 31u / 80u) : 31;
      b = (t < 64)  ? (uint8_t)(16u + t * 15u / 64u)                  : (t < 160 ? (uint8_t)(31u - (t - 64) * 31u / 96u) : (uint8_t)((t - 160) * 31u / 95u));
    }
    uint16_t c = SNES_RGB(r, g, b);
    REG_CGDATA = (uint8_t)(c & 0xFF);
    REG_CGDATA = (uint8_t)(c >> 8);
  }
}

// Far-load tile-row `trow` (8 image rows) of the grid into near chrbuf, in Mode 7 tiled order
// (chr byte tcol*64 + r*8 + c is image pixel (tcol*8+c, trow*8+r)). One far pointer (grid) live ->
// near writes — the grid_hash idiom. noinline to bound +mos-a16 pressure (handoff §4).
__attribute__((noinline)) static void build_band(uint8_t trow) {
  for (uint8_t tcol = 0; tcol < TILES; tcol++)
    for (uint8_t r = 0; r < 8; r++)
      for (uint8_t c = 0; c < 8; c++) {
        uint8_t x = (uint8_t)(tcol * 8 + c), y = (uint8_t)(trow * 8 + r);
        chrbuf[(uint16_t)tcol * 64 + (uint16_t)r * 8 + c] = grid[(uint16_t)((uint16_t)y * HOP_GRID + x)];
      }
}

// DMA ROW_BYTES of character data from near chrbuf into Mode 7 VRAM HIGH bytes at word `destword`.
static void dma_chr_to(uint16_t destword) {
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = destword;
  REG_DMAP0 = 0x00; REG_BBAD0 = 0x19;                          // A->B inc, pattern 0, dest $2119 (VMDATAH)
  REG_A1T0L = (uint8_t)(uintptr_t)chrbuf; REG_A1T0H = (uint8_t)((uintptr_t)chrbuf >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = (uint8_t)ROW_BYTES; REG_DAS0H = (uint8_t)(ROW_BYTES >> 8);
  REG_MDMAEN = 0x01;
}

int main(void) {
  snes_ppu_reset_blank();                 // force-blank + zero PPU control regs (determinism)
  m7_begin();                             // Mode 7, BG1 main screen (still force-blanked)
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES, TILES);      // 128x128 image = 16x16 tiles, top-left of the grid
  load_palette();

  grid_clear(grid);
  grid_plot(grid, pa, pb, pc, K_POINTS);  // far-RMW accumulation (force-blanked)
  corpus_result = grid_hash(grid);        // boot gate: grid hash == host reference

  for (uint8_t trow = 0; trow < TILES; trow++) {   // reveal: far grid -> near chrbuf -> VRAM, band by band
    build_band(trow);
    dma_chr_to((uint16_t)trow * ROW_BYTES);
  }
  m7_set_matrix(0x0080, 0x0000, 0x0000, 0x0080);  // 2x zoom -> 128x128 fills 256x224
  m7_set_center(0, 0);
  m7_set_scroll(0, 0);
  m7_show();                              // release force-blank — the attractor appears
  for (;;) {}
}
