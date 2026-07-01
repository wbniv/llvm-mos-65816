// Bit-Census Field — #53 of the compiler stress-test demo battery.
// Renders the verified, portable bit-population census (examples/65816/bitcensus.h — the same header
// the host oracle tools/bitcensus-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas
// (BG3), so it builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// Each cell's colour is a bit-count of a 64-bit value built from its (x, y, time) coordinates, cycling
// through the four bit-population intrinsics:
//   __builtin_popcountll -> XOR/AND bit-fractal | __builtin_clzll -> magnitude bands
//   __builtin_ctzll      -> ruler bands         | __builtin_parityll -> parity checker
// On the 65816 these inline-lower via G_CTPOP/G_CTLZ/G_CTTZ (MOSLegalizerInfo.cpp:308 `.lower()`) —
// the SWAR popcount masks 0x55/0x33/0xF0 show up in the disasm.  A codegen corner none of the first 52
// demos ever emit.  The `ll` (64-bit) builtins are width-identical host vs target -> bit-exact gate.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // full-canvas redraw fits ONE v-blank (4 KB; see #16/#40)
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/bitcensus.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define CELL        8                // 8x8 px per census cell -> 16x16 cells over the 128x128 canvas
#define NCELL       (CANVAS_W / CELL)   // 16
#define NCOL        4                // BG3 2bpp: 4 colours
#define BAND        4                // recompute BAND cell-rows/frame (64-bit bit-counts are heavier)
#define FN_HOLD     150u             // frames each intrinsic is shown before cycling to the next

// BG3 2bpp palette (CGRAM 0..3): indigo -> magenta -> cyan -> white.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(3, 2, 12), SNES_RGB(28, 6, 24), SNES_RGB(6, 26, 28), SNES_RGB(31, 31, 31),
};

// Two-row HUD labels, one per intrinsic (top row is fixed, bottom row names the live function).
static const char *const fn_name[4] = {
  "POPCOUNT  BIT-FRACTAL",
  "CLZ  MAGNITUDE BANDS ",
  "CTZ  RULER SEQUENCE  ",
  "PARITY  CHECKER      ",
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     t;        // frame counter (drives function cycle)
  uint16_t     t_snap;   // t captured at the START of each 4-band cycle — held constant so all
                         // bands in the cycle use the same sx/sy/tt (prevents scroll seam)
  uint8_t      band;     // which BAND of cell-rows to recompute this frame
  uint8_t      fn;       // live intrinsic (0..3)
  uint8_t      fn_shown; // fn currently written to the HUD (avoid redundant text redraw)
} App;

volatile uint16_t corpus_result;  // bit-census gate CRC (read from WRAM by the differential gate)

// Fill an 8x8 cell at (cx,cy) with 2bpp colour (0..3), writing whole tile bytes directly.
static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);   // one cell == one 8x8 tile
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Recompute one BAND of cell-rows from the bit-census at snapshot t. noinline caps RA.
__attribute__((noinline))
static void field_band(App *a, uint16_t t_snap) {
  uint8_t y0 = (uint8_t)(a->band * BAND);
  uint16_t sx = (uint16_t)(t_snap >> 2);      // diagonal scroll — same for all bands in a cycle
  uint16_t sy = (uint16_t)(t_snap >> 3);
  uint16_t tt = (uint16_t)(t_snap >> 4);
  for (uint8_t cy = y0; cy < (uint8_t)(y0 + BAND) && cy < NCELL; cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      uint8_t census = bitcensus_cell((uint16_t)(cx + sx), (uint16_t)(cy + sy), tt, a->fn);
      cell_fill(&a->canvas, cx, cy, bitcensus_color(census, NCOL));
    }
  // re-DMA just this band of the canvas (BAND rows * NCELL tiles)
  uint16_t lo = (uint16_t)((uint16_t)y0 * CANVAS_TILES_W);
  uint16_t hi = (uint16_t)(lo + (uint16_t)BAND * CANVAS_TILES_W - 1u);
  if (hi > (uint16_t)(CANVAS_NTILES - 1)) hi = (uint16_t)(CANVAS_NTILES - 1);
  if (a->canvas.lo > lo) a->canvas.lo = lo;
  if (a->canvas.hi < hi) a->canvas.hi = hi;
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->t = 0u;
  a->t_snap = 0u;
  a->band = 0u;
  a->fn = 0u;
  a->fn_shown = 0xFFu;
  text_puts(&a->text, 0, 2, "BIT-CENSUS FIELD");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "BIT-CENSUS", "POPCOUNT/CLZ/CTZ");
  corpus_result = bitcensus_gate_crc();         // self-verify the census math == host 0x9516
  title_end(&a.screen, &title, 110);
  for (;;) {
    a.t++;
    a.fn = (uint8_t)(((uint16_t)(a.t / FN_HOLD)) & 3u);
    if (a.fn != a.fn_shown) {                    // update the HUD label only when the function changes
      text_puts(&a.text, 1, 0, fn_name[a.fn]);
      a.fn_shown = a.fn;
    }
    field_band(&a, a.t_snap);                    // all bands in a cycle share the same snapshot
    a.band++;
    if (a.band * BAND >= NCELL) {
      a.band = 0u;
      a.t_snap = a.t;                            // advance snapshot only after a full redraw cycle
    }
    display_frame(&a.screen);
  }
}
