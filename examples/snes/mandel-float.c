// #21 — the on-SNES SOFT-FLOAT Mandelbrot, rendered in MODE 7 via FAR stores.
//
// The soft-float companion to mandel-display.c / julia.c. Where those iterate z^2+c in Q5.10
// FIXED-POINT, this one iterates it in IEEE-754 single-precision `float` (examples/65816/mandel-
// float.h). The 65816 has no FPU, so every multiply/add/subtract/compare/divide in the escape-time
// inner loop is a SOFT-FLOAT LIBCALL (__mulsf3/__addsf3/__subsf3/__divsf3/__gtsf2/__floatsisf) —
// the whole library no other demo touches. It is correspondingly SLOW (hundreds of instructions per
// pixel), which is the point: the visible grind IS the proof that real software floating point is
// running on the console.
//
// Same display trick as Julia: a 16x14 coarse escape-time grid is computed ONE ROW PER SPIN FRAME
// (so the heavy soft-float compute is spread invisibly under a smooth Mode-7 spin/zoom), then
// 4x-UPSCALED into a high-WRAM escape framebuffer at $7E2000 (FAR STORES, the #320 sta [dp] path)
// and FAR-LOADED line by line into Mode 7 character VRAM. Each full turn it advances to the next
// ZOOM WINDOW (MF_WIN[0..5], framing the whole set then diving toward the seahorse spiral) and
// wipes the freshly-ground image in top-to-bottom.
//
// mos-a16-only — far pointers are 32-bit, so this needs +mos-a16. corpus_result carries the
// differential gate hash (mf_gate_crc, a far-pointer-free 6x6 low-WRAM fold + bit-exact orbit
// witness — so the corpus slice is a full 5-way test) == the host oracle tools/mandel-float-sim ==
// 0x4169.
#include <snes.h>
#include "mode7.h"
#include "snesgfx/splash.h"
#include "../65816/mandel-float.h"
#include "sincos.h"

#define DW 64                // image width  (8 tiles)
#define DH 56                // image height (7 tiles)
#define DN 8                 // display maxiter (escape 0..8 -> 9-entry palette). Soft-float is slow,
                             // so keep this modest; the GATE uses MF_GATE_ITER (12) independently of DN.
#define CW 16                // COARSE compute grid: 16x14, 4x-upscaled into the 64x56 framebuffer.
#define CH 14                // 64/16 = 56/14 = 4 = 2^SH, so the upscale is a shift. Deliberately CHUNKY:
#define SHX 2                // at hundreds of soft-float libcalls per pixel a full-res grind would take
#define SHY 2                // minutes, so each fat pixel literally IS hundreds of __mulsf3/__addsf3.
#define SPIN_FRAMES 256      // vblanks of smooth Mode-7 spin/zoom between recomputes (one full turn)
#define TILES_W (DW / 8)     // 8
#define TILES_H (DH / 8)     // 7

// Canonical 64x56 escape buffer in HIGH WRAM ($7E2000) — reachable only via 24-bit/far addressing,
// so filling + reading it exercises the #320 far store/load path. 3584 B.
static M7_FAR uint8_t *const fb = (M7_FAR uint8_t *)0x7E2000u;

volatile uint16_t corpus_result;       // near: the differential gate proof (mf_gate_crc)
static uint8_t coarse[CW * CH];        // near: the CW x CH escape grid, upscaled into fb each morph
static const uint8_t m7_zero = 0;       // fixed-source byte for the tilemap-clear DMA
static uint16_t pal[DN + 1];           // base BGR555 palette, cached for the colour cycle
static uint8_t pshift = 0, pcount = 0;  // colour-cycle state

// DN+1 CGRAM entries (escape 0..DN) = the Mandelbrot palette. 8bpp direct index: the Mode 7 pixel
// value == escape count == the palette index. Also cached in pal[] for cycling.
static void load_palette(void) {
  REG_CGADD = 0;
  for (uint8_t n = 0; n <= DN; n++) {
    uint8_t r, g, b;
    mf_palette(n, DN, &r, &g, &b);
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

// Compute one coarse row j (CW cells) of the escape-time grid for zoom window `win`. This is the
// SOFT-FLOAT grind — three __mulsf3 + several __addsf3/__subsf3 + __gtsf2 per iteration in mf_cell,
// and __divsf3/__floatsisf for the per-pixel coordinate. Called ONE ROW PER SPIN FRAME.
static void compute_coarse_row(uint8_t j, const float *win) {
  float re0 = win[0], im0 = win[1];
  float dre = win[2] / (float)CW;        // __divsf3
  float dim = win[3] / (float)CH;
  float fj = (float)j;                   // __floatsisf
  float jdim = fj * dim;                 // __mulsf3
  float ci = im0 + jdim;                 // __addsf3
  uint8_t *row = &coarse[(uint16_t)j * CW];
  for (uint8_t i = 0; i < CW; i++) {
    float fi = (float)i;                 // __floatsisf
    float idre = fi * dre;               // __mulsf3
    float cr = re0 + idre;               // __addsf3
    row[i] = mf_cell(cr, ci, DN);
  }
}

// Reveal the freshly-computed coarse grid: UPSCALE 2x into fb (FAR STORES) and FAR-LOAD each image
// line into Mode 7 character VRAM in vblank. The new image sweeps in top-to-bottom.
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

// PROGRESSIVE boot paint: compute one coarse row, then immediately upscale + reveal its block of
// display rows, so the very first image grinds in top-to-bottom AS it is computed — there is never a
// long blank screen, and the visible crawl IS the proof that each fat pixel costs hundreds of
// soft-float libcalls. Used for the first window only; later windows recompute in the spin
// background and wipe_in (so the set keeps spinning while the next zoom grinds).
static void boot_paint(const float *win) {
  m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
  for (uint8_t jc = 0; jc < CH; jc++) {
    compute_coarse_row(jc, win);                                  // slow soft-float grind, one row
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

  // Brand FIRST so the boot isn't a blank screen: the soft-float gate below grinds ~9 s (every op a
  // libcall), so show "SOFT-FLOAT MANDELBROT" up front — the ensuing compute reads as "working", not
  // "broken".
  splash_show("SOFT-FLOAT", "MANDELBROT", 150);

  // Differential proof: fold the 2-window 6x6 gate + bit-exact orbit witness (low WRAM, far-pointer-
  // free) into corpus_result. Slow (soft-float) but stable well before any snapshot deadline.
  corpus_result = mf_gate_crc();

  // One-time Mode 7 setup (force-blanked): enter Mode 7, clear the tilemap, lay the 8x7 identity,
  // load the palette, frame the 64x56 image at 4x.
  m7_begin();
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES_W, TILES_H);
  load_palette();
  m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);
  m7_set_center(DW / 2, DH / 2);
  m7_set_scroll((uint16_t)(int16_t)(-(128 - DW / 2)), (uint16_t)(int16_t)(-(112 - DH / 2)));
  m7_show();
  REG_NMITIMEN = NMITIMEN_NMI;

  // Boot frame: grind window 0 in PROGRESSIVELY (paint each coarse row as it is computed), so the
  // first soft-float image crawls in top-to-bottom instead of leaving a long blank screen.
  uint8_t win = 0;
  boot_paint(MF_WIN[win]);

  for (;;) {
    // Advance to the next zoom window (W0..W5 then wrap) — the image we will grind during this spin.
    win = (uint8_t)((win + 1u < (unsigned)MF_NWIN) ? win + 1u : 0u);

    // Spin the CURRENT image one full turn while computing the NEXT window's coarse grid, one row
    // per frame. Soft-float is slow, so a row may span several vblanks; the spin keeps the affine
    // matrix moving each vblank regardless, and the grind finishes within the turn.
    uint8_t rowdone = 0;
    for (uint16_t k = 0; k < SPIN_FRAMES; k++) {
      spin_frame((uint8_t)k);
      if (rowdone < CH) { compute_coarse_row(rowdone, MF_WIN[win]); rowdone++; }
    }
    while (rowdone < CH) { compute_coarse_row(rowdone, MF_WIN[win]); rowdone++; }

    // Reveal the freshly-ground zoom level (sweeps in top-to-bottom), then spin onward.
    wipe_in();
  }
}
