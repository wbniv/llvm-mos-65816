// Perlin Gradient-Noise Flow Field — #68 of the compiler stress-test demo battery.
// Renders the verified, portable fixed-point Perlin noise (examples/65816/perlin.h — the same header the
// host oracle tools/perlin-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// Each cell's colour is 2-D Perlin gradient noise of its (x, y) plus a scrolling time offset: a
// permutation table + the Hermite quintic fade polynomial 6t^5-15t^4+10t^3 + gradient dot products +
// lerp, all fixed-point. The field flows like smoke/marble. A codegen corner none of the first 67 demos
// run: the perm-index + fade-polynomial + dot-of-gradients + interpolation pipeline.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/perlin.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       16
#define NCOL        4
#define BAND        4             // recompute BAND cell-rows/frame (fixed-point Perlin is __mulsi3-heavy)
#define PN_SCALE    160           // Q8.8 units per cell (~0.625 Perlin cells)

// BG3 2bpp palette (CGRAM 0..3): a smoke/marble ramp — deep indigo -> violet -> teal -> cream.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(3, 3, 12), SNES_RGB(18, 8, 26), SNES_RGB(8, 24, 26), SNES_RGB(30, 30, 22),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     t;
  uint8_t      band;
} App;

volatile uint16_t corpus_result;  // Perlin gate CRC (read from WRAM by the differential gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Recompute one BAND of cell-rows from Perlin noise at the current scroll. noinline caps register pressure.
__attribute__((noinline))
static void field_band(App *a) {
  uint8_t y0 = (uint8_t)(a->band * BAND);
  int32_t sx = (int32_t)((uint16_t)(a->t * 6u));            // slow diagonal scroll (Q8.8)
  int32_t sy = (int32_t)((uint16_t)(a->t * 4u));
  for (uint8_t cy = y0; cy < (uint8_t)(y0 + BAND) && cy < NCELL; cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      int32_t n = pn_noise((int32_t)cx * PN_SCALE + sx, (int32_t)cy * PN_SCALE + sy);
      uint8_t col = (uint8_t)(((n + 256) >> 7) & 3u);        // map ~[-256,256] -> 4 bands
      cell_fill(&a->canvas, cx, cy, col);
    }
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
  pn_init();
  a->t = 0u; a->band = 0u;
  text_puts(&a->text, 0, 2, "PERLIN NOISE");
  text_puts(&a->text, 1, 0, "FADE 6t5-15t4+10t3  GRAD DOT + LERP");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "PERLIN NOISE", "GRADIENT FIELD");
  corpus_result = perlin_gate_crc();            // self-verify the noise math == host 0xA72D
  title_end(&a.screen, &title, 110);
  for (;;) {
    a.t++;
    field_band(&a);
    a.band++;
    if (a.band * BAND >= NCELL) a.band = 0u;
    display_frame(&a.screen);
  }
}
