// Complex Domain-Colouring with Poles — #58 of the compiler stress-test demo battery.
// Renders the verified, portable rational-map colouring (examples/65816/domcol.h — the same header the
// host oracle tools/domcol-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// Colours a grid by the complex rational map f(z) = (z^2-1)/(z^2+c). Where z^2+c == 0 the reciprocal
// gives +/-Inf or NaN, and the code branches on isnan/isinf (x != x -> __unordsf2; x == x -> __eqsf2) to
// paint the poles. Soft-float is VERY slow on the 65816, so the field (8x8 big cells, sampling the same
// z-range as the header's 16-grid at half resolution) is computed ONCE, live on-console, one row/frame
// (a "developing" reveal that proves the soft-float runs on hardware), then the palette cycles for life.
// A codegen corner none of the first 57 demos run: NaN/unordered floating-point compares. (The
// differential folds the COLOUR INDEX, never raw NaN bits.)
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/domcol.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NDISP       8               // 8x8 display cells (each 16x16 px) — soft-float is too slow for 16x16
#define NCOL        4

// Fixed map parameter with two visible poles (z^2 = -0.6 -> poles at z = +/- 0.775 i).
#define C_RE 0.6f
#define C_IM 0.0f

// BG3 2bpp palette (CGRAM 0..3); the non-zero entries cycle each frame for a shimmer.
static uint16_t bg3_pal[NCOL] = {
  SNES_RGB(2, 3, 9), SNES_RGB(6, 12, 28), SNES_RGB(31, 22, 6), SNES_RGB(31, 31, 31),
};
static const uint16_t pal_ring[3] = {                    // the 3 colours the shimmer rotates through
  SNES_RGB(6, 12, 28), SNES_RGB(31, 22, 6), SNES_RGB(20, 8, 28),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     frame;
  uint8_t      row;        // next display row to compute (0..NDISP); == NDISP means field done
  uint8_t      shimmer;
} App;

volatile uint16_t corpus_result;  // domain-colouring gate CRC (read from WRAM by the differential gate)

// Fill a 16x16 display cell (2x2 canvas tiles) at display (dx,dy) with 2bpp colour.
static void disp_fill(BitmapCanvas *cv, uint8_t dx, uint8_t dy, uint8_t color) {
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t ty = 0; ty < 2; ty++)
    for (uint8_t tx = 0; tx < 2; tx++) {
      uint16_t tile = (uint16_t)((uint16_t)((dy * 2u + ty)) * CANVAS_TILES_W + (dx * 2u + tx));
      uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
      for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
    }
}

// Compute one display row of the field (the live soft-float work). noinline caps register pressure.
__attribute__((noinline))
static void compute_row(App *a, uint8_t dy) {
  for (uint8_t dx = 0; dx < NDISP; dx++) {
    uint8_t col = domcol_cell((uint8_t)(dx * 2u), (uint8_t)(dy * 2u), C_RE, C_IM);  // sample 16-grid @ half-res
    disp_fill(&a->canvas, dx, dy, col);
  }
  uint16_t lo = (uint16_t)((uint16_t)(dy * 2u) * CANVAS_TILES_W);
  uint16_t hi = (uint16_t)(lo + 2u * CANVAS_TILES_W - 1u);
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
  a->frame = 0u;
  a->row = 0u;
  a->shimmer = 0u;
  text_puts(&a->text, 0, 1, "DOMAIN COLOURING");
  text_puts(&a->text, 1, 2, "RATIONAL MAP NAN POLES");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "DOMAIN COLOUR", "NaN / POLES");
  corpus_result = domcol_gate_crc();            // self-verify the map math == host 0xF3FD
  title_end(&a.screen, &title, 110);
  for (;;) {
    a.frame++;
    if (a.row < NDISP) {                         // developing: one soft-float row per frame
      compute_row(&a, a.row);
      a.row++;
    } else {                                     // done: cycle the palette for a shimmer
      a.shimmer = (uint8_t)((a.shimmer + 1u) % 3u);
      bg3_pal[1] = pal_ring[a.shimmer];
      bg3_pal[2] = pal_ring[(a.shimmer + 1u) % 3u];
      upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
    }
    display_frame(&a.screen);
  }
}
