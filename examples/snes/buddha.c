// #4 Buddhabrot — escaping-orbit DENSITY accumulation on the SNES (Mode 7), the compiler
// stress-test battery's PRNG + far scatter-write member.
//
// Random complex c (xorshift16) is iterated z<-z^2+c from z=0; for the c that ESCAPE, the orbit is
// replayed and every visited (zr,zi) increments a 128x128 hit-count grid in HIGH WRAM ($7E2000) via
// the #320 far read-modify-write path (lda [dp] / saturate-compare / inc / sta [dp]) at a RUNTIME-
// computed index. Over many escaping orbits the accumulated density resolves into the ghostly,
// smoke-like silhouette. The hit count IS the 8bpp Mode 7 pixel (a CGRAM index), revealed one tile-
// row per frame (build_band far-loads a band of the grid into a NEAR buffer in tiled order,
// dma_chr_to DMAs it to VRAM — one far pointer live per helper, the grid_hash idiom that sidesteps
// the +mos-a16 far-pointer pressure trap). The cloud BLOOMS progressively as samples accumulate.
//
// mos-a16-only — a far pointer is a 32-bit value, so this requires +mos-a16 (the prebuilt 8-bit
// toolchain can't legalize the far G_PTR_ADD). dev/build.sh greps for the "mos-a16-only" marker.
//
// Differential channel (3-way bar, host == +mos-a16 on bsnes-jg + MAME): corpus_result is the far-
// load hash of the grid after a DETERMINISTIC K_GATE-sample accumulation (fixed seed) == the host
// oracle examples/65816/k_buddha_far.c -DHOST -DK_GATE=K_GATE. The grid then keeps blooming to
// K_BLOOM for the richer on-screen image (the gate snapshot is taken at exactly K_GATE).
//
// Capture / drive: dev/run.sh buddha.  Live play: task buddha-play.
// Plan: docs/plans/2026-06-28-4-snes-buddhabrot.md.
#define BUD_GRID 128                              // 16 KiB grid in $7E2000 (1:1 with the display)
#include <snes.h>
#include "mode7.h"
#include "snesgfx/m7title.h"
#include "../65816/buddha.h"

// Gate point (deterministic, == the host oracle) and the final on-screen sample budget. K_GATE must
// match the oracle's; the gate hash is snapshotted at exactly K_GATE samples, then the bloom
// continues. (Both tuned in the plan's verification pass.)
#ifndef K_GATE
#define K_GATE  2000u
#endif
#ifndef K_BLOOM
#define K_BLOOM 40000u                            // total samples for the finished image (then static)
#endif
#define SAMP_PER_FRAME 24u                        // samples accumulated per frame (bloom granularity)

#define TILES     16                              // 128/8 — Mode 7 tiles per axis
#define ROW_BYTES 1024                            // one Mode 7 tile-row of character data (16*64)
#define MAG       0x0080                          // Mode 7 matrix: 2x magnify (128 grid fills 256 wide)
#define PLOT_HBIAS ((int16_t)-64)                 // centre grid 64 at screen centre 128 (64-128)
#define PLOT_VBIAS ((int16_t)-48)                 // centre grid 64 at screen centre 112 (64-112)

#define FAR __attribute__((address_space(2)))
static FAR uint8_t *const grid = (FAR uint8_t *)0x7E2000u;   // 16 KiB far density grid

BUD_DEFINE_CLEAR(grid_clear, FAR)
BUD_DEFINE_PLOT (grid_plot,  FAR)
BUD_DEFINE_ACCUM(grid_accum, FAR, grid_plot)
BUD_DEFINE_HASH (grid_hash,  FAR)

static const uint8_t m7_zero = 0;                 // fixed-source byte for the tilemap/VRAM clears
static uint8_t  chrbuf[ROW_BYTES];                // near: one tile-row staged for DMA
static uint16_t cgbuf[256];                       // near: the ghost-glow CGRAM image, staged for DMA
static bud_rng  rng;                              // persistent PRNG state (bloom continues across frames)

volatile uint16_t corpus_result;                  // near proof channel: grid hash at K_GATE == oracle

// Ghostly glow palette: index 0 = black (no hits); indices 1..255 a dark->bright ramp with a SQRT
// brightness curve (so sparse filaments stay visible while the dense core doesn't blow straight to a
// white blob) tinted blue->white for the ethereal "ghost" look. The hit count is the index, so the
// curve maps count -> brightness. CAP sets the count that reaches full white; counts above it clamp.
#define PAL_CAP 14u
static uint8_t isqrt32(uint32_t v) {
  uint32_t r = 0, b = 1uL << 14;                  // largest power-of-4 <= our max operand (~961*255)
  while (b > v) b >>= 2;
  while (b) {
    if (v >= r + b) { v -= r + b; r = (r >> 1) + b; } else { r >>= 1; }
    b >>= 2;
  }
  return (uint8_t)r;
}
static void build_palette(void) {
  cgbuf[0] = 0;                                   // no hits -> black backdrop
  for (uint16_t i = 1; i < 256; i++) {
    uint16_t c = (i < PAL_CAP) ? i : (uint16_t)PAL_CAP;
    // t = round(sqrt(c / CAP) * 31) via isqrt(c * 31*31 / CAP); 0..31 brightness. The sqrt curve lifts
    // sparse low counts into a faint blue haze (the "ghostly" orbit density) while the dense core
    // saturates toward white — and stays graded as the cloud keeps blooming past the preview frame.
    uint8_t t = isqrt32((uint32_t)c * (uint32_t)(31u * 31u) / (uint32_t)PAL_CAP);
    if (t > 31) t = 31;
    uint8_t b = t;                                // blue leads (dim = deep blue)
    uint8_t g = (uint8_t)(t * 7u / 8u);
    uint8_t r = (uint8_t)(t * 5u / 8u);           // red lags (bright = white)
    cgbuf[i] = SNES_RGB(r, g, b);
  }
}

// Far-load tile-row `trow` (8 image rows) of the grid into near chrbuf in Mode 7 tiled order — one
// far pointer live -> near writes (the grid_hash idiom). noinline bounds +mos-a16 pressure (§4).
__attribute__((noinline)) static void build_band(uint8_t trow) {
  for (uint8_t tcol = 0; tcol < TILES; tcol++)
    for (uint8_t r = 0; r < 8; r++)
      for (uint8_t c = 0; c < 8; c++) {
        uint8_t x = (uint8_t)(tcol * 8 + c), y = (uint8_t)(trow * 8 + r);
        chrbuf[(uint16_t)tcol * 64 + (uint16_t)r * 8 + c] =
            grid[(uint16_t)((uint16_t)y * BUD_GRID + x)];   // hit count IS the CGRAM index
      }
}

// DMA ROW_BYTES of character data from near chrbuf into Mode 7 VRAM HIGH bytes at word `destword`.
static void dma_chr_to(uint16_t destword) {
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = destword;
  REG_DMAP0 = 0x00; REG_BBAD0 = 0x19;
  REG_A1T0L = (uint8_t)(uintptr_t)chrbuf; REG_A1T0H = (uint8_t)((uintptr_t)chrbuf >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = (uint8_t)ROW_BYTES; REG_DAS0H = (uint8_t)(ROW_BYTES >> 8);
  REG_MDMAEN = 0x01;
}

// DMA the staged ghost palette cgbuf -> CGRAM (512 bytes in vblank).
static void dma_cgram(void) {
  REG_CGADD = 0;
  REG_DMAP0 = 0x00; REG_BBAD0 = 0x22;             // A->B inc, dest $2122 (CGDATA)
  REG_A1T0L = (uint8_t)(uintptr_t)cgbuf; REG_A1T0H = (uint8_t)((uintptr_t)cgbuf >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = 0x00; REG_DAS0H = 0x02;             // 512 bytes (256 BGR555 entries)
  REG_MDMAEN = 0x01;
}

// Clear all 64 KB of VRAM to 0 (force-blank only) — bsnes randomises power-on VRAM, and the Mode 7
// character rows are filled only one band/frame, so without a boot clear the plot area shows random
// tiles for the first ~16 frames. Two fixed-source DMAs (low byte then high byte of every word).
static void vram_clear_all(void) {
  REG_VMAIN = VMAIN_INC_LOW_1; REG_VMADD = 0;
  REG_DMAP0 = 0x08; REG_BBAD0 = 0x18;             // A->B, FIXED source -> $2118
  REG_A1T0L = (uint8_t)(uintptr_t)&m7_zero; REG_A1T0H = (uint8_t)((uintptr_t)&m7_zero >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = 0x00; REG_DAS0H = 0x80;             // 0x8000 words
  REG_MDMAEN = 0x01;
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = 0;
  REG_DMAP0 = 0x08; REG_BBAD0 = 0x19;             // -> $2119
  REG_A1T0L = (uint8_t)(uintptr_t)&m7_zero; REG_A1T0H = (uint8_t)((uintptr_t)&m7_zero >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = 0x00; REG_DAS0H = 0x80;
  REG_MDMAEN = 0x01;
}

int main(void) {
  snes_ppu_reset_blank();
  // Title splash (~1.5 s), then it restores force-blank + self-clears its VRAM. The grid-hash
  // corpus_result is deterministic (timing-independent), so the splash's frame shift can't change it.
  m7splash("ORBIT DENSITY", "BUDDHABROT", 90);
  vram_clear_all();                       // wipe random power-on VRAM before anything is displayed
  m7_begin();
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES, TILES);
  m7_set_center(64, 64);                  // pivot the Mode 7 transform around the grid centre
  m7_set_matrix(MAG, 0x0000, 0x0000, MAG);
  m7_set_scroll((uint16_t)PLOT_HBIAS, (uint16_t)PLOT_VBIAS);   // centre the 128 grid in the screen

  grid_clear(grid);                       // WRAM is not zeroed at boot (bsnes randomises)
  bud_rng_init(&rng, BUD_SEED);
  build_palette();
  dma_cgram();                            // load CGRAM before display (no garbage-colour first frame)
  m7_show();                              // release force-blank; the cloud blooms in live below
  REG_NMITIMEN = NMITIMEN_NMI;            // VBlank NMI -> snes_wait_vblank pacing

  uint32_t done = 0;
  uint8_t  trow = 0, gated = 0;
  for (;;) {
    if (done < K_BLOOM) {
      uint16_t chunk = SAMP_PER_FRAME;
      if (done < K_GATE && done + chunk > K_GATE) chunk = (uint16_t)(K_GATE - done);  // land on K_GATE
      if (done + chunk > K_BLOOM)                 chunk = (uint16_t)(K_BLOOM - done);
      grid_accum(grid, &rng, chunk);              // far scatter-write accumulation
      done += chunk;
    }
    build_band(trow);                             // reveal/refresh one band (far-load -> near)

    snes_wait_vblank();                           // --- vblank: DMA only ---
    dma_chr_to((uint16_t)trow * ROW_BYTES);
    trow = (uint8_t)((trow + 1) & (TILES - 1));

    // Gate: once the deterministic K_GATE accumulation completes, hash it == the host oracle. `done`
    // lands on K_GATE exactly (the chunk cap above), so the hash matches the oracle bit-for-bit.
    if (!gated && done >= K_GATE) { corpus_result = grid_hash(grid); gated = 1; }
  }
}
