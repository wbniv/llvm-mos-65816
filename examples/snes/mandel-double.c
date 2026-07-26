// #33 — the on-SNES DOUBLE-PRECISION soft-float Mandelbrot, with a FLOAT twin, in MODE 7 via FAR stores.
//
// The 64-bit companion to mandel-float.c (#21). Where that iterates z^2+c in IEEE-754 SINGLE precision,
// this renders the set TWICE: the TOP half in 64-bit `double`, the BOTTOM half in 32-bit `float`. The
// 65816 has no FPU, so the top half is the entire DOUBLE soft-float library (__muldf3/__adddf3/__subdf3/
// __divdf3/__ltdf2/__floatsidf) — the library NO other demo touches — and casting the shared double
// window down to float coords for the bottom half pulls in __truncdfsf2 too. Double is ~2-3x slower than
// single (a register pair-of-pairs per value), which is the point: the visible grind IS the proof that
// real 64-bit floating point is running on the console.
//
// THE PRECISION CLIFF — why both halves look identical here. The split-screen renders the WHOLE SET
// (re_span 3.2), where the per-pixel step (~0.05) is FAR above float's ~1e-7 epsilon, so float and double
// agree pixel-for-pixel and the top/bottom seam is invisible (the set is symmetric about the real axis,
// so the double top and float bottom join seamlessly). That IS the honest console-scale result. The
// float-vs-double cliff only emerges at EXTREME zoom (re_span ~1e-6), where the per-pixel step drops below
// float's epsilon and the float side collapses into chunky blocks while double stays crisp — but resolving
// that depth needs HUNDREDS of iterations per pixel (uint8 maxiter can't even hold the count), i.e.
// minutes per frame in on-console double soft-float, so it is shown HOST-SIDE in the plan, not live. The
// live demo instead PROVES double correctness via the differential gate.
//
// mos-a16-only — far pointers are 32-bit, so this needs +mos-a16. corpus_result carries the differential
// gate hash (md_gate_crc, a far-pointer-free fold of a double escape buffer + a float escape buffer + a
// bit-exact double orbit witness + a double<->float conversion witness — so the corpus slice is a full
// 5-way test) == the host oracle tools/mandel-double-sim == 0x0EDF.
// ROM-SIZE CONSTRAINT — must precede the title_layer.h include. The double soft-float library alone is
// ~20 KB of this 32 KB LoROM bank (__adddf3 6728 B + __muldf3 5431 B + the float twin's __addsf3 3179 B
// + __mulsf3 2311 B + the float<->int/compare helpers), so there is no room for title_layer's 4 KB
// FONT16 Waldo table. TITLE_FONT16_OFF selects the legacy title path, which pixel-doubles the 8x8 font8
// into 16x16 glyphs instead — same title, ~4 KB cheaper, and it is what the shipped/published ROM has
// always been built with. This lives HERE, not in a per-example flag table in one build script, so every
// build path (dev/build.sh's example loop, dev/rebuild-web-roms.sh, dev/mandel-double.sh) gets it — the
// flag previously existed ONLY in dev/rebuild-web-roms.sh's EXTRA_CFLAGS, so `dev/run.sh build` could
// never link this demo. Guarded so an explicit -DTITLE_FONT16_OFF on the command line is not a
// redefinition.
#ifndef TITLE_FONT16_OFF
#define TITLE_FONT16_OFF
#endif

#include <snes.h>
#include "mode7.h"
#include "snesgfx/title_layer.h"
#include "../65816/mandel-double.h"
#include "sincos.h"

#define DW 64                // image width  (8 tiles)
#define DH 56                // image height (7 tiles)
#define DN 16                // display maxiter (escape 0..16 -> 17-entry palette). The GATE uses
                             // MD_GATE_ITER (6) independently of DN.
#define CW 16                // COARSE compute grid: 16x14, 4x-upscaled into the 64x56 framebuffer.
#define CH 14                // 64/16 = 56/14 = 4 = 2^SH, so the upscale is a shift.
#define SHX 2                // each fat pixel literally IS dozens of __muldf3/__adddf3 (double) on the top
#define SHY 2                // half, __mulsf3/__addsf3 (float) on the bottom.
#define SPIN_FRAMES 256      // vblanks of smooth Mode-7 spin/zoom between recomputes (one full turn)
#define TILES_W (DW / 8)     // 8
#define TILES_H (DH / 8)     // 7
#define CH_HALF (CH / 2)     // 7 — coarse rows < CH_HALF computed in DOUBLE, >= in FLOAT

// Canonical 64x56 escape buffer in HIGH WRAM ($7E2000) — reachable only via 24-bit/far addressing, so
// filling + reading it exercises the far store/load path. 3584 B.
static M7_FAR uint8_t *const fb = (M7_FAR uint8_t *)0x7E2000u;

volatile uint16_t corpus_result;       // near: the differential gate proof (md_gate_crc)
static uint8_t coarse[CW * CH];        // near: the CW x CH escape grid, upscaled into fb each morph
static const uint8_t m7_zero = 0;       // fixed-source byte for the tilemap-clear DMA
static uint16_t pal[DN + 1];           // base BGR555 palette, cached for the colour cycle
static uint8_t pshift = 0, pcount = 0;  // colour-cycle state

// DN+1 CGRAM entries (escape 0..DN) = the Mandelbrot palette. 8bpp direct index: the Mode 7 pixel value
// == escape count == the palette index. Also cached in pal[] for cycling.
static void load_palette(void) {
  REG_CGADD = 0;
  for (uint8_t n = 0; n <= DN; n++) {
    uint8_t r, g, b;
    md_palette(n, DN, &r, &g, &b);
    uint16_t c = SNES_RGB(r, g, b);
    pal[n] = c;
    REG_CGDATA = (uint8_t)(c & 0xFF);
    REG_CGDATA = (uint8_t)(c >> 8);
  }
}

// Steady colour cycle: rotate the escape colours (indices 0..DN-1), interior (index DN) stays black.
static void cycle_palette(uint8_t shift) {
  REG_CGADD = 0;
  for (uint8_t n = 0; n < DN; n++) {
    uint8_t j = (uint8_t)(n + shift);
    if (j >= DN) j = (uint8_t)(j - DN);
    REG_CGDATA = (uint8_t)(pal[j] & 0xFF);
    REG_CGDATA = (uint8_t)(pal[j] >> 8);
  }
  REG_CGDATA = (uint8_t)(pal[DN] & 0xFF);
  REG_CGDATA = (uint8_t)(pal[DN] >> 8);
}

// Block until the NEXT true vblank, clearing the stale RDNMI flag first (reveal points follow long
// computes, many vblanks elapse unread).
static void wait_vblank_fresh(void) {
  (void)REG_RDNMI;
  snes_wait_vblank();
}

static void tick_cycle(uint8_t every) {
  if (++pcount >= every) { pcount = 0; if (++pshift >= DN) pshift = 0; cycle_palette(pshift); }
}

// Compute one coarse row j (CW cells) of the escape-time grid for the WHOLE-SET window MD_WIN[0]. Rows in
// the TOP half (j < CH_HALF) are the DOUBLE grind — three __muldf3 + several __adddf3/__subdf3 + __gtdf2
// per iteration in md_cell_double — and rows in the BOTTOM half are the FLOAT twin (md_cell_float). The
// per-pixel step is derived from the CONSTANT window, so both divides constant-fold at compile time (no
// __divdf3/__divsf3 — keeping the ROM inside one 32 KiB LoROM bank; the float-divide corner is already
// #21's, and #33's stress is the double mul/add/sub/cmp + conversions, all preserved). The noinline cells
// keep the per-pixel escape math as REAL runtime soft-float libcalls. Called ONE ROW PER SPIN FRAME.
static void compute_coarse_row(uint8_t j) {
  uint8_t *row = &coarse[(uint16_t)j * CW];
  if (j < CH_HALF) {
    double re0 = MD_WIN[0][0], im0 = MD_WIN[0][1];
    double dre = MD_WIN[0][2] / (double)CW; // const-folds
    double dim = MD_WIN[0][3] / (double)CH;
    double fj = (double)j;                  // __floatsidf
    double jdim = fj * dim;                 // __muldf3
    double ci = im0 + jdim;                 // __adddf3
    for (uint8_t i = 0; i < CW; i++) {
      double fi = (double)i;                // __floatsidf
      double idre = fi * dre;               // __muldf3
      double cr = re0 + idre;               // __adddf3
      row[i] = md_cell_double(cr, ci, DN);
    }
  } else {
    float re0 = (float)MD_WIN[0][0], im0 = (float)MD_WIN[0][1];      // const-folds (__truncdfsf2 at CT)
    float dre = (float)(MD_WIN[0][2] / (double)CW); // const-folds
    float dim = (float)(MD_WIN[0][3] / (double)CH);
    float fj = (float)j;                    // __floatsisf
    float jdim = fj * dim;                  // __mulsf3
    float ci = im0 + jdim;                  // __addsf3
    for (uint8_t i = 0; i < CW; i++) {
      float fi = (float)i;                  // __floatsisf
      float idre = fi * dre;                // __mulsf3
      float cr = re0 + idre;                // __addsf3
      row[i] = md_cell_float(cr, ci, DN);
    }
  }
}

// Reveal the freshly-computed coarse grid: UPSCALE 4x into fb (FAR STORES) and FAR-LOAD each image line
// into Mode 7 character VRAM in vblank. The new image sweeps in top-to-bottom.
static void wipe_in(void) {
  m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
  for (uint8_t j = 0; j < DH; j++) {
    uint8_t trow = (uint8_t)(j >> 3), r = (uint8_t)(j & 7);
    const uint8_t *crow = &coarse[(uint16_t)(j >> SHY) * CW];
    for (uint8_t i = 0; i < DW; i++)
      fb[(uint16_t)j * DW + i] = crow[i >> SHX];                       // FAR STORE (upscale)
    wait_vblank_fresh();
    m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
    tick_cycle(3);
    for (uint8_t tcol = 0; tcol < TILES_W; tcol++) {                   // 8 tiles, row r of each
      snes_vram_addr((uint16_t)((uint16_t)(trow * TILES_W + tcol) * 64 + (uint16_t)r * 8));
      uint16_t base = (uint16_t)((uint16_t)j * DW + (uint16_t)tcol * 8);
      for (uint8_t c = 0; c < 8; c++) REG_VMDATAH = fb[base + c];      // FAR LOAD
    }
  }
}

// PROGRESSIVE boot paint: compute one coarse row, then immediately upscale + reveal its block of display
// rows, so the very first image grinds in top-to-bottom AS it is computed — there is never a long blank
// screen, and the visible crawl IS the proof that each fat pixel costs dozens of soft-float libcalls (the
// top half noticeably slower: those are 64-bit __muldf3, the bottom 32-bit __mulsf3).
static void boot_paint(void) {
  m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
  for (uint8_t jc = 0; jc < CH; jc++) {
    compute_coarse_row(jc);                                       // slow soft-float grind, one row
    const uint8_t *crow = &coarse[(uint16_t)jc * CW];
    for (uint8_t s = 0; s < (1u << SHY); s++) {
      uint8_t j = (uint8_t)(((uint16_t)jc << SHY) + s);           // display row this coarse row maps to
      for (uint8_t i = 0; i < DW; i++)
        fb[(uint16_t)j * DW + i] = crow[i >> SHX];                // FAR STORE (upscale)
      wait_vblank_fresh();
      m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
      tick_cycle(3);
      uint8_t trow = (uint8_t)(j >> 3), r = (uint8_t)(j & 7);
      for (uint8_t tcol = 0; tcol < TILES_W; tcol++) {            // 8 tiles, row r of each
        snes_vram_addr((uint16_t)((uint16_t)(trow * TILES_W + tcol) * 64 + (uint16_t)r * 8));
        uint16_t base = (uint16_t)((uint16_t)j * DW + (uint16_t)tcol * 8);
        for (uint8_t c = 0; c < 8; c++) REG_VMDATAH = fb[base + c];   // FAR LOAD
      }
    }
  }
}

// One smooth Mode 7 frame: rotate + zoom-breathe about the image centre, colour-cycle.
static void spin_frame(uint8_t k) {
  wait_vblank_fresh();
  int16_t zoom = (int16_t)(0x0030 + (((int32_t)SINCOS[(uint8_t)(k >> 1)] * 0x0010) >> 8));
  int16_t cs = SINCOS[(uint8_t)(k + 64)];
  int16_t sn = SINCOS[k];
  int16_t a = (int16_t)(((int32_t)cs * zoom) >> 8);
  int16_t b = (int16_t)(((int32_t)(-sn) * zoom) >> 8);
  int16_t c = (int16_t)(((int32_t)sn * zoom) >> 8);
  m7_set_matrix(a, b, c, a);
  tick_cycle(6);
}

int main(void) {
  snes_ppu_reset_blank();

  // Brand FIRST so the boot isn't a blank screen: the soft-float gate below grinds for several seconds
  // (every op a 64-bit libcall), so show "DOUBLE-PRECISION MANDELBROT" up front — the ensuing compute
  // reads as "working", not "broken".
  splash16("DOUBLE-FLOAT", "MANDELBROT", 150);

  // Differential proof: fold the double + float escape buffers + bit-exact double orbit witness + the
  // conversion witness (all low WRAM, far-pointer-free) into corpus_result.
  corpus_result = md_gate_crc();

  // The display always frames the WHOLE SET (MD_WIN[0]) — see the precision-cliff note at the top of this
  // file. compute_coarse_row derives both the double and the float coordinates from that constant window.

  // One-time Mode 7 setup (force-blanked): enter Mode 7, clear the tilemap, lay the 8x7 identity, load
  // the palette, frame the 64x56 image at 4x.
  m7_begin();
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES_W, TILES_H);
  load_palette();
  m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
  m7_set_center(DW / 2, DH / 2);
  m7_set_scroll((uint16_t)(int16_t)(-(128 - DW / 2)), (uint16_t)(int16_t)(-(112 - DH / 2)));
  m7_show();
  REG_NMITIMEN = NMITIMEN_NMI;

  // Boot frame: grind the set in PROGRESSIVELY (paint each coarse row as it is computed) — the top 7
  // coarse rows in double, the bottom 7 in float — so the first image crawls in top-to-bottom, the double
  // top half visibly slower than the float bottom.
  boot_paint();

  for (;;) {
    // Spin the rendered set one full turn while RE-grinding it, one coarse row per frame (keeps the
    // double + float soft-float running continuously), then reveal the fresh image and spin onward.
    uint8_t rowdone = 0;
    for (uint16_t k = 0; k < SPIN_FRAMES; k++) {
      spin_frame((uint8_t)k);
      if (rowdone < CH) { compute_coarse_row(rowdone); rowdone++; }
    }
    while (rowdone < CH) { compute_coarse_row(rowdone); rowdone++; }
    wipe_in();
  }
}
