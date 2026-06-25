// #321 beefy demo, Track 2 — render the fixed-point Mandelbrot ON the SNES.
//
// The SNES has no linear framebuffer, so we show the escape buffer as a background:
// each Mandelbrot cell becomes one 8x8 SOLID-COLOUR tile, and the BG1 tilemap IS the
// image (tilemap entry = escape count = tile number = palette index). No per-pixel
// bitplane de-linearisation — only 16 solid tiles to build. Mode 1, BG1 4bpp, so
// escape counts run 0..15 (DN=15; 15 = interior = black).
//
// The compute is the SAME mandel.h kernel the differential gate (k_mandel.c) and the
// host renderer (tools/mandel-render.c) use, so the on-screen image is the verified
// one. corpus_result still carries the buffer CRC (WRAM readback) as a proof channel.
//
// Capture: dev/mandel-shot.sh boots this in bsnes-jg (software renderer -> real PNG
// via dev/jgxcheck.cpp) and MAME-under-Xvfb. See docs/investigations/.
#include <snes.h>
#include "../65816/mandel.h"

#define DW 32        // tile columns (fills the 256px-wide visible screen: 32*8)
#define DH 28        // tile rows    (fills the 224px-tall visible screen: 28*8)
#define DN 15        // max iterations (<=15: one 4bpp palette entry per escape count)

#define CHAR_BASE 0x0000   // VRAM word addr of the 16 solid tiles
#define MAP_BASE  0x1000   // VRAM word addr of the BG1 tilemap (no overlap: tiles use 0..255)

static uint8_t fb[DW * DH];          // escape buffer, 896 B (low WRAM)
volatile uint16_t corpus_result;     // buffer CRC — the WRAM proof channel (== host 0x...)
static uint8_t pre[16 * 14];         // progressive-preview scratch, 224 B. Declared AFTER
                                     // corpus_result so the proof symbol keeps its WRAM addr
                                     // (the in-browser self-check reads a fixed offset).

// One VRAM word, explicit low-then-high so the $2119 write triggers the auto-increment
// (don't rely on the byte order of a 16-bit volatile store to an MMIO port).
static void vram_w(uint16_t w) { REG_VMDATAL = (uint8_t)w; REG_VMDATAH = (uint8_t)(w >> 8); }

// 16 CGRAM entries = the shared Mandelbrot palette (mandel.h), so the SNES colours
// match the host PNG exactly.
static void load_palette(void) {
  REG_CGADD = 0;
  for (uint8_t n = 0; n < 16; n++) {
    uint8_t r, g, b;
    mandel_palette(n, DN, &r, &g, &b);
    uint16_t c = SNES_RGB(r, g, b);
    REG_CGDATA = (uint8_t)(c & 0xFF);
    REG_CGDATA = (uint8_t)(c >> 8);
  }
}

// Build 16 solid-colour 4bpp tiles at CHAR_BASE. A 4bpp tile is 16 words: words 0-7 =
// bitplanes 0&1 (one word/row), words 8-15 = bitplanes 2&3. For a solid colour c,
// bitplane p is all-ones iff bit p of c is set, so every row of a plane-pair is the
// same word. Written as ONE flat loop over the 256 words (value derived from the word
// index) so there is no ambiguity in how the VRAM address advances.
static void upload_solid_tiles(void) {
  snes_vram_addr(CHAR_BASE);
  for (uint16_t w = 0; w < (uint16_t)(16 * 16); w++) {
    uint8_t c    = (uint8_t)(w >> 4);          // tile index 0..15
    uint8_t hi23 = (uint8_t)((w >> 3) & 1);    // 0 = planes 0&1, 1 = planes 2&3
    uint16_t val = hi23
      ? (uint16_t)(((c & 4) ? 0x00FF : 0) | ((c & 8) ? 0xFF00 : 0))
      : (uint16_t)(((c & 1) ? 0x00FF : 0) | ((c & 2) ? 0xFF00 : 0));
    vram_w(val);
  }
}

// The tilemap IS the image: each tile = escape count = solid-tile number. Write the FULL
// 32x32 map (1024 entries) from an sw*sh source grid, nearest-neighbour scaled to fill the
// 32x28 image — so a coarse pass (e.g. 4x4) blows up to cover the whole screen and a finer
// pass refines it. Rows past the image (>= DH) get tile 0 so no on-screen cell reads bsnes's
// randomised power-up VRAM. The per-tile divide is hoisted into two small index tables built
// by counters (sw,sh always divide DW,DH evenly here), keeping the hot loop — and thus the
// first reveal — fast. For the final pass (sw=DW, sh=DH) the tables are the identity.
static void upload_scaled(const uint8_t *src, uint8_t sw, uint8_t sh) {
  uint8_t cmap[DW], rmap[DH];
  uint8_t rep_x = (uint8_t)(DW / sw), rep_y = (uint8_t)(DH / sh);
  uint8_t s = 0, cnt = 0;
  for (uint8_t col = 0; col < DW; col++) { cmap[col] = s; if (++cnt == rep_x) { cnt = 0; s++; } }
  s = 0; cnt = 0;
  for (uint8_t row = 0; row < DH; row++) { rmap[row] = s; if (++cnt == rep_y) { cnt = 0; s++; } }
  snes_vram_addr(MAP_BASE);
  for (uint16_t i = 0; i < 1024; i++) {
    uint8_t col = (uint8_t)(i & 31), row = (uint8_t)(i >> 5);
    vram_w(row < DH ? (uint16_t)src[(uint16_t)rmap[row] * sw + cmap[col]] : 0);
  }
}

int main(void) {
  snes_ppu_reset_blank();                       // force-blank + zero PPU control regs
                                                 //  (kills bsnes power-up nondeterminism)

  // One-time PPU setup, done while still force-blanked: the shared palette, the 16 solid
  // tiles, and BG1 pointed at our char/tilemap bases. (Scroll regs each latch two writes;
  // the power-up value is garbage.)
  load_palette();
  upload_solid_tiles();
  REG_BGMODE  = BGMODE_1;                        // mode 1: BG1 = 4bpp
  REG_BG12NBA = (uint8_t)(CHAR_BASE >> 12);      // BG1 char base ($1000-word units)
  REG_BG1SC   = SNES_BGSC(MAP_BASE, 0);          // BG1 tilemap base, 32x32 map
  REG_BG1HOFS = 0; REG_BG1HOFS = 0;              // scroll = 0
  REG_BG1VOFS = 0; REG_BG1VOFS = 0;
  REG_TM      = TM_BG1;                          // main screen = BG1 only (TS/colour-math
                                                 //  already zeroed by snes_ppu_reset_blank)

  // Progressive coarse->fine render. The beefy on-SNES compute fills the whole 32x28 buffer
  // slowly, so instead of force-blanking until it finishes (~seconds of black), render at
  // 4x4, reveal, then 8x7, 16x14, and finally the real 32x28 — a recognizable image lands in
  // <0.1 s and sharpens. Each pass recomputes a finer grid of the SAME window (mandel_fill
  // derives its steps from w/h, so every grid samples the identical region) and rewrites the
  // tilemap; the force-blank around passes 2+ is sub-frame. Grids divide 32x28 cleanly.
  //
  // FIDELITY: passes 1-3 touch only `pre`/the tilemap. `fb` is filled exactly ONCE, by the
  // final canonical mandel_fill(fb, DW, DH, DN) below, so corpus_result == the gate CRC
  // (0x9103) by construction — progressive drawing changes only WHEN pixels appear.

  mandel_fill(pre, 4, 4, DN);                   // pass 1: 16 cells, the fast first paint
  upload_scaled(pre, 4, 4);
  REG_INIDISP = INIDISP_ON;                      // first reveal — uses the boot force-blank (no blink)

  mandel_fill(pre, 8, 7, DN);                   // pass 2: 56 cells
  REG_INIDISP = INIDISP_FORCE_BLANK; upload_scaled(pre, 8, 7);   REG_INIDISP = INIDISP_ON;

  mandel_fill(pre, 16, 14, DN);                 // pass 3: 224 cells
  REG_INIDISP = INIDISP_FORCE_BLANK; upload_scaled(pre, 16, 14); REG_INIDISP = INIDISP_ON;

  mandel_fill(fb, DW, DH, DN);                  // pass 4: the canonical buffer (same kernel as the gate)
  corpus_result = mandel_crc(fb, (uint16_t)(DW * DH));
  REG_INIDISP = INIDISP_FORCE_BLANK; upload_scaled(fb, DW, DH);  REG_INIDISP = INIDISP_ON;

  for (;;) {}
}
