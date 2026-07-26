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
#include "snesgfx/m7title.h"
#include "../65816/avalanche.h"
#include "sincos.h"

#define CW 64                // matrix width  = 64 INPUT bits  (8 tiles)
#define CH 56                // matrix height = 56 OUTPUT bits shown (7 tiles)
#define NH 8                 // rainbow hue buckets (palette indices 1..NH; 0 = black)
#define TILES_W (CW / 8)     // 8
#define TILES_H (CH / 8)     // 7
#define SPIN_FRAMES 150      // vblanks of gentle Mode-7 breathe + colour-cycle between re-mixes

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

// Compute one matrix column i (all CH output-bit rows) for `seed`. The 64-bit grind is the hash:
// h64_avalanche_col does a variable-count `1<<i` shift then splitmix64 (2 __muldi3 + shifts/xor).
// Bit extraction is then done by splitting the 64-bit result into four 16-bit words ONCE (four
// __lshrdi3) and pulling bits with cheap NATIVE 16-bit shifts — NOT 56 variable 64-bit shifts per
// column (which made the boot a ~6 s black screen). A set output bit gets a hue banded down the rows;
// a cleared bit is black. Bit-identical to `(h >> j) & 1` for j = 0..CH-1.
static void compute_col(uint8_t i, uint64_t seed) {
  uint64_t h = h64_avalanche_col(seed, i);
  uint16_t words[4];
  words[0] = (uint16_t)h;  words[1] = (uint16_t)(h >> 16);
  words[2] = (uint16_t)(h >> 32);  words[3] = (uint16_t)(h >> 48);
  uint8_t j = 0;
  for (uint8_t w = 0; w < 4 && j < CH; w++) {
    uint16_t v = words[w];
    for (uint8_t b = 0; b < 16 && j < CH; b++, j++) {
      uint8_t hue = (uint8_t)(1u + ((unsigned)j * NH) / CH);
      mat[(uint16_t)j * CW + i] = (v & 1u) ? hue : 0u;
      v = (uint16_t)(v >> 1);                            // native 16-bit shift — fast
    }
  }
}

// Chunked replica of h64_gate_crc (examples/65816/avalanche.h): folds the 256-step splitmix64 + 64-bit
// divide a few iterations per FRAME so the proof computes in the BACKGROUND instead of freezing the
// screen for ~5 s (the slow __udivdi3 path). MUST stay byte-identical to h64_gate_crc — same seed,
// same per-iteration ops, same final fold — so corpus_result == the oracle 0x27EA.
static uint64_t g_s = (uint64_t)0x0123456789ABCDEFULL;
static uint64_t g_acc = (uint64_t)0xFFFFFFFFFFFFFFFFULL;
static uint16_t g_k = 0;
static uint8_t g_done = 0;
static void gate_step(uint8_t iters) {
  if (g_done) return;
  for (uint8_t n = 0; n < iters && g_k < (uint16_t)H64_GATE_N; n++, g_k++) {
    g_s = h64_mix(g_s);
    g_acc ^= g_s;
    g_acc = g_acc + (g_s >> 17);
    uint64_t d = g_s | (uint64_t)1;
    g_acc = g_acc ^ (g_acc / d);
  }
  if (g_k >= (uint16_t)H64_GATE_N) {
    uint16_t hh = 0;
    for (uint8_t w = 0; w < 4; w++) {
      uint16_t word = (uint16_t)(g_acc >> (uint8_t)(w * 16));
      hh = (uint16_t)((uint16_t)(((unsigned)hh << 1) | ((unsigned)hh >> 15)) ^ word);
    }
    corpus_result = hh;
    g_done = 1;
  }
}

// Upload the matrix into Mode 7 character VRAM (Mode 7 interleaved high bytes; near buffer, no far
// pointer). ROWS_PER_VB image rows per vblank — ~64 byte-writes/row, so 4 rows ≈ 256 writes, well
// inside the ~1.5 KiB V-blank budget — so the whole 64x56 frame refreshes in CH/ROWS_PER_VB = 14
// vblanks (~0.23 s) instead of a slow 56-frame scan. All writes happen after wait_vblank_fresh().
#define ROWS_PER_VB 4
static void blit_in(void) {
  uint8_t j = 0;
  while (j < CH) {
    wait_vblank_fresh();
    m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
    tick_cycle(2);
    for (uint8_t n = 0; n < ROWS_PER_VB && j < CH; n++, j++) {
      uint8_t trow = (uint8_t)(j >> 3), r = (uint8_t)(j & 7);
      for (uint8_t tcol = 0; tcol < TILES_W; tcol++) {
        snes_vram_addr((uint16_t)((uint16_t)(trow * TILES_W + tcol) * 64 + (uint16_t)r * 8));
        uint16_t base = (uint16_t)((uint16_t)j * CW + (uint16_t)tcol * 8);
        for (uint8_t c = 0; c < 8; c++) REG_VMDATAH = mat[base + c];
      }
    }
  }
}

// One gentle Mode 7 frame: an axis-aligned zoom-BREATHE about the centre + colour cycle. The matrix
// re-mixes only when the seed steps; between, the hardware keeps it alive. Kept axis-aligned (no
// rotation) for two reasons: the rainbow bands are SEMANTIC (one hue per output-bit row, so a tilt
// would scramble the reading), and — load-bearing — an off-diagonal Mode-7 matrix with the diagonal
// (A=D=cos·z) passing through zero is SINGULAR and collapses the whole image to black (the original
// bug). Breathing only A=D around 0x40 (never near 0) keeps the determinant healthy and the full
// frame visible at all times.
static void drift_frame(uint8_t k) {
  wait_vblank_fresh();
  int16_t z = (int16_t)(0x0040 + (((int32_t)SINCOS[k] * 0x0008) >> 8));   // ~0x38..0x48, always > 0
  m7_set_matrix(z, 0x0000, 0x0000, z);
  tick_cycle(4);
}

int main(void) {
  snes_ppu_reset_blank();

  m7splash("64-BIT", "AVALANCHE", 90);

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

  // Boot: grind the first matrix (64 columns of 64-bit hashing) and reveal it FAST, so the avalanche
  // is on screen in ~2 s instead of behind a long black boot.
  for (uint8_t i = 0; i < CW; i++) compute_col(i, seed);
  blit_in();

  for (;;) {
    // Crawl the seed and re-mix the matrix in the background while Mode 7 breathes + colour-cycles.
    seed += (uint64_t)0x9E3779B97F4A7C15ULL;          // golden-ratio step (__adddi3)
    uint8_t coldone = 0;
    for (uint16_t k = 0; k < SPIN_FRAMES; k++) {
      drift_frame((uint8_t)k);
      gate_step(2);                                   // fold the differential proof in the background
      if (coldone < CW) { compute_col(coldone, seed); coldone++; }
    }
    while (coldone < CW) { compute_col(coldone, seed); coldone++; }
    blit_in();
  }
}
