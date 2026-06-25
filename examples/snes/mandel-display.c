// #321 beefy demo, Track 2 — render the fixed-point Mandelbrot ON the SNES, in MODE 7.
//
// Unlike mandel-mode7.c (which DMAs a HOST-baked 128x128 image and needs +mos-a16 high WRAM),
// this computes the fractal on the 65816 and writes it, a tile-row at a time, into Mode 7
// character VRAM — progressively (coarse -> fine), then spins/zooms it with the affine matrix.
//
// It stays on the DEFAULT 65816 target (so the prebuilt toolchain builds it and it syncs to the
// web demo): no +mos-a16 far/high-WRAM pixel buffer. Pixels are staged in a small NEAR low-WRAM
// buffer and DMA'd to VRAM; the fidelity CRC is rolled byte-by-byte as the canonical pass
// computes (no full image buffer needed).
//
// REVEAL DURING VBLANK — no force-blank flash. Each refresh is one Mode 7 tile-row = 8 image rows
// = a contiguous 512-byte character region; a 512-byte WRAM->VRAM DMA fits comfortably inside one
// vblank, so the picture fills in (and later sharpens) flicker-free.
//
// Image: 64x56 px = 8x7 Mode 7 tiles, DN=15 (escape 0..15, 15 = interior = black). The matrix
// 4x-magnifies it to exactly fill 256x224. corpus_result carries the buffer CRC (== the host
// reference tools/mandel-render 64 56 15 == 0x204F) as the differential proof channel.
#include <snes.h>
#include "mode7.h"
#include "../65816/mandel.h"
#include "sincos.h"

#define DW 64                // image width  (8 tiles)
#define DH 56                // image height (7 tiles)
#define DN 15                // max iterations (escape count fits a small CGRAM palette)
#define TILES_W (DW / 8)     // 8
#define TILES_H (DH / 8)     // 7
#define ROW_BYTES 512        // one tile-row of character data (8 tiles * 64 bytes)

static uint8_t scratch[32 * 28];        // coarse-preview grid (max 32x28 = 896 B, low WRAM)
static uint8_t chrbuf[ROW_BYTES];       // one tile-row, in Mode 7 tiled order, staged for DMA
volatile uint16_t corpus_result;        // rolling CRC of the canonical 64x56 buffer (the proof)
static const uint8_t m7_zero = 0;       // fixed-source byte for the tilemap-clear DMA

// 16 CGRAM entries (escape 0..DN) = the shared Mandelbrot palette (mandel.h). 8bpp direct index:
// the Mode 7 pixel value == escape count == the CRC byte.
static void load_palette(void) {
  REG_CGADD = 0;
  for (uint8_t n = 0; n <= DN; n++) {
    uint8_t r, g, b;
    mandel_palette(n, DN, &r, &g, &b);
    uint16_t c = SNES_RGB(r, g, b);
    REG_CGDATA = (uint8_t)(c & 0xFF);
    REG_CGDATA = (uint8_t)(c >> 8);
  }
}

// CRC16-CCITT (XModem) one byte — the incremental form of mandel.h's mandel_crc, so feeding the
// canonical buffer row-major reproduces mandel_crc(fb, DW*DH) exactly (== the host reference).
static void crc_byte(uint16_t *crc, uint8_t b) {
  uint16_t c = (uint16_t)(*crc ^ (uint16_t)((uint16_t)b << 8));
  for (uint8_t i = 0; i < 8; i++)
    c = (c & 0x8000) ? (uint16_t)((uint16_t)(c << 1) ^ 0x1021) : (uint16_t)(c << 1);
  *crc = c;
}

// DMA `nbytes` of character data from a NEAR buffer (bank $00 low WRAM) into the Mode 7 VRAM HIGH
// bytes starting at word `destword`. WRAM->VRAM is a legal DMA (only WRAM<->WRAM is not).
static void dma_chr_to(uint16_t destword, const uint8_t *src, uint16_t nbytes) {
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = destword;   // advance one word per $2119 (high) write
  REG_DMAP0 = 0x00;                                      // A->B, increment source, pattern 0
  REG_BBAD0 = 0x19;                                      // B-bus dest = $2119 (VMDATAH = char)
  REG_A1T0L = (uint8_t)(uintptr_t)src; REG_A1T0H = (uint8_t)((uintptr_t)src >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = (uint8_t)nbytes; REG_DAS0H = (uint8_t)(nbytes >> 8);
  REG_MDMAEN = 0x01;                                     // trigger ch0 (CPU stalls until done)
}

// Block until the NEXT true vblank. The reveal points follow long computes (many vblanks elapse
// unread), so clear the stale RDNMI flag FIRST — otherwise snes_wait_vblank() returns immediately
// mid-frame and the DMA would corrupt VRAM during active display.
static void wait_vblank_fresh(void) {
  (void)REG_RDNMI;        // discard a flag latched during the preceding compute
  snes_wait_vblank();     // now blocks until the next vblank actually begins
}

// Fill chrbuf with Mode 7 tile-row `trow` (8 image rows) of a cw*ch coarse grid, nearest-neighbour
// scaled to 64x56 (shx/shy = log2(DW/cw) = log2(DH/ch)), in tiled order ready for dma_chr_to.
static void build_coarse_row(uint8_t trow, const uint8_t *coarse, uint8_t cw, uint8_t shx, uint8_t shy) {
  for (uint8_t tcol = 0; tcol < TILES_W; tcol++)
    for (uint8_t r = 0; r < 8; r++)
      for (uint8_t c = 0; c < 8; c++) {
        uint8_t x = (uint8_t)(tcol * 8 + c), y = (uint8_t)(trow * 8 + r);
        chrbuf[(uint16_t)tcol * 64 + (uint16_t)r * 8 + c] = coarse[(uint16_t)(y >> shy) * cw + (x >> shx)];
      }
}

// A whole coarse pass: compute the cw*ch grid, then reveal it tile-row by tile-row in vblank.
static void coarse_pass(uint8_t cw, uint8_t ch, uint8_t shx, uint8_t shy, uint8_t in_vblank) {
  mandel_fill(scratch, cw, ch, DN);
  for (uint8_t trow = 0; trow < TILES_H; trow++) {
    build_coarse_row(trow, scratch, cw, shx, shy);
    if (in_vblank) wait_vblank_fresh();
    dma_chr_to((uint16_t)trow * ROW_BYTES, chrbuf, ROW_BYTES);
  }
}

int main(void) {
  snes_ppu_reset_blank();                       // force-blank + zero PPU control regs

  // One-time Mode 7 setup (force-blanked): enter Mode 7, clear the 128x128 tilemap and lay the 8x7
  // identity, load the palette, frame the image at 4x (a=d=0x0040 -> 64x56 fills 256x224, top-left
  // aligned: center 0, scroll 0).
  m7_begin();
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES_W, TILES_H);
  load_palette();
  m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
  m7_set_center(0, 0);
  m7_set_scroll(0, 0);

  // First image: the 8x7 coarse field, uploaded while still force-blanked (boot is black, not a
  // flash), then released. From here on every refresh lands in vblank, so the screen never blanks.
  coarse_pass(8, 7, 3, 3, 0);
  m7_show();
  REG_NMITIMEN = NMITIMEN_NMI;                   // enable vblank NMI (crt0's weak `rti` handler is safe)

  // Finer previews, revealed in vblank (no force-blank, no flash).
  coarse_pass(16, 14, 2, 2, 1);
  coarse_pass(32, 28, 1, 1, 1);

  // Canonical 64x56, top-down a tile-row at a time. Compute each strip's 8 rows ROW-MAJOR, fold
  // every escape count into the rolling CRC in that order (so corpus_result == mandel_crc over a
  // row-major 64x56 buffer == mandel-render 64 56 15), and stash each pixel into chrbuf at its
  // TILED offset; then reveal the strip with one vblank DMA. Rows below keep the 32x28 preview ->
  // sharpens top-down, flicker-free.
  {
    int16_t dre = (int16_t)(MANDEL_REW / DW);
    int16_t dim = (int16_t)(MANDEL_IMW / DH);
    uint16_t crc = 0xFFFF;
    for (uint8_t trow = 0; trow < TILES_H; trow++) {
      for (uint8_t r = 0; r < 8; r++) {
        uint8_t j = (uint8_t)(trow * 8 + r);
        int16_t ci = (int16_t)(MANDEL_IM0 + (int16_t)j * dim);
        for (uint8_t i = 0; i < DW; i++) {
          int16_t cr = (int16_t)(MANDEL_RE0 + (int16_t)i * dre);
          uint8_t v = mandel_cell(cr, ci, DN);
          crc_byte(&crc, v);
          chrbuf[(uint16_t)(i >> 3) * 64 + (uint16_t)r * 8 + (i & 7)] = v;
        }
      }
      wait_vblank_fresh();
      dma_chr_to((uint16_t)trow * ROW_BYTES, chrbuf, ROW_BYTES);
    }
    corpus_result = crc;                         // == gate CRC 0x204F (set once, after the render)
  }

  // Steady state: the iconic Mode 7 move — slowly rotate the rendered fractal while gently zooming.
  // Pivot on the image centre (32,28); the scroll offset keeps that point at screen centre so the
  // angle-0 / 4x framing matches the static render exactly (no jump). Pure matrix animation, no
  // recompute, so it never affects corpus_result. The matrix is latched in vblank each frame.
  m7_set_center(DW / 2, DH / 2);
  m7_set_scroll((uint16_t)(int16_t)(-(128 - DW / 2)), (uint16_t)(int16_t)(-(112 - DH / 2)));  // (-96,-84)
  uint8_t angle = 0, t = 0;
  for (;;) {
    wait_vblank_fresh();
    int16_t zoom = (int16_t)(0x0030 + (((int32_t)SINCOS[(uint8_t)(t >> 1)] * 0x0008) >> 8));  // 0x28..0x38
    int16_t cs = SINCOS[(uint8_t)(angle + 64)];   // cos (8.8)
    int16_t sn = SINCOS[angle];                    // sin (8.8)
    int16_t a = (int16_t)(((int32_t)cs * zoom) >> 8);
    int16_t b = (int16_t)(((int32_t)(-sn) * zoom) >> 8);
    int16_t c = (int16_t)(((int32_t)sn * zoom) >> 8);
    m7_set_matrix(a, b, c, a);                     // A=D=cos*zoom, B=-sin*zoom, C=sin*zoom
    angle = (uint8_t)(angle + 1);                  // ~256 frames / rotation
    t = (uint8_t)(t + 1);
  }
}
