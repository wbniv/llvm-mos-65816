// Rotozoom — #56 of the compiler stress-test demo battery.
// Renders the verified, portable affine texture rotate-zoom (examples/65816/rotozoom.h — the same header
// the host oracle tools/rotozoom-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3),
// so it builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// Each cell samples a procedural texture at an affine-transformed coordinate: the Q16.16 fixed-point
// multiply q16mul(a,b) = (int64)a*b >> 16 keeps the middle 32 bits of a 64-bit product — the WIDENING
// MULTIPLY-HIGH (G_SMULH/G_UMULH .lower() @300, which on this soft-multiply target expands through
// __muldi3). The texture spins and breathes ("rotozoomer"). A codegen corner none of the first 55 run.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/rotozoom.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       16
#define NCOL        4
#define BAND        4              // recompute BAND cell-rows/frame (q16mul -> __muldi3 is heavy)

// BG3 2bpp palette (CGRAM 0..3): the checker/grid texture — navy / blue / gold / white.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(2, 3, 10), SNES_RGB(8, 14, 30), SNES_RGB(31, 24, 6), SNES_RGB(31, 31, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     frame;
  uint8_t      band;
} App;

volatile uint16_t corpus_result;  // rotozoom gate CRC (read from WRAM by the differential gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Recompute one BAND of cell-rows of the rotozoom at the current angle/zoom/pan. noinline caps RA.
__attribute__((noinline))
static void field_band(App *a) {
  uint8_t ang = (uint8_t)(a->frame & 0xFFu);                          // spin
  uint16_t zoom = (uint16_t)(256u + (uint16_t)((ROTO_SIN((uint8_t)(a->frame >> 1)) )));  // breathe (Q8.8)
  int32_t u0 = ((int32_t)32 << 16) + ((int32_t)ROTO_COS((uint8_t)(a->frame >> 2)) << 10); // pan
  int32_t v0 = ((int32_t)32 << 16) + ((int32_t)ROTO_SIN((uint8_t)(a->frame >> 2)) << 10);
  uint8_t y0 = (uint8_t)(a->band * BAND);
  for (uint8_t cy = y0; cy < (uint8_t)(y0 + BAND) && cy < NCELL; cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      uint8_t tx, ty;
      rotozoom_uv(cx, cy, ang, zoom, u0, v0, &tx, &ty);
      cell_fill(&a->canvas, cx, cy, rotozoom_tex(tx, ty));
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
  a->frame = 0u;
  a->band = 0u;
  text_puts(&a->text, 0, 3, "ROTOZOOM");
  text_puts(&a->text, 1, 0, "Q16.16 WIDENING MUL-HIGH");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "ROTOZOOM", "WIDENING MUL-HIGH");
  corpus_result = rotozoom_gate_crc();          // self-verify the affine math == host 0xD448
  title_end(&a.screen, &title, 110);
  for (;;) {
    a.frame++;
    field_band(&a);
    a.band++;
    if (a.band * BAND >= NCELL) a.band = 0u;
    display_frame(&a.screen);
  }
}
