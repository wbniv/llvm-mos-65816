// Newton-Raphson Reciprocal Perspective Floor — #47 of the compiler stress-test demo battery.
// A perspective checkerboard floor whose depth mapping z = FOCAL/row is computed by a MULTIPLY-ONLY
// Newton-Raphson fixed-point reciprocal (examples/65816/nrecip.h — the same nr_recip the host oracle
// tools/nrecip-sim.c and the corpus slice run), no hardware divide, no divide libcall. No far pointers
// -> builds default-8-bit AND +mos-a16 AND +mos-xy16, the full 5-way bar.
//
// Codegen under test: iterative fixed-point refinement — the convergent loop x = x*(2 - m*x) that
// refines a reciprocal estimate, lowering to 32-bit __mulsi3 (Q15 muls) with zero divide libcalls.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/nrecip.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       (CANVAS_W / 8)   // 16 cells per axis
#define FOCAL       4096u            // z = FOCAL/row
#define XK          9                // horizontal checker shift
#define ZK          11               // depth checker shift
#define CAMSPEED    48               // forward scroll per frame

static const uint16_t bg3_pal[4] = {
  SNES_RGB(2, 4, 8), SNES_RGB(6, 10, 20), SNES_RGB(10, 16, 28), SNES_RGB(28, 30, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  int32_t      camz;                 // forward camera position (scrolls the floor)
} App;

volatile uint16_t corpus_result;  // Newton-reciprocal fold (read from WRAM by the gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Recompute the perspective floor. noinline caps the a16/xy16 register pressure of the reciprocal loop.
__attribute__((noinline))
static void floor_step(App *a) {
  for (uint8_t cx = 0; cx < NCELL; cx++) cell_fill(&a->canvas, cx, 0, 2u);  // horizon band
  for (uint8_t cy = 1; cy < NCELL; cy++) {
    uint32_t inv = nr_recip((uint16_t)cy);                 // Q16 of 1/cy (Newton reciprocal)
    uint32_t z = (uint32_t)(((uint32_t)FOCAL * inv) >> 16); // depth ~ FOCAL/cy
    int32_t worldZ = (int32_t)((int32_t)z + a->camz);
    uint8_t zbit = (uint8_t)((uint32_t)(worldZ >> ZK) & 1u);
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      int32_t worldX = (int32_t)((int32_t)((int16_t)cx - 8) * (int32_t)z);   // spread by depth
      uint8_t xbit = (uint8_t)(((uint32_t)(worldX >> XK)) & 1u);
      uint8_t col = (uint8_t)((xbit ^ zbit) ? 3u : 1u);
      if (cy < 4u) col = (uint8_t)(col == 3u ? 2u : 0u);   // fade distant rows
      cell_fill(&a->canvas, cx, cy, col);
    }
  }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
  a->camz += CAMSPEED;
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->camz = 0;
  text_puts(&a->text, 0, 1, "NEWTON RECIPROCAL FLOOR");
  text_puts(&a->text, 1, 0, "X=X*(2-M*X)  1/Z  NO DIVIDE");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "NEWTON FLOOR", "1/Z RECIPROCAL");
  corpus_result = nrecip_gate_crc();            // self-verify the Newton reciprocal == host 0x044A
  title_end(&a.screen, &title, 110);
  for (;;) {
    floor_step(&a);
    display_frame(&a.screen);
  }
}
