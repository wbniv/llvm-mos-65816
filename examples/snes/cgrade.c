// Many-Argument Color-Grade Kernel — #50 of the compiler stress-test demo battery.
// A per-cell color grade sweeps ten coefficients over time, re-grading a base gradient
// (examples/65816/cgrade.h — the same 10-argument color_grade the host oracle tools/cgrade-sim.c and
// the corpus slice run), forcing the extra arguments onto the soft stack. No far pointers -> builds
// default-8-bit AND +mos-a16 AND +mos-xy16, the full 5-way bar.
//
// Codegen under test: >register-count argument spilling — color_grade takes 10 int16 params, so the
// extras spill onto the soft stack (.noinit..Lstatic_stack) and the callee reads them back off frame.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/cgrade.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       (CANVAS_W / 8)   // 16

static const uint16_t bg3_pal[4] = {
  SNES_RGB(4, 4, 12), SNES_RGB(24, 8, 20), SNES_RGB(28, 22, 8), SNES_RGB(12, 28, 24),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     phase;
} App;

volatile uint16_t corpus_result;  // many-arg color-grade fold (read from WRAM by the gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Re-grade the whole field with time-swept coefficients. noinline caps a16/xy16 pressure.
__attribute__((noinline))
static void grade_step(App *a) {
  uint16_t p = a->phase;
  int16_t la = (int16_t)((p & 63u) - 32);      // sweeping lift
  int16_t lb = (int16_t)(((p >> 1) & 63u) - 20);
  int16_t lc = (int16_t)(24 - (int16_t)((p >> 2) & 47u));
  int16_t ga = (int16_t)((p >> 1) & 7u);        // sweeping gamma
  int16_t gb = (int16_t)((p >> 2) & 5u);
  int16_t gc = (int16_t)((p >> 3) & 9u);
  int16_t gn = (int16_t)(3 + ((p >> 4) & 3u));  // gain
  int16_t mx = (int16_t)(((p >> 2) & 7u) - 3);  // mix
  int16_t bs = (int16_t)(((p >> 1) % 6u) + 1u); // bias
  for (uint8_t cy = 0; cy < NCELL; cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      int16_t base = (int16_t)(((int16_t)cx + (int16_t)cy) * 6);   // diagonal gradient
      int16_t r = color_grade(base, la, lb, lc, ga, gb, gc, gn, mx, bs);  // 10-arg spilling call
      uint8_t col = (uint8_t)(((uint16_t)r >> 4) & 3u);
      cell_fill(&a->canvas, cx, cy, col);
    }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
  a->phase++;
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->phase = 0u;
  text_puts(&a->text, 0, 1, "10-ARG COLOR GRADE");
  text_puts(&a->text, 1, 0, "ARGS SPILL TO SOFT STACK  CC TEST");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "COLOR GRADE", "10-ARG SPILL");
  corpus_result = cgrade_gate_crc();            // self-verify the many-arg grade == host 0x783F
  title_end(&a.screen, &title, 110);
  for (;;) {
    grade_step(&a);
    display_frame(&a.screen);
  }
}
