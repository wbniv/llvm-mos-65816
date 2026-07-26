// #1 — the on-SNES fixed-point JULIA-set explorer, rendered in MODE 7 via FAR stores.
//
// The Julia companion to mandel-display.c. The 65816 iterates z_{n+1} = z_n^2 + c (the same Q5.10
// escape-time kernel, examples/65816/julia.h) but with z_0 = the PIXEL coordinate and c a single
// complex CONSTANT for the whole frame, animated along the classic 0.7885*e^{i*theta} orbit
// (JULIA_CPATH). Every full Mode-7 turn it RE-GRINDS the set for the next c — a 32x28 escape-time
// grid (three 16x16->32 multiplies per iteration), one row per spin frame so the compute is spread
// invisibly — then 2x-UPSCALES it into a high-WRAM escape framebuffer at $7E2000 (FAR STORES, the
// #320 sta [dp] path) and FAR-LOADS each line back (lda [dp]) into Mode 7 character VRAM. So the
// heavy complex multiply is the SUSTAINED morph engine, and the hardware affine matrix is the motion
// (Mandelbrot computes once then only spins; Julia keeps grinding to morph).
//
// mos-a16-only — far pointers are 32-bit values, so this needs +mos-a16 (the 16-bit-accumulator
// target); the 8-bit toolchain can't legalize the far G_PTR_ADD.
//
// SMOOTH 60 fps — the set rotates + zoom-breathes + colour-cycles continuously while the next c is
// computed in the background; every turn it wipes in the freshly-morphed set top-to-bottom (an active
// reveal, never a freeze). corpus_result carries the differential gate hash (julia_gate_crc, a
// 4-keyframe 6x6 low-WRAM fold — far-pointer-free, so the corpus slice is a full 5-way test) == the
// host oracle tools/julia-sim == 0x3490.
#include <snes.h>
#include "mode7.h"
#include "snesgfx/m7title.h"
#include "../65816/julia.h"
#include "sincos.h"

#define DW 64                // image width  (8 tiles)
#define DH 56                // image height (7 tiles)
#define DN 10                // display maxiter (escape 0..10 -> an 11-entry palette); the GATE uses
                             // JULIA_GATE_N (8) independently, so DN is free to tune for morph speed.
#define CW 32                // COARSE compute grid width  (escape-time is ~22 s at 64x56 on the 65816,
#define CH 28                // far too slow to morph — compute 32x28 (4x fewer cells) ONE ROW PER SPIN
#define SHX 1                // FRAME so the fractal never freezes, then nearest-neighbour UPSCALE 2x
#define SHY 1                // into the 64x56 far framebuffer. 64/32 = 56/28 = 2 = 2^SH, so the upscale
                             // is a shift. The grind is still real; the far store/load path is full.
#define SPIN_FRAMES 256      // vblanks of smooth Mode-7 spin/zoom between recomputes (one full turn)
#define TILES_W (DW / 8)     // 8
#define TILES_H (DH / 8)     // 7

// Canonical 64x56 escape buffer in HIGH WRAM ($7E2000) — reachable only via 24-bit/far addressing,
// so filling + reading it exercises the #320 far store/load path (sta [dp] / lda [dp]). 3584 B.
static M7_FAR uint8_t *const fb = (M7_FAR uint8_t *)0x7E2000u;

volatile uint16_t corpus_result;       // near: the differential gate proof (julia_gate_crc)
static uint8_t coarse[CW * CH];        // near: the CW x CH escape grid, upscaled into fb each morph
static const uint8_t m7_zero = 0;       // fixed-source byte for the tilemap-clear DMA
static uint16_t pal[DN + 1];           // base BGR555 palette, cached for the colour cycle
static uint8_t pshift = 0, pcount = 0;  // colour-cycle state, shared across spin + wipe-in

// 13 CGRAM entries (escape 0..DN) = the Julia palette (julia.h). 8bpp direct index: the Mode 7
// pixel value == escape count == the palette index. Also cached in pal[] for cycling.
static void load_palette(void) {
  REG_CGADD = 0;
  for (uint8_t n = 0; n <= DN; n++) {
    uint8_t r, g, b;
    julia_palette(n, DN, &r, &g, &b);
    uint16_t c = SNES_RGB(r, g, b);
    pal[n] = c;
    REG_CGDATA = (uint8_t)(c & 0xFF);
    REG_CGDATA = (uint8_t)(c >> 8);
  }
}

// Steady colour cycle: rewrite CGRAM with the escape colours (indices 0..DN-1) rotated by `shift`,
// keeping the interior (index DN) black so only the bands flow. Called in vblank.
static void cycle_palette(uint8_t shift) {
  REG_CGADD = 0;
  for (uint8_t n = 0; n < DN; n++) {
    uint8_t j = (uint8_t)(n + shift);
    if (j >= DN) j = (uint8_t)(j - DN);
    REG_CGDATA = (uint8_t)(pal[j] & 0xFF);
    REG_CGDATA = (uint8_t)(pal[j] >> 8);
  }
  REG_CGDATA = (uint8_t)(pal[DN] & 0xFF);          // interior stays put (black)
  REG_CGDATA = (uint8_t)(pal[DN] >> 8);
}

// Block until the NEXT true vblank. The reveal points follow long computes (many vblanks elapse
// unread), so clear the stale RDNMI flag FIRST — otherwise snes_wait_vblank() returns immediately
// mid-frame and the upload would corrupt VRAM during active display.
static void wait_vblank_fresh(void) {
  (void)REG_RDNMI;
  snes_wait_vblank();
}

// Advance the colour cycle by one step every `every` calls (flows the escape bands).
static void tick_cycle(uint8_t every) {
  if (++pcount >= every) { pcount = 0; if (++pshift >= DN) pshift = 0; cycle_palette(pshift); }
}

// Compute one coarse row j (CW cells) of the escape-time grid for Julia constant c = (cr,ci).
// This is the fixed-point grind — three 16x16->32 __mulsi3 per iteration in julia_cell. Called
// ONE ROW PER SPIN FRAME so the heavy compute is spread across the spin and never freezes the screen.
static void compute_coarse_row(uint8_t j, int16_t cr, int16_t ci) {
  int16_t dre = (int16_t)(JULIA_REW / CW);
  int16_t dim = (int16_t)(JULIA_IMW / CH);
  int16_t zi0 = (int16_t)(JULIA_IM0 + (int16_t)j * dim);
  uint8_t *row = &coarse[(uint16_t)j * CW];
  for (uint8_t i = 0; i < CW; i++) {
    int16_t zr0 = (int16_t)(JULIA_RE0 + (int16_t)i * dre);
    row[i] = julia_cell(zr0, zi0, cr, ci, DN);
  }
}

// Reveal the freshly-computed coarse grid: UPSCALE 2x into fb (FAR STORES) and FAR-LOAD each image
// line into Mode 7 character VRAM in vblank, at the crisp axis-aligned framing. The new set sweeps
// in top-to-bottom (an active reveal, not a freeze). Holds the colour cycle flowing.
static void wipe_in(void) {
  m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
  for (uint8_t j = 0; j < DH; j++) {
    uint8_t trow = (uint8_t)(j >> 3), r = (uint8_t)(j & 7);
    const uint8_t *crow = &coarse[(uint16_t)(j >> SHY) * CW];
    for (uint8_t i = 0; i < DW; i++)
      fb[(uint16_t)j * DW + i] = crow[i >> SHX];                       // FAR STORE (upscale)
    wait_vblank_fresh();
    m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);                     // hold base framing while wiping
    tick_cycle(3);
    for (uint8_t tcol = 0; tcol < TILES_W; tcol++) {                   // 8 tiles, row r of each
      snes_vram_addr((uint16_t)((uint16_t)(trow * TILES_W + tcol) * 64 + (uint16_t)r * 8));
      uint16_t base = (uint16_t)((uint16_t)j * DW + (uint16_t)tcol * 8);
      for (uint8_t c = 0; c < 8; c++) REG_VMDATAH = fb[base + c];      // FAR LOAD
    }
  }
}

// One smooth Mode 7 frame: rotate + zoom-breathe about the image centre (pure affine matrix, latched
// in vblank), colour-cycle. `k` is the rotation phase (0..255 = one full turn).
static void spin_frame(uint8_t k) {
  wait_vblank_fresh();
  int16_t zoom = (int16_t)(0x0030 + (((int32_t)SINCOS[(uint8_t)(k >> 1)] * 0x0010) >> 8));
  int16_t cs = SINCOS[(uint8_t)(k + 64)];                             // cos (8.8)
  int16_t sn = SINCOS[k];                                             // sin (8.8)
  int16_t a = (int16_t)(((int32_t)cs * zoom) >> 8);
  int16_t b = (int16_t)(((int32_t)(-sn) * zoom) >> 8);
  int16_t c = (int16_t)(((int32_t)sn * zoom) >> 8);
  m7_set_matrix(a, b, c, a);                                          // A=D=cos*zoom, B=-sin*zoom, C=sin*zoom
  tick_cycle(6);
}

int main(void) {
  snes_ppu_reset_blank();                       // force-blank + zero PPU control regs

  // Differential proof first: fold the 4-keyframe 6x6 gate (low WRAM, far-pointer-free) into
  // corpus_result. Stable from boot (~frame 90), long before any snapshot deadline. == oracle 0x3490.
  corpus_result = julia_gate_crc();

  // Title splash (Mode 7 has no spare BG): ~1.5 s, then it restores force-blank and self-clears its
  // VRAM so the Mode 7 setup below starts clean.
  m7splash("Z^2 + C", "JULIA SET", 90);

  // One-time Mode 7 setup (force-blanked): enter Mode 7, clear the 128x128 tilemap, lay the 8x7
  // identity, load the palette, frame the 64x56 image at 4x (a=d=0x0040 -> fills 256x224).
  m7_begin();
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES_W, TILES_H);
  load_palette();
  m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
  // Centered pivot: the steady-state spin rotates about the image centre, and angle-0 / zoom-0x40
  // reproduces the crisp axis-aligned 4x framing (mandel-display's steady-state pivot).
  m7_set_center(DW / 2, DH / 2);
  m7_set_scroll((uint16_t)(int16_t)(-(128 - DW / 2)), (uint16_t)(int16_t)(-(112 - DH / 2)));
  m7_show();                                     // boot is black (no image yet), not a flash
  REG_NMITIMEN = NMITIMEN_NMI;                   // enable vblank NMI (crt0's weak `rti` handler is safe)

  // The trick (Mandelbrot's): the fixed-point grind is the MORPH, the hardware affine transform is
  // the MOTION. A 64x56 escape-time recompute is ~22 s on the 65816 — far too slow to morph — so we
  // compute a 32x28 coarse grid ONE ROW PER SPIN FRAME (the heavy 3-__mulsi3/iter julia_cell loop,
  // spread invisibly across the spin), then 2x-UPSCALE it into the far framebuffer and wipe it in.
  // Result: the Julia set rotates + zoom-breathes + colour-cycles SMOOTHLY at 60 fps, and every full
  // turn it morphs to the next c along the path — never a frozen frame. corpus_result is untouched.
  uint8_t phase = 0, sub = 0;
  const uint8_t SUBSTEPS = 4;                     // interpolation steps between adjacent keyframes

  // Boot frame: compute keyframe 0 fully (one-time ~3 s, screen black) and reveal it.
  for (uint8_t j = 0; j < CH; j++) compute_coarse_row(j, JULIA_CPATH[0][0], JULIA_CPATH[0][1]);
  wipe_in();

  for (;;) {
    // Advance c to the next substep along the orbit (the c we will compute during this spin).
    if (++sub >= SUBSTEPS) { sub = 0; if (++phase >= JULIA_NPHASE) phase = 0; }
    uint8_t nph = (uint8_t)((phase + 1u < JULIA_NPHASE) ? phase + 1u : 0u);
    int16_t cr0 = JULIA_CPATH[phase][0], ci0 = JULIA_CPATH[phase][1];
    int16_t cr1 = JULIA_CPATH[nph][0],   ci1 = JULIA_CPATH[nph][1];
    // c = c0 + (c1-c0)*sub/SUBSTEPS  (a 16x16->32 __mulsi3 per axis; /SUBSTEPS folds to a shift).
    int16_t cr = (int16_t)(cr0 + (int16_t)(((int32_t)(cr1 - cr0) * sub) / SUBSTEPS));
    int16_t ci = (int16_t)(ci0 + (int16_t)(((int32_t)(ci1 - ci0) * sub) / SUBSTEPS));

    // Spin the CURRENT image one full turn while computing the NEXT set's coarse grid, one row per
    // frame (CH rows finish well inside SPIN_FRAMES, then it is pure spin).
    uint8_t rowdone = 0;
    for (uint16_t k = 0; k < SPIN_FRAMES; k++) {
      spin_frame((uint8_t)k);
      if (rowdone < CH) { compute_coarse_row(rowdone, cr, ci); rowdone++; }
    }
    while (rowdone < CH) { compute_coarse_row(rowdone, cr, ci); rowdone++; }

    // Reveal the freshly-morphed set (sweeps in top-to-bottom), then spin onward to the next c.
    wipe_in();
  }
}
