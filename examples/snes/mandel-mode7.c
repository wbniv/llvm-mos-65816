// #321 Track 3b — a BIG, per-pixel Mandelbrot on the SNES: computed into HIGH WRAM via
// #320 far stores, displayed crisply via Mode 7, revealed PROGRESSIVELY (coarse -> fine,
// top-down) so the slow 128x128 compute is watchable instead of a multi-minute black screen.
//
// Why this exists / what it exercises:
//   * 128x128 escape buffer = 16 KiB — too big for low WRAM (8 KiB), so it lives at $7E2000
//     (high WRAM) and is filled + read back via far stores/loads (the motivating far-pointer
//     use case; cf. Track 3a / k_mandel_far.c). corpus_result = CRC of that far buffer.
//   * Mode 7 character data is LINEAR 8bpp, 256-tile cap, so 128x128 = 16x16 = 256 tiles. We
//     show it at 2x zoom so it fills the screen.
//   * Reveal is done in vblank (no force-blank flash): each refresh is one Mode 7 tile-row = a
//     contiguous 1 KiB character region DMA'd from a near staging buffer. Coarse previews
//     (16x16, 32x32) land fast; then the canonical 128x128 fills the far buffer and is revealed
//     a tile-row at a time as it computes, sharpening top-down.
//
// +mos-a16-only (far pointers are 32-bit values). Capture: dev/run.sh mandel-mode7. Build with
// -DMANDEL_TESTPAT to fill a fast synthetic pattern (display de-risk) instead of the slow kernel.
#include <snes.h>
#include "mode7.h"
#include "../65816/mandel.h"

#define W 128            // image width  (must equal M7_W; dev/mandel-mode7.sh awk's this literal)
#define H 128            // image height (must equal M7_H)
#define DN 12            // max iterations (8bpp indexes CGRAM directly; 128x128 is heavy)
#define TILES 16         // W/8 = H/8
#define ROW_BYTES 1024   // one Mode 7 tile-row of character data (16 tiles * 64 bytes)

// High-WRAM raster escape buffer (reachable only via 24-bit/far addressing).
static M7_FAR uint8_t *const fb = (M7_FAR uint8_t *)0x7E2000u;  // 16 KiB

static uint8_t scratch[32 * 32];     // near: coarse-preview grid (max 32x32 = 1 KiB)
static uint8_t chrbuf[ROW_BYTES];    // near: one tile-row, Mode 7 tiled order, staged for DMA
volatile uint16_t corpus_result;     // near: CRC of fb (far loads), the proof channel
static const uint8_t m7_zero = 0;    // fixed-source byte for the tilemap-clear DMA

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

// CRC16-CCITT over the raster buffer via far loads (== host reference over the same grid).
static uint16_t crc_fb(void) {
  uint16_t crc = 0xFFFF;
  for (uint16_t k = 0; k < (uint16_t)(W * H); k++) {
    crc ^= (uint16_t)((uint16_t)fb[k] << 8);                    // FAR LOAD
    for (uint8_t b = 0; b < 8; b++)
      crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
  }
  return crc;
}

// DMA `nbytes` of character data from the near staging buffer into the Mode 7 VRAM HIGH bytes
// starting at word `destword` (WRAM->VRAM is a legal DMA; only WRAM<->WRAM is not).
static void dma_chr_to(uint16_t destword, const uint8_t *src, uint16_t nbytes) {
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = destword;
  REG_DMAP0 = 0x00; REG_BBAD0 = 0x19;                          // A->B inc, pattern 0, dest $2119
  REG_A1T0L = (uint8_t)(uintptr_t)src; REG_A1T0H = (uint8_t)((uintptr_t)src >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = (uint8_t)nbytes; REG_DAS0H = (uint8_t)(nbytes >> 8);
  REG_MDMAEN = 0x01;
}

// Block until the NEXT true vblank, clearing the flag stale-latched during the preceding compute.
static void wait_vblank_fresh(void) {
  (void)REG_RDNMI;
  snes_wait_vblank();
}

// Fill chrbuf with tile-row `trow` (8 image rows) of a cw*ch coarse grid in `scratch`, nearest-
// neighbour scaled to 128x128 (shx/shy = log2(W/cw)=log2(H/ch)), in Mode 7 tiled order.
static void build_coarse_row(uint8_t trow, uint8_t cw, uint8_t shx, uint8_t shy) {
  for (uint8_t tcol = 0; tcol < TILES; tcol++)
    for (uint8_t r = 0; r < 8; r++)
      for (uint8_t c = 0; c < 8; c++) {
        uint8_t x = (uint8_t)(tcol * 8 + c), y = (uint8_t)(trow * 8 + r);
        chrbuf[(uint16_t)tcol * 64 + (uint16_t)r * 8 + c] = scratch[(uint16_t)(y >> shy) * cw + (x >> shx)];
      }
}

// A whole coarse pass: compute the cw*ch grid, then reveal it tile-row by tile-row.
static void coarse_pass(uint8_t cw, uint8_t ch, uint8_t shx, uint8_t shy, uint8_t in_vblank) {
  mandel_fill(scratch, cw, ch, DN);
  for (uint8_t trow = 0; trow < TILES; trow++) {
    build_coarse_row(trow, cw, shx, shy);
    if (in_vblank) wait_vblank_fresh();
    dma_chr_to((uint16_t)trow * ROW_BYTES, chrbuf, ROW_BYTES);
  }
}

int main(void) {
  snes_ppu_reset_blank();              // force-blank + zero PPU control regs (determinism)

  m7_begin();
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES, TILES);
  load_palette();
  m7_set_matrix(0x0080, 0x0000, 0x0000, 0x0080);   // 2x zoom -> 128x128 fills 256x224
  m7_set_center(0, 0);
  m7_set_scroll(0, 0);

#ifndef MANDEL_TESTPAT
  // Coarse previews: 16x16 uploaded while force-blanked (boot), then released; 32x32 in vblank.
  coarse_pass(16, 16, 3, 3, 0);
  m7_show();
  REG_NMITIMEN = NMITIMEN_NMI;
  coarse_pass(32, 32, 2, 2, 1);
#else
  m7_show();
  REG_NMITIMEN = NMITIMEN_NMI;
#endif

  // Canonical 128x128: fill the far buffer one image LINE at a time and reveal each line in vblank
  // — a smooth top-down scanline fill. fb is fully populated by far stores (the a16 use case); the
  // CRC then runs over the whole far buffer == mandel-render 128 128 12. In Mode 7's tiled layout
  // one image row r is, per 8x8 tile, 8 contiguous chr bytes at tile*64 + r*8 — so a line is 16
  // short runs (one per tile column), read straight from the far buffer.
#ifndef MANDEL_TESTPAT
  int16_t dre = (int16_t)(MANDEL_REW / W);
  int16_t dim = (int16_t)(MANDEL_IMW / H);
#endif
  for (uint16_t y = 0; y < H; y++) {
    uint8_t trow = (uint8_t)(y >> 3), r = (uint8_t)(y & 7);
#ifdef MANDEL_TESTPAT
    for (uint16_t x = 0; x < W; x++) fb[y * W + x] = (uint8_t)(((x >> 2) ^ (y >> 2)) & 0x1F);
#else
    int16_t ci = (int16_t)(MANDEL_IM0 + (int16_t)y * dim);
    for (uint16_t x = 0; x < W; x++) {
      int16_t cr = (int16_t)(MANDEL_RE0 + (int16_t)x * dre);
      fb[y * W + x] = mandel_cell(cr, ci, DN);                  // FAR STORE
    }
#endif
    wait_vblank_fresh();
    for (uint8_t tcol = 0; tcol < TILES; tcol++) {                          // row r of each of 16 tiles
      snes_vram_addr((uint16_t)((uint16_t)(trow * TILES + tcol) * 64 + (uint16_t)r * 8));
      uint16_t base = (uint16_t)(y * W + (uint16_t)tcol * 8);
      for (uint8_t c = 0; c < 8; c++) REG_VMDATAH = fb[base + c];           // FAR LOAD
    }
  }
  corpus_result = crc_fb();            // far loads over the whole buffer == host reference

  for (;;) {}
}
