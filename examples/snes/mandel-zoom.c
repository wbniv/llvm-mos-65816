// Interactive SNES Mandelbrot ZOOM PYRAMID — true increasing detail as you zoom in (#321 M2).
//
// Builds on the interactive Mode 7 fly-around (mandel-interactive.c), which only MAGNIFIES a
// single baked image (no new detail on zoom-in). Here the HOST bakes a STACK of L Mandelbrot
// levels, each 2x finer zoom centered on one iconic point (the real-axis mini-Mandelbrot), all
// tiled into Mode 7 character order and baked into ROM (examples/snes/pyramid_image.h, generated
// by tools/mandel-bake-pyramid.c). At boot the ROM DMAs level 0 straight ROM->VRAM — INSTANT. Then
// Mode 7 hardware-zooms the current level; when zoom crosses a 2x threshold the ROM DMAs the next
// (finer) level and resets the Mode 7 scale, so the dive runs into GENUINELY NEW fractal structure
// — and the SNES does ZERO fractal math (depth is limited only by the host's double precision, not
// the on-console Q5.10). See docs/plans/2026-06-25-321-mandelbrot-zoom-pyramid.md.
//
//   L / R ........ zoom out / in (crosses levels)      Y / A .... rotate
//   Select ....... cycle palette                       Start .... reset to level 0
//
// What this exercises for +mos-a16: the fractal is baked, but the per-frame view->matrix math AND
// the LEVEL-SWAP threshold arithmetic in examples/snes/zoom.h are live +mos-a16 customers — four
// 16x16->32 fixed-point multiplies (the Mode 7 matrix) plus the 16-bit scale/level state machine.
// Gated by a host==target differential: the ROM logs the pads it actually read (pad_log[]) + a
// rolling CRC of the per-frame (lvl, scale, angle, matrix) (zoom_crc); dev/jgxcheck.cpp -DJGX_ZOOM
// replays zoom.h over that ground-truth log and asserts an identical CRC. Separately, the ROM
// hashes EVERY baked level at boot (level_hash[]) and the harness asserts each == its host
// reference (MANDEL_PYR_HASH[k]) — so every displayed level IS the verified deeper Mandelbrot.
//
// The upload is a plain ROM->VRAM DMA (no far pointer), so this builds BOTH default-8bit and
// +mos-a16 — a host==default==+mos-a16 differential. Capture: dev/run.sh mandel-zoom.
#include <snes.h>
#include "mode7.h"
#include "../65816/mandel.h"   // img_hash16 (per-level boot gate over the baked character data)
#include "zoom.h"              // pure zoom math + (via pyramid_image.h) MANDEL_PYR/PAL/SINCOS/HASH

#define PADLOG_N 64            // bounded, fully-logged test window (frames). 64 u16 = 128 B WRAM.

#define TILES_W     (MANDEL_PYR_W / 8)                       // image tiles per row (8x8 chars)
#define TILES_H     (MANDEL_PYR_H / 8)
#define LEVEL_BYTES ((uint16_t)(MANDEL_PYR_W * MANDEL_PYR_H)) // chr bytes per level (DMA count)

// WRAM proof channels (near, low WRAM .bss). Read by the emulator harness; volatile so the
// per-frame writes are not optimised away.
volatile uint16_t corpus_result;             // level_hash[0] — the single-value smoke / MAME gate
volatile uint16_t level_hash[MANDEL_PYR_L];  // per-level img_hash16 (each asserted == host ref)
volatile uint16_t zoom_crc;                  // rolling CRC of per-frame zoom state + Mode 7 matrix
volatile uint8_t  nframes;                   // frames folded into zoom_crc (capped at PADLOG_N)
volatile uint8_t  cur_level;                 // level currently displayed (informational channel)
volatile uint16_t pad_log[PADLOG_N];         // ground-truth pad reads, for the host replay

static const uint8_t m7_zero = 0;            // fixed-source byte for the tilemap clear DMA

// Rewrite CGRAM with the shared palette rotated by `shift` (the Select-cycled colour effect).
// Called inside vblank (<= MANDEL_NCOL words), so no mid-frame CGRAM glitch.
static void cycle_palette(uint8_t shift) {
  REG_CGADD = 0;
  for (uint8_t i = 0; i < MANDEL_NCOL; i++) {
    uint8_t j = (uint8_t)(i + shift);
    if (j >= MANDEL_NCOL) j = (uint8_t)(j - MANDEL_NCOL);
    uint16_t c = MANDEL_PAL[j];
    REG_CGDATA = (uint8_t)(c & 0xFF);
    REG_CGDATA = (uint8_t)(c >> 8);
  }
}

// DMA level `lvl`'s character data ROM->VRAM (high bytes). Single-bank (Phase 1): every level is a
// near ROM const, so a 16-bit source address in bank $00 reaches it. (Phase 2 multi-bank splits a
// per-level far-symbol into bank:addr16 instead.) The tilemap is set ONCE at boot and untouched by
// this high-byte DMA, so a swap is just this one transfer — instant.
static void dma_level(uint8_t lvl) {
  m7_dma_chr(0x00, (uint16_t)(uintptr_t)MANDEL_PYR[lvl], LEVEL_BYTES);
}

// Push the current zoom to the PPU: Mode 7 matrix (precomputed in `m`) + palette rotation.
// Hardware-only — the pure math it consumes lives in zoom.h.
static void apply_zoom(const zoom_t *z, const int16_t m[4]) {
  m7_set_matrix(m[0], m[1], m[2], m[3]);
  cycle_palette(z->pal);
}

int main(void) {
  snes_ppu_reset_blank();

  // Instant upload: level-0 character data ROM->VRAM (high bytes), tilemap clear + identity.
  dma_level(0);
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES_W, TILES_H);
  m7_cgram_load(MANDEL_PAL, MANDEL_NCOL);

  m7_begin();                            // Mode 7, BG1 main screen (still force-blanked)
  // Pivot zoom on the image centre (the baked deep point) and place that point at the SCREEN
  // centre (256x224 -> 128,112) so the dive homes there. M7 fixed point = screen (M7X-HOFS,
  // M7Y-VOFS) <-> source (M7X,M7Y); set M7X/Y to the image centre and offset the scroll to put it
  // at the screen centre.
  m7_set_center(MANDEL_PYR_W / 2, MANDEL_PYR_H / 2);
  m7_set_scroll((uint16_t)(int16_t)(MANDEL_PYR_W / 2 - 128),
                (uint16_t)(int16_t)(MANDEL_PYR_H / 2 - 112));

  zoom_t z; zoom_reset(&z);
  int16_t m[4];
  zoom_matrix(&z, m);
  apply_zoom(&z, m);                      // initial view (level 0, fill scale)
  m7_show();                             // release force-blank — INSTANT Mandelbrot (just a DMA)

  // Boot gate: hash EVERY baked level and assert each == its host reference (MANDEL_PYR_HASH[k]).
  // Fast rolling hash (not CRC16) so all L finish in a few frames with level 0 already on screen.
  for (uint8_t k = 0; k < MANDEL_PYR_L; k++)
    level_hash[k] = img_hash16(MANDEL_PYR[k], LEVEL_BYTES);
  corpus_result = level_hash[0];
  cur_level = 0;

  uint16_t vc = 0xFFFF;
  uint8_t  nf = 0;
  for (;;) {                             // steady-state 60 fps: zoom + level swap + Mode 7 matrix
    snes_wait_vblank();
    uint16_t pad = snes_read_pad1();
    if (zoom_step(&z, pad)) {             // level changed -> DMA the new (finer/coarser) level
      dma_level(z.lvl);
      cur_level = z.lvl;
    }
    zoom_matrix(&z, m);
    apply_zoom(&z, m);
    if (nf < PADLOG_N) {                  // first PADLOG_N frames: the verifiable zoom-math window
      pad_log[nf] = pad;
      vc = zoom_fold(vc, &z, m);
      nf++;
      zoom_crc = vc;
      nframes = nf;
    }
  }
}
