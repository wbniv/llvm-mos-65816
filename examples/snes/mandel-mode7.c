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
//   * The interleaved Mode 7 VRAM image (low byte = tilemap, high byte = chr) is built in
//     a high-WRAM staging buffer and uploaded with ONE 32 KiB DMA — the DMA exemplar the
//     rendering handoff (docs/handoffs/2026-06-24-snes-graphics-rendering.md) points to.
//
// +mos-a16-only (far pointers are 32-bit values). corpus_result carries the CRC of the
// raster buffer (far loads) as the proof channel. Capture: dev/run.sh mandel-mode7.
// Build with -DMANDEL_TESTPAT to fill a fast synthetic pattern (display de-risk) instead
// of the slow Mandelbrot. See docs/plans/2026-06-24-snes-mandelbrot-beefy-demo.md (Track 3).
#include <snes.h>
#include "../65816/mandel.h"

#define FAR __attribute__((address_space(2)))
#define W 128            // image width  (= 16 tiles)
#define H 128            // image height (= 16 tiles)
#define DN 12            // max iterations. 8bpp indexes CGRAM directly; kept modest because
                         // 128x128 = 16384 cells of software 32-bit fixed-point is heavy
                         // (~thousands of frames of emulated time even at this N).

// High-WRAM layout (reachable only via 24-bit/far addressing):
static FAR uint8_t  *const fb   = (FAR uint8_t  *)0x7E2000u;  // raster escape buffer, 16 KiB
static FAR uint16_t *const vbuf = (FAR uint16_t *)0x7E6000u;  // interleaved Mode 7 image, 32 KiB

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

// Build the interleaved Mode 7 VRAM image: word n holds (chr[n] << 8) | tilemap[n].
//  - tilemap entry n: position (n&127, n>>7) in the 128x128 tile grid; the 16x16 image
//    tiles sit in the top-left, everything else = tile 0.
//  - chr byte n: tile n>>6, in-tile (row (n>>3)&7, col n&7) -> raster pixel of that block.
static void build_vbuf(void) {
  uint16_t n = 0;
  do {
    uint8_t tx = (uint8_t)(n & 127), ty = (uint8_t)(n >> 7);
    uint8_t tile = (tx < 16 && ty < 16) ? (uint8_t)(ty * 16 + tx) : 0;
    uint8_t t = (uint8_t)(n >> 6), off = (uint8_t)(n & 63);
    uint16_t ix = (uint16_t)((t & 15) * 8 + (off & 7));
    uint16_t iy = (uint16_t)((t >> 4) * 8 + (off >> 3));
    uint8_t px = fb[iy * W + ix];                              // FAR LOAD
    vbuf[n] = (uint16_t)(tile | ((uint16_t)px << 8));         // FAR STORE
  } while (++n != 0x4000);                                     // 16384 words
}

// One 32 KiB DMA: high-WRAM staging -> VRAM word 0, interleaved (pattern 1 = $2118/$2119).
static void dma_vbuf_to_vram(void) {
  snes_vram_addr(0x0000);              // VMAIN = inc-after-$2119, VMADD = 0
  REG_DMAP0 = 0x01;                    // direction A->B, transfer pattern 1 (two registers)
  REG_BBAD0 = 0x18;                    // B-bus dest = $2118 (VMDATAL); pattern 1 also hits $2119
  REG_A1T0L = (uint8_t)0x6000;         // A-bus source = $7E6000 (vbuf)
  REG_A1T0H = (uint8_t)(0x6000 >> 8);
  REG_A1B0  = 0x7E;                    // source bank
  REG_DAS0L = 0x00;                    // count = 0x8000 = 32768 bytes
  REG_DAS0H = 0x80;
  REG_MDMAEN = 0x01;                   // trigger channel 0 (CPU stalls until done)
}

int main(void) {
  snes_ppu_reset_blank();              // force-blank + zero PPU control regs (determinism)
  fill();
  corpus_result = crc_fb();
  load_palette();
  build_vbuf();
  dma_vbuf_to_vram();

  REG_BGMODE = BGMODE_7;               // single 8bpp rotation/scale layer
  REG_M7SEL  = 0x00;                   // wrap outside the map
  SNES_M7(REG_M7A, 0x0080); SNES_M7(REG_M7B, 0x0000);   // 2x zoom: screen steps 0.5 source
  SNES_M7(REG_M7C, 0x0000); SNES_M7(REG_M7D, 0x0080);
  REG_M7X = 0; REG_M7X = 0;            // rotation centre (0,0); write-twice latch
  REG_M7Y = 0; REG_M7Y = 0;
  REG_BG1HOFS = 0; REG_BG1HOFS = 0;    // Mode 7 scroll = 0
  REG_BG1VOFS = 0; REG_BG1VOFS = 0;
  REG_TM = TM_BG1;
  REG_INIDISP = INIDISP_ON;            // show it
  for (;;) {}
}
