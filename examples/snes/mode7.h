// Shared SNES Mode 7 setup + tilemap helpers.
//
// Used by examples/snes/mandel-display.c — the on-SNES fixed-point Mandelbrot tester, which renders
// in Mode 7 from a far high-WRAM escape buffer. This header provides the Mode 7 register setup, the
// tilemap clear/identity, and the affine-matrix / centre / scroll setters.
//
// Mode 7 character data is LINEAR 8bpp (1 byte/pixel, 256-tile cap), so e.g. a 64x56 image is 8x7
// tiles and a 128x128 image is the 16x16 = 256-tile maximum. The tile grid is a fixed 128x128. See
// docs/handoffs/2026-06-24-snes-graphics-rendering.md for the low-level mechanics.
#ifndef MODE7_H
#define MODE7_H

#include <snes.h>

#define M7_FAR __attribute__((address_space(2)))   /* 24-bit / far (high WRAM) */

// Clear `nwords` Mode 7 tilemap entries (VRAM LOW bytes) to 0 via a FIXED-source DMA reading the
// zero byte at (srcbank:srczero), from word 0.
static inline void m7_tilemap_clear(uint8_t srcbank, uint16_t srczero, uint16_t nwords) {
  REG_VMAIN = VMAIN_INC_LOW_1; REG_VMADD = 0;    // advance one word after each $2118 (low) write
  REG_DMAP0 = 0x08;                              // A->B, FIXED source (bit3), pattern 0
  REG_BBAD0 = 0x18;                              // B-bus dest = $2118 (VMDATAL)
  REG_A1T0L = (uint8_t)srczero; REG_A1T0H = (uint8_t)(srczero >> 8); REG_A1B0 = srcbank;
  REG_DAS0L = (uint8_t)nwords;  REG_DAS0H = (uint8_t)(nwords >> 8);
  REG_MDMAEN = 0x01;
}

// Set one Mode 7 tilemap entry (the VRAM low byte at `word`) to `tile`. VMAIN is inc-after-HIGH so
// writing the low byte alone does not advance VMADD.
static inline void m7_tilemap_set(uint16_t word, uint8_t tile) {
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = word; REG_VMDATAL = tile;
}

// The Mode 7 tile grid is a fixed 128x128 = 16384 entries (one byte each, the VRAM low byte).
// Give m7_tilemap_clear this count to blank the whole grid before laying down the identity, for
// ANY image size (an image smaller than 128x128 still surrounds itself with tile 0).
#define M7_TILEMAP_WORDS 16384

// Write the identity tilemap for an image of `tiles_w` x `tiles_h` 8x8 tiles (image W = tiles_w*8,
// H = tiles_h*8): the chr is laid out tile 0,1,2,... in row-major tile order (tile = ty*tiles_w +
// tx), so tile (ty*tiles_w + tx) maps to Mode 7 tilemap word ty*128 + tx — the image tiles sit in
// the top-left of the 128x128 grid, the rest staying tile 0 from the preceding m7_tilemap_clear.
// Parametric over image size (mandel-display's tester uses 8x7 = 64x56). tiles_w*tiles_h <= 256.
static inline void m7_tilemap_identity(uint8_t tiles_w, uint8_t tiles_h) {
  for (uint8_t ty = 0; ty < tiles_h; ty++)
    for (uint8_t tx = 0; tx < tiles_w; tx++)
      m7_tilemap_set((uint16_t)((uint16_t)ty * 128 + tx), (uint8_t)(ty * tiles_w + tx));
}

// Enter Mode 7 with BG1 as the only main-screen layer (screen still force-blanked).
static inline void m7_begin(void) {
  REG_BGMODE = BGMODE_7;
  REG_M7SEL  = 0x00;                    // wrap outside the map
  REG_TM     = TM_BG1;
}

// Release force-blank — show the picture.
//
// M7BLANK_PROBE (measurement builds only, never shipped): paint CGRAM[0] white at the moment the
// blank is released. Most Mode 7 demos deliberately use a BLACK backdrop (buddha's "no hits ->
// black", the cloud blooming in on it), so a picture-level scan cannot tell "still force-blanked"
// from "released, but the art is still black". With the probe on, everything after the release is
// white, so the all-black run measured by dev/m7blank.sh is EXACTLY the force-blank window — the
// thing this handoff contract is about. Compiled out by default; costs a shipped ROM nothing.
static inline void m7_show(void) {
#ifdef M7BLANK_PROBE
  REG_CGADD = 0; REG_CGDATA = 0xFF; REG_CGDATA = 0x7F;
#endif
  REG_INIDISP = INIDISP_ON;
}

// Mode 7 transform setters. Matrix elements are 8.8 signed; centre/scroll are write-twice
// latched ports (low byte then high byte).
static inline void m7_set_matrix(int16_t a, int16_t b, int16_t c, int16_t d) {
  SNES_M7(REG_M7A, (uint16_t)a); SNES_M7(REG_M7B, (uint16_t)b);
  SNES_M7(REG_M7C, (uint16_t)c); SNES_M7(REG_M7D, (uint16_t)d);
}
static inline void m7_set_center(uint16_t x, uint16_t y) {
  REG_M7X = (uint8_t)x; REG_M7X = (uint8_t)(x >> 8);
  REG_M7Y = (uint8_t)y; REG_M7Y = (uint8_t)(y >> 8);
}
static inline void m7_set_scroll(uint16_t h, uint16_t v) {
  REG_BG1HOFS = (uint8_t)h; REG_BG1HOFS = (uint8_t)(h >> 8);
  REG_BG1VOFS = (uint8_t)v; REG_BG1VOFS = (uint8_t)(v >> 8);
}

#endif /* MODE7_H */
