// Fenwick Tree (Binary-Indexed Tree) — #63 of the compiler stress-test demo battery.
// Renders the verified, portable Fenwick tree (examples/65816/fenwick.h — the same header the host oracle
// tools/fenwick-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it builds
// default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A moving triangular bump updates the 16 bins each frame (point updates); the running prefix sum (the
// integral) is queried back out and drawn as a rising staircase below the signal. Both the point update
// (`i += i & -i`) and the prefix query (`i -= i & -i`) walk the tree using the `i & -i` low-bit-isolation
// two's-complement trick — a codegen shape none of the first 62 demos emit.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/fenwick.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define SIG_TOP     0          // signal bars occupy cell-rows 0..7
#define INT_TOP     8          // integral bars occupy cell-rows 8..15

// BG3 2bpp palette (CGRAM 0..3): empty / signal (green) / integral (amber) / axis (grey).
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(2, 4, 8), SNES_RGB(8, 28, 12), SNES_RGB(31, 22, 6), SNES_RGB(16, 16, 18),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  Fenwick      fw;
  uint16_t     t;
} App;

volatile uint16_t corpus_result;  // Fenwick gate CRC (read from WRAM by the differential gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Draw an 8-tall bar in column cx, height h (0..8), colour col, with its base at row (top+7).
static void draw_bar(BitmapCanvas *cv, uint8_t cx, uint8_t top, uint8_t h, uint8_t col) {
  for (uint8_t r = 0; r < 8; r++)
    cell_fill(cv, cx, (uint8_t)(top + r), (r >= (uint8_t)(8u - h)) ? col : 0u);
}

// Recompute: update all bins to the current signal (point updates), then draw signal + integral. noinline.
__attribute__((noinline))
static void field_step(App *a) {
  for (uint16_t i = 1u; i <= FW_N; i++) fw_set(&a->fw, i, fw_signal(i, a->t));   // point updates (i&-i up)
  int16_t total = fw_prefix(&a->fw, FW_N);                                        // prefix query (i&-i down)
  if (total < 1) total = 1;
  for (uint16_t i = 1u; i <= FW_N; i++) {
    uint8_t cx = (uint8_t)(i - 1u);
    int16_t s = fw_signal(i, a->t);
    uint8_t sh = (uint8_t)((s > 8) ? 8 : ((s < 0) ? 0 : s));
    draw_bar(&a->canvas, cx, SIG_TOP, sh, 1u);                                    // signal bar (green)
    int16_t pfx = fw_prefix(&a->fw, i);                                           // running integral
    uint8_t ih = (uint8_t)(((int32_t)pfx * 8) / total);
    if (ih > 8u) ih = 8u;
    draw_bar(&a->canvas, cx, INT_TOP, ih, 2u);                                    // integral bar (amber)
  }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  fw_clear(&a->fw);
  a->t = 0u;
  text_puts(&a->text, 0, 1, "FENWICK TREE  (i & -i)");
  text_puts(&a->text, 1, 0, "SIGNAL / RUNNING INTEGRAL (PREFIX SUM)");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "FENWICK TREE", "i & -i  PREFIX SUMS");
  corpus_result = fenwick_gate_crc();           // self-verify the BIT math == host 0x3454
  title_end(&a.screen, &title, 110);
  field_step(&a);
  static uint8_t sub = 0;
  for (;;) {
    if (++sub >= 8u) { sub = 0u; a.t++; field_step(&a); }   // advance the bump every 8 frames
    display_frame(&a.screen);
  }
}
