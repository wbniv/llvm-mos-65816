/* examples/snes/burning-ship.c — Burning Ship fractal SNES demo (#3 of the compiler stress-test
 * battery). Renders the verified, portable escape-time fractal (examples/65816/burning_ship.h — the
 * same header the host oracle tools/burning-ship-sim.c and the corpus slice run) into a 32×28 grid of
 * solid-colour BG1 4bpp tiles (the doom-fire display model), so it builds default-8-bit AND +mos-a16
 * AND +mos-xy16 (no far pointers → the full 5-way bar).
 *
 * The whole ship is computed once, progressively (a few rows per frame, a top-to-bottom reveal), then
 * the 15 escape-band colours are CYCLED through CGRAM each frame so the bands flow. Interior cells
 * (never escape) stay black.
 *
 * Codegen under test: the Burning Ship map z_{n+1}=(|Re z|+i|Im z|)²+c — three Q12 __mulsi3 per
 * iteration plus the two abs folds that distinguish it from the Mandelbrot. Multiply-only (no divide).
 * corpus_result = bs_gate_crc() (16×16 window, maxiter 24), set once at startup.                    */
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/vram.h"
#include "../65816/burning_ship.h"

#define BS_W   32u            /* grid width  in cells (= screen tile cols) */
#define BS_H   28u            /* grid height in cells (= screen tile rows) */
#define BS_MAXI 16u           /* escape-iteration cap (kept modest: the full-grid grind blocks behind
                               * the title, and interior cells run the full count) */

/* World window (Q12) over the whole ship: x ∈ [−2.2, 1.0], y ∈ [0.6, −1.81] (row 0 = top = high y). */
#define WIN_X0  ((int16_t)-9011)   /* −2.2  */
#define WIN_DX  ((int16_t)410)     /*  3.2 / 32 per col  */
#define WIN_Y0  ((int16_t)2458)    /*  0.6  */
#define WIN_DY  ((int16_t)366)     /*  2.5 / 28 per row (subtracted) */

/* ---- VRAM layout (fixed) ------------------------------------------------------ */
#define BS_CHR  0x0000u   /* BG1 chr: 16 solid-colour 4bpp tiles */
#define BS_MAP  0x4000u   /* BG1 tilemap: 32×32 */

/* Base 16-colour escape ramp: 0 = black (interior ship silhouette); 1..15 a VIVID
 * blue→cyan→green→yellow→orange→red→pink→white ramp (bright even at the low end so the fast-escape
 * "sea" is visible, not near-black). */
static const uint16_t bs_base_pal[16] = {
  SNES_RGB( 0, 0, 0), SNES_RGB( 2, 8,24), SNES_RGB( 2,14,28), SNES_RGB( 2,20,30),
  SNES_RGB( 4,26,28), SNES_RGB( 6,30,22), SNES_RGB(10,31,14), SNES_RGB(18,31, 8),
  SNES_RGB(26,30, 4), SNES_RGB(31,26, 2), SNES_RGB(31,20, 1), SNES_RGB(31,14, 2),
  SNES_RGB(31, 8, 6), SNES_RGB(31, 6,16), SNES_RGB(31,12,26), SNES_RGB(31,24,31),
};

static uint8_t  bs_grid[BS_W * BS_H];   /* colour index per cell */
static uint16_t bs_pal[16];             /* live (cycled) palette */

/* ---- BsLayer drawable (BG1 4bpp, full-tilemap + palette DMA per frame) --------
 * The grid is small (32×28 = 896 tiles → 1792 B), and Display force-blanks during the DMA flush, so
 * the whole tilemap is pushed in one job each frame (no half-alternation to get wrong). */
typedef struct {
  Drawable base;
  uint16_t shadow[BS_H * BS_W];           /* full tilemap shadow (28*32 = 896 words) */
} BsLayer;

static void _bs_reserve(Drawable *d, VramAlloc *va) {
  (void)va;
  BsLayer *l = (BsLayer *)d;
  REG_BG1SC   = SNES_BGSC(BS_MAP, 0);
  REG_BG12NBA = (uint8_t)((BS_CHR >> 12) & 0x0Fu);
  /* 16 solid-colour 4bpp tiles (each 16 words; bitplane row = 0xFF where the colour bit is set). */
  snes_vram_addr(BS_CHR);
  for (uint8_t c = 0; c < 16; c++) {
    uint16_t bp01 = (uint16_t)((c & 2 ? 0xFF00u : 0u) | (c & 1 ? 0x00FFu : 0u));
    uint16_t bp23 = (uint16_t)((c & 8 ? 0xFF00u : 0u) | (c & 4 ? 0x00FFu : 0u));
    for (uint8_t r = 0; r < 8; r++) REG_VMDATA = bp01;
    for (uint8_t r = 0; r < 8; r++) REG_VMDATA = bp23;
  }
  snes_vram_addr(BS_MAP);
  for (uint16_t i = 0; i < (uint16_t)(32u * 32u); i++) REG_VMDATA = 0u;
  l->base.tm_bits = TM_BG1;
}

static void _bs_emit(Drawable *d, UploadQueue *q) {
  BsLayer *l = (BsLayer *)d;
  upq_push_cgram(q, 0u, bs_pal, 0x00u, (uint16_t)sizeof bs_pal);     /* cycled palette */
  for (uint16_t n = 0; n < (uint16_t)(BS_H * BS_W); n++) l->shadow[n] = bs_grid[n];
  upq_push_vram(q, BS_MAP, l->shadow, 0x00u, (uint16_t)(BS_H * BS_W * 2u), VMAIN_INC_HIGH_1);
}

static const DrawableVT BS_VT = { _bs_reserve, _bs_emit };

/* Compute one grid row r (escape-time → colour index). noinline bounds a16/xy16 register pressure. */
__attribute__((noinline))
static void compute_row(uint8_t r) {
  int16_t cy = (int16_t)(WIN_Y0 - (int16_t)((int16_t)r * WIN_DY));
  uint8_t *row = bs_grid + (uint16_t)r * BS_W;
  for (uint8_t c = 0; c < BS_W; c++) {
    int16_t cx = (int16_t)(WIN_X0 + (int16_t)((int16_t)c * WIN_DX));
    uint8_t n = bs_iter(cx, cy, (uint8_t)BS_MAXI);
    row[c] = (n >= (uint8_t)BS_MAXI) ? 0u : (uint8_t)(1u + (n % 15u));
  }
}

/* Rotate the 15 escape-band colours (1..15) by one step; colour 0 (interior) stays black. */
static void cycle_palette(uint8_t phase) {
  bs_pal[0] = bs_base_pal[0];
  for (uint8_t i = 1; i < 16; i++)
    bs_pal[i] = bs_base_pal[1u + (uint8_t)((i - 1u + phase) % 15u)];
}

volatile uint16_t corpus_result;

int main(void) {
  uint16_t i;
  for (i = 0; i < (uint16_t)(BS_W * BS_H); i++) bs_grid[i] = 0u;
  for (i = 0; i < 16; i++) bs_pal[i] = bs_base_pal[i];

  corpus_result = bs_gate_crc();          /* self-verify == host 0x6F2D */

  static BsLayer bl;
  bl.base.vt = &BS_VT;

  Display d;
  display_init(&d);
  display_add(&d, (Drawable *)&bl);

  /* Title overlay (BG2). The full-grid escape-time compute is too heavy to reveal progressively at
     60 fps (interior cells run the full 24-iteration grind), so compute the WHOLE ship in one blocking
     pass while the title masks it (no display_frame during the compute → the PPU keeps showing the
     title). Then tear the title down and flow the escape bands forever. */
  static TitleLayer title;
  title_init(&title, "BURNING SHIP", "FRACTAL");
  display_add(&d, (Drawable *)&title);
  display_frame(&d);                      /* show the title (grid still black underneath) */

  for (uint8_t r = 0; r < (uint8_t)BS_H; r++) compute_row(r);   /* compute the whole ship */

  display_hold(&d, 30);                   /* hold the title a beat after the grind finishes */
  display_hide_layer(&d, (Drawable *)&title);

  uint8_t phase = 0;
  for (;;) {
    phase = (uint8_t)(phase + 1u);        /* flow the 15 escape bands */
    cycle_palette(phase);
    display_frame(&d);
  }
}
