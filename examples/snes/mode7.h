// Shared SNES Mode 7 upload + setup helpers.
//
// Refactored out of examples/snes/mandel-mode7.c so the static (Track 3b) and interactive
// Mandelbrot demos share the exact VRAM-image build, the 32 KiB DMA, and the Mode 7 register
// setup. The ONLY thing that differs between the two demos is the source image's address space
// — the far high-WRAM compute buffer (static) vs. a near baked ROM array (interactive) — which
// M7_DEFINE_BUILD_VBUF() handles by stamping the de-linearize loop for a given qualifier.
//
// Mode 7 character data is LINEAR 8bpp (1 byte/pixel, 256-tile cap), so a 128x128 image is
// exactly 16x16 = 256 tiles — the per-pixel maximum. The interleaved VRAM image (low byte =
// tilemap, high byte = chr) is staged in high WRAM and uploaded with ONE 32 KiB DMA. See
// docs/handoffs/2026-06-24-snes-graphics-rendering.md for the low-level mechanics.
#ifndef MODE7_H
#define MODE7_H

#include <snes.h>

#define M7_FAR __attribute__((address_space(2)))   /* 24-bit / far (high WRAM) */
#define M7_W   128                                  /* image width  (= 16 tiles) */
#define M7_H   128                                  /* image height (= 16 tiles) */

// 32 KiB interleaved Mode 7 staging image in HIGH WRAM ($7E6000) — too big for low WRAM, so
// it is filled via far stores (a 32-bit pointer => +mos-a16-only).
static M7_FAR uint16_t *const m7_vbuf = (M7_FAR uint16_t *)0x7E6000u;

// Stamp a `build_vbuf`-style function that de-linearizes a 128x128 8bpp source `img` (in the
// SRCQUAL address space) into the interleaved Mode 7 image at m7_vbuf. word n = (chr[n]<<8) |
// tilemap[n]:
//   * tilemap entry n: position (n&127, n>>7) in the 128x128 tile grid; the 16x16 image tiles
//     sit in the top-left, everything else = tile 0.
//   * chr byte n: tile n>>6, in-tile (row (n>>3)&7, col n&7) -> source pixel of that block.
// SRCQUAL is M7_FAR for a high-WRAM compute buffer, or empty for a near ROM array.
#define M7_DEFINE_BUILD_VBUF(NAME, SRCQUAL)                               \
  static void NAME(const SRCQUAL uint8_t *img) {                          \
    uint16_t n = 0;                                                       \
    do {                                                                  \
      uint8_t tx = (uint8_t)(n & 127), ty = (uint8_t)(n >> 7);           \
      uint8_t tile = (tx < 16 && ty < 16) ? (uint8_t)(ty * 16 + tx) : 0; \
      uint8_t t = (uint8_t)(n >> 6), off = (uint8_t)(n & 63);            \
      uint16_t ix = (uint16_t)((t & 15) * 8 + (off & 7));                \
      uint16_t iy = (uint16_t)((t >> 4) * 8 + (off >> 3));               \
      uint8_t px = img[iy * M7_W + ix];                                   \
      m7_vbuf[n] = (uint16_t)(tile | ((uint16_t)px << 8));               \
    } while (++n != 0x4000);   /* 16384 words */                          \
  }

// One 32 KiB DMA: high-WRAM staging -> VRAM word 0, interleaved (pattern 1 = $2118/$2119).
static inline void m7_dma_vbuf_to_vram(void) {
  snes_vram_addr(0x0000);               // VMAIN = inc-after-$2119, VMADD = 0
  REG_DMAP0 = 0x01;                     // direction A->B, transfer pattern 1 (two registers)
  REG_BBAD0 = 0x18;                     // B-bus dest = $2118 (VMDATAL); pattern 1 also hits $2119
  REG_A1T0L = (uint8_t)0x6000;          // A-bus source = $7E6000 (m7_vbuf)
  REG_A1T0H = (uint8_t)(0x6000 >> 8);
  REG_A1B0  = 0x7E;                     // source bank
  REG_DAS0L = 0x00;                     // count = 0x8000 = 32768 bytes
  REG_DAS0H = 0x80;
  REG_MDMAEN = 0x01;                    // trigger channel 0 (CPU stalls until done)
}

// --- Instant-boot upload: stream a host-pre-tiled image straight from ROM to Mode 7 VRAM, with
// NO de-linearize loop or high-WRAM staging (that is the slow black-screen boot m7_vbuf/build_vbuf
// cause). The character data goes to the VRAM HIGH bytes by DMA; the tilemap (LOW bytes) is a
// fast DMA-clear plus a tiny identity loop. srcbank:srcaddr is a CPU A-bus address — for a near
// ROM const in this single-bank LoROM, srcbank = 0x00 and srcaddr = (uint16_t)&sym. ---

// DMA `nbytes` of character data from (srcbank:srcaddr) into Mode 7 VRAM HIGH bytes, from word 0.
static inline void m7_dma_chr(uint8_t srcbank, uint16_t srcaddr, uint16_t nbytes) {
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = 0;   // advance one word after each $2119 (high) write
  REG_DMAP0 = 0x00;                              // A->B, increment source, pattern 0 (one register)
  REG_BBAD0 = 0x19;                              // B-bus dest = $2119 (VMDATAH)
  REG_A1T0L = (uint8_t)srcaddr; REG_A1T0H = (uint8_t)(srcaddr >> 8); REG_A1B0 = srcbank;
  REG_DAS0L = (uint8_t)nbytes;  REG_DAS0H = (uint8_t)(nbytes >> 8);
  REG_MDMAEN = 0x01;                             // trigger ch0 (CPU stalls until done)
}

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

// Write the identity tilemap for a host-tiled image of `tiles_w` x `tiles_h` 8x8 tiles (image
// W = tiles_w*8, H = tiles_h*8): the chr is laid out tile 0,1,2,... in row-major tile order
// (tile = ty*tiles_w + tx, the mandel-bake order), so tile (ty*tiles_w + tx) maps to Mode 7
// tilemap word ty*128 + tx — the image tiles sit in the top-left of the 128x128 grid, the rest
// staying tile 0 from the preceding m7_tilemap_clear. Parametric so a 64x64 (8x8) pyramid level
// and a 128x128 (16x16) image share one path. tiles_w*tiles_h must be <= 256 (Mode 7 tile cap).
static inline void m7_tilemap_identity(uint8_t tiles_w, uint8_t tiles_h) {
  for (uint8_t ty = 0; ty < tiles_h; ty++)
    for (uint8_t tx = 0; tx < tiles_w; tx++)
      m7_tilemap_set((uint16_t)((uint16_t)ty * 128 + tx), (uint8_t)(ty * tiles_w + tx));
}

// Load `n` BGR555 colours into CGRAM starting at palette index 0.
static inline void m7_cgram_load(const uint16_t *pal, uint16_t n) {
  REG_CGADD = 0;
  for (uint16_t i = 0; i < n; i++) {
    REG_CGDATA = (uint8_t)(pal[i] & 0xFF);
    REG_CGDATA = (uint8_t)(pal[i] >> 8);
  }
}

// Enter Mode 7 with BG1 as the only main-screen layer (screen still force-blanked).
static inline void m7_begin(void) {
  REG_BGMODE = BGMODE_7;
  REG_M7SEL  = 0x00;                    // wrap outside the map
  REG_TM     = TM_BG1;
}

// Release force-blank — show the picture.
static inline void m7_show(void) { REG_INIDISP = INIDISP_ON; }

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
