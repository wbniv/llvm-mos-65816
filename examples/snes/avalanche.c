// #22 — the on-SNES 64-BIT AVALANCHE matrix, rendered in Mode 7.
//
// A 64x56 image where cell (i,j) = output bit j of a 64-bit splitmix64 hash of a seed with INPUT bit
// i flipped (examples/65816/avalanche.h). On the 16-bit 65816 every hash is a pile of multi-limb
// libcalls — __muldi3 (64x64 multiply), __lshrdi3/__ashldi3 (64-bit shifts incl. variable counts and
// the whole-limb >>32), __adddi3, 64-bit xor — the integer-width family no Round-1 demo touches.
//
// The picture IS the proof: for a correct mixer, flipping ANY one input bit flips ~half the output
// bits, so the matrix is ~50% dense with no structure — a shimmering rainbow field (hue banded down
// the output-bit axis, palette-cycled). A 64-bit carry/shift/divide miscompile would either freeze
// the gate CRC mismatch or print visible structure. The seed crawls so the field keeps re-mixing.
//
// No far pointers — the 64x56 matrix lives in bank-0 WRAM — so the corpus slice (avalanche_sim.c) is
// a full 5-way differential. corpus_result carries the gate hash (h64_gate_crc, 256 chained
// splitmix64 + a 64-bit divide) == the host oracle tools/avalanche-sim == 0x27EA.
#include <snes.h>
#include "mode7.h"
#include "snesgfx/splash.h"
#include "../65816/avalanche.h"
#include "sincos.h"

#define CW 64                // matrix width  = 64 INPUT bits  (8 tiles)
#define CH 56                // matrix height = 56 OUTPUT bits shown (7 tiles)
#define NH 8                 // rainbow hue buckets (palette indices 1..NH; 0 = black)
#define TILES_W (CW / 8)     // 8
#define TILES_H (CH / 8)     // 7
#define SPIN_FRAMES 200      // vblanks of gentle Mode-7 drift + colour-cycle between re-mixes

volatile uint16_t corpus_result;       // near: the differential gate proof (h64_gate_crc)
static uint8_t mat[CW * CH];           // near: the 64x56 avalanche matrix (palette indices)
static const uint8_t m7_zero = 0;       // fixed-source byte for the tilemap-clear DMA
static uint16_t pal[NH + 1];           // base BGR555 palette, cached for the colour cycle
static uint8_t pshift = 0, pcount = 0;

static void load_palette(void) {
  REG_CGADD = 0;
  for (uint8_t n = 0; n <= NH; n++) {
    uint8_t r, g, b;
    h64_palette(n, NH, &r, &g, &b);
    uint16_t c = SNES_RGB(r, g, b);
    pal[n] = c;
    REG_CGDATA = (uint8_t)(c & 0xFF);
    REG_CGDATA = (uint8_t)(c >> 8);
  }
}

// Rotate the hue colours (indices 1..NH), keeping black (index 0) fixed so the cleared bits stay dark
// and only the set-bit bands flow.
static void cycle_palette(uint8_t shift) {
  REG_CGADD = 0;
  REG_CGDATA = (uint8_t)(pal[0] & 0xFF);            // black stays put
  REG_CGDATA = (uint8_t)(pal[0] >> 8);
  for (uint8_t n = 0; n < NH; n++) {
    uint8_t j = (uint8_t)(n + shift);
    if (j >= NH) j = (uint8_t)(j - NH);
    REG_CGDATA = (uint8_t)(pal[1 + j] & 0xFF);
    REG_CGDATA = (uint8_t)(pal[1 + j] >> 8);
  }
}

static void wait_vblank_fresh(void) { (void)REG_RDNMI; snes_wait_vblank(); }

static void tick_cycle(uint8_t every) {
  if (++pcount >= every) { pcount = 0; if (++pshift >= NH) pshift = 0; cycle_palette(pshift); }
}

// Compute one matrix column i (all CH output-bit rows) for `seed`. This is the 64-bit grind:
// h64_avalanche_col does a variable-count `1<<i` shift then splitmix64 (2 __muldi3 + shifts/xor).
// A set output bit gets a hue that banded down the rows; a cleared bit is black.
static void compute_col(uint8_t i, uint64_t seed) {
  uint64_t h = h64_avalanche_col(seed, i);
  for (uint8_t j = 0; j < CH; j++) {
    uint8_t bit = (uint8_t)((h >> j) & (uint64_t)1);     // __lshrdi3 (variable j) + mask
    uint8_t hue = (uint8_t)(1u + ((unsigned)j * NH) / CH);
    mat[(uint16_t)j * CW + i] = bit ? hue : 0u;
  }
}

// Reveal the matrix into Mode 7 character VRAM, one image row per vblank (Mode 7 interleaved high
// bytes, exactly like the fractal demos but reading the NEAR buffer — no far pointer). Holds the
// colour cycle + a gentle drift flowing.
static void blit_in(void) {
  for (uint8_t j = 0; j < CH; j++) {
    uint8_t trow = (uint8_t)(j >> 3), r = (uint8_t)(j & 7);
    wait_vblank_fresh();
    m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
    tick_cycle(2);
    for (uint8_t tcol = 0; tcol < TILES_W; tcol++) {
      snes_vram_addr((uint16_t)((uint16_t)(trow * TILES_W + tcol) * 64 + (uint16_t)r * 8));
      uint16_t base = (uint16_t)((uint16_t)j * CW + (uint16_t)tcol * 8);
      for (uint8_t c = 0; c < 8; c++) REG_VMDATAH = mat[base + c];
    }
  }
}

// One gentle Mode 7 frame: a slow rotation breathe about the centre + colour cycle (the matrix itself
// re-mixes only when the seed steps; between, the hardware keeps it alive).
static void drift_frame(uint8_t k) {
  wait_vblank_fresh();
  int16_t cs = SINCOS[(uint8_t)(k + 64)];
  int16_t sn = SINCOS[k];
  int16_t a = (int16_t)(((int32_t)cs * 0x0040) >> 8);
  int16_t b = (int16_t)(((int32_t)(-sn) * 0x0010) >> 8);
  int16_t c = (int16_t)(((int32_t)sn * 0x0010) >> 8);
  m7_set_matrix(a, b, c, a);
  tick_cycle(4);
}

int main(void) {
  snes_ppu_reset_blank();

  splash_show("64-BIT", "AVALANCHE", 90);

  // Differential proof: 256 chained splitmix64 + 64-bit divide folded into corpus_result. Stable from
  // boot, before any snapshot deadline. == oracle 0x27EA.
  corpus_result = h64_gate_crc();

  // One-time Mode 7 setup (force-blanked): enter Mode 7, clear tilemap, lay the 8x7 identity, load the
  // rainbow palette, frame the 64x56 image at 4x.
  m7_begin();
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES_W, TILES_H);
  load_palette();
  m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
  m7_set_center(CW / 2, CH / 2);
  m7_set_scroll((uint16_t)(int16_t)(-(128 - CW / 2)), (uint16_t)(int16_t)(-(112 - CH / 2)));
  m7_show();
  REG_NMITIMEN = NMITIMEN_NMI;

  uint64_t seed = (uint64_t)0xC0FFEE0064B17ULL;

  // Boot: grind the first matrix (64 columns of 64-bit hashing) then reveal it.
  for (uint8_t i = 0; i < CW; i++) compute_col(i, seed);
  blit_in();

  for (;;) {
    // Crawl the seed and re-mix the matrix in the background while Mode 7 drifts + colour-cycles.
    seed += (uint64_t)0x9E3779B97F4A7C15ULL;          // golden-ratio step (__adddi3)
    uint8_t coldone = 0;
    for (uint16_t k = 0; k < SPIN_FRAMES; k++) {
      drift_frame((uint8_t)k);
      if (coldone < CW) { compute_col(coldone, seed); coldone++; }
    }
    while (coldone < CW) { compute_col(coldone, seed); coldone++; }
    blit_in();
  }
}
